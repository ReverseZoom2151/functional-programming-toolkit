-- | Symbolic expressions and canonical single-variable polynomials.
module Functional.Symbolic.Algebra
  ( Expr (..)
  , Polynomial
  , eval
  , evalWith
  , simplify
  , expand
  , factor
  , differentiate
  , substitute
  , toPolynomial
  , fromPolynomial
  , renderExpr
  , parseExpr
  ) where

import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import qualified Data.Map.Strict as Map
import Data.List (sortOn)

data Expr
  = Constant Integer
  | Variable
  | Symbol String
  | Add Expr Expr
  | Multiply Expr Expr
  | Power Int
  | SymbolPower String Int
  deriving (Eq, Show)

newtype Polynomial = Polynomial [Integer] deriving (Eq)

eval :: Integer -> Expr -> Integer
eval x expression = case expression of
  Constant n -> n
  Variable -> x
  Symbol _ -> 0
  Add left right -> eval x left + eval x right
  Multiply left right -> eval x left * eval x right
  Power power -> x ^ power
  SymbolPower _ _ -> 0

-- | Evaluate an expression with values for every named symbol. The legacy
-- 'Variable' constructor is named @x@ in this environment.
evalWith :: [(String, Integer)] -> Expr -> Either String Integer
evalWith bindings = go
  where
    environment = Map.fromList bindings
    lookupSymbol name = maybe (Left ("no value supplied for " ++ name)) Right (Map.lookup name environment)
    go expression = case expression of
      Constant n -> Right n
      Variable -> lookupSymbol "x"
      Symbol name -> lookupSymbol name
      Add left right -> (+) <$> go left <*> go right
      Multiply left right -> (*) <$> go left <*> go right
      Power power -> (^ power) <$> lookupSymbol "x"
      SymbolPower name power -> (^ power) <$> lookupSymbol name

simplify :: Expr -> Expr
simplify expression
  | usesOnlyX expression = fromPolynomial (toPolynomial expression)
  | otherwise = fromMultiPolynomial (toMultiPolynomial expression)

-- | Expand an expression into its canonical polynomial form. This is named
-- separately from 'simplify' so it can be used directly from the CLI/REPL.
expand :: Expr -> Expr
expand = simplify

-- | Factor out the greatest common integer coefficient and the lowest shared
-- power of @x@. Expressions without a non-trivial common monomial are left in
-- canonical expanded form.
factor :: Expr -> Expr
factor expression
  | not (usesOnlyX expression) = fromMultiPolynomial (toMultiPolynomial expression)
  | otherwise = factorUnivariate expression

factorUnivariate :: Expr -> Expr
factorUnivariate expression
  | degree == 2, Just (firstRoot, secondRoot) <- integerRoots coefficients = scaledProduct leading (linearFactor firstRoot) (linearFactor secondRoot)
  | null nonZero = Constant 0
  | coefficient == 1 && power == 0 = fromPolynomial polynomial
  | otherwise = Multiply (monomial coefficient power) (fromPolynomial remainder)
  where
    polynomial@(Polynomial coefficients) = toPolynomial expression
    degree = length coefficients - 1
    leading = if null coefficients then 1 else last coefficients
    nonZero = filter (/= 0) coefficients
    power = length (takeWhile (== 0) coefficients)
    unsignedCoefficient = foldr1 gcd (map abs nonZero)
    coefficient
      | last nonZero < 0 = negate unsignedCoefficient
      | otherwise = unsignedCoefficient
    remainder = Polynomial (map (`div` coefficient) (drop power coefficients))

-- | Differentiate an expression with respect to @x@ and return its canonical
-- polynomial form.
differentiate :: Expr -> Expr
differentiate expression
  | usesOnlyX expression = fromPolynomial (derivative (toPolynomial expression))
  | otherwise = fromMultiPolynomial (derivativeMulti "x" (toMultiPolynomial expression))

-- | Replace every occurrence of @x@ in an expression with another expression.
-- This is useful for composition as well as symbolic exploration in the REPL.
substitute :: Expr -> Expr -> Expr
substitute replacement expression = case expression of
  Constant n -> Constant n
  Variable -> replacement
  Symbol name -> Symbol name
  Add left right -> Add (substitute replacement left) (substitute replacement right)
  Multiply left right -> Multiply (substitute replacement left) (substitute replacement right)
  Power n -> powerOf replacement n
  SymbolPower name n -> SymbolPower name n

toPolynomial :: Expr -> Polynomial
toPolynomial expression = case expression of
  Constant n -> Polynomial [n]
  Variable -> Polynomial [0, 1]
  Symbol _ -> Polynomial [0]
  Power n -> Polynomial (replicate n 0 ++ [1])
  SymbolPower _ _ -> Polynomial [0]
  Add left right -> add (toPolynomial left) (toPolynomial right)
  Multiply left right -> multiply (toPolynomial left) (toPolynomial right)

fromPolynomial :: Polynomial -> Expr
fromPolynomial (Polynomial coefficients) = case terms of
  [] -> Constant 0
  first : rest -> foldl Add first rest
  where
    terms = [term power coefficient | (power, coefficient) <- zip [0 ..] coefficients, coefficient /= 0]
    term 0 coefficient = Constant coefficient
    term 1 1 = Variable
    term 1 coefficient = Multiply (Constant coefficient) Variable
    term power 1 = Power power
    term power coefficient = Multiply (Constant coefficient) (Power power)

renderExpr :: Expr -> String
renderExpr expression = case expression of
  Constant n -> show n
  Variable -> "x"
  Symbol name -> name
  Power n -> "x^" ++ show n
  SymbolPower name n -> name ++ "^" ++ show n
  Add left right -> "(" ++ renderExpr left ++ " + " ++ renderExpr right ++ ")"
  Multiply left right -> "(" ++ renderExpr left ++ " * " ++ renderExpr right ++ ")"

-- | Parse a small expression language containing integers, @x@, @+@, @-@,
-- @*@, parentheses, and powers such as @x^2@. Whitespace is ignored.
parseExpr :: String -> Either String Expr
parseExpr input = do
  (expression, remaining) <- parseSum (filter (not . isSpace) input)
  if null remaining
    then Right expression
    else Left ("unexpected input: " ++ remaining)

type Parser a = String -> Either String (a, String)

parseSum :: Parser Expr
parseSum input = do
  (first, rest) <- parseProduct input
  go first rest
  where
    go left ('+':rest) = do
      (right, remaining) <- parseProduct rest
      go (Add left right) remaining
    go left ('-':rest) = do
      (right, remaining) <- parseProduct rest
      go (Add left (Multiply (Constant (-1)) right)) remaining
    go left rest = Right (left, rest)

parseProduct :: Parser Expr
parseProduct input = do
  (first, rest) <- parseFactor input
  go first rest
  where
    go left ('*':rest) = do
      (right, remaining) <- parseFactor rest
      go (Multiply left right) remaining
    go left rest = Right (left, rest)

parseFactor :: Parser Expr
parseFactor [] = Left "expected an expression"
parseFactor ('-':rest) = do
  (expression, remaining) <- parseFactor rest
  Right (Multiply (Constant (-1)) expression, remaining)
parseFactor input@(first:_)
  | isAlpha first = do
      let (name, rest) = span isAlphaNum input
      parseNamedPower name rest
parseFactor ('(':rest) = do
  (expression, remaining) <- parseSum rest
  case remaining of
    ')':after -> Right (expression, after)
    _ -> Left "expected ')'"
parseFactor input@(first:_)
  | isDigit first = Right (Constant (read digits), remaining)
  | otherwise = Left ("expected an expression, found '" ++ [first] ++ "'")
  where
    (digits, remaining) = span isDigit input

parseNamedPower :: String -> Parser Expr
parseNamedPower name ('^':rest) = do
  (digits, remaining) <- parseDigits rest
  let degree = read digits
  Right (if name == "x" then Power degree else SymbolPower name degree, remaining)
parseNamedPower name rest = Right (if name == "x" then Variable else Symbol name, rest)

parseDigits :: Parser String
parseDigits input = case span isDigit input of
  ([], _) -> Left "expected a non-negative exponent after '^'"
  result -> Right result

add :: Polynomial -> Polynomial -> Polynomial
add (Polynomial left) (Polynomial right) = normalise (zipWith (+) (pad left) (pad right))
  where
    width = max (length left) (length right)
    pad values = values ++ replicate (width - length values) 0

multiply :: Polynomial -> Polynomial -> Polynomial
multiply (Polynomial left) (Polynomial right) = normalise coefficients
  where
    width = length left + length right - 1
    coefficients = [sum [a * b | (i, a) <- zip [0 ..] left, (j, b) <- zip [0 ..] right, i + j == power] | power <- [0 .. width - 1]]

normalise :: [Integer] -> Polynomial
normalise = Polynomial . reverse . dropWhile (== 0) . reverse

derivative :: Polynomial -> Polynomial
derivative (Polynomial []) = Polynomial []
derivative (Polynomial (_ : coefficients)) = normalise
  [ fromIntegral power * coefficient
  | (power, coefficient) <- zip [1 :: Int ..] coefficients
  ]

powerOf :: Expr -> Int -> Expr
powerOf _ 0 = Constant 1
powerOf expression n = foldr1 Multiply (replicate n expression)

monomial :: Integer -> Int -> Expr
monomial coefficient power = case power of
  0 -> Constant coefficient
  _ | coefficient == 1 -> Power power
    | otherwise -> Multiply (Constant coefficient) (Power power)

linearFactor :: Integer -> Expr
linearFactor root = Add Variable (Constant (negate root))

scaledProduct :: Integer -> Expr -> Expr -> Expr
scaledProduct 1 left right = Multiply left right
scaledProduct coefficient left right = Multiply (Constant coefficient) (Multiply left right)

integerRoots :: [Integer] -> Maybe (Integer, Integer)
integerRoots [constant, linear, quadratic]
  | quadratic == 0 = Nothing
  | otherwise = do
      rootDiscriminant <- perfectSquare (linear * linear - 4 * quadratic * constant)
      let denominator = 2 * quadratic
          firstNumerator = negate linear + rootDiscriminant
          secondNumerator = negate linear - rootDiscriminant
      if firstNumerator `mod` denominator == 0 && secondNumerator `mod` denominator == 0
        then Just (firstNumerator `div` denominator, secondNumerator `div` denominator)
        else Nothing
integerRoots _ = Nothing

perfectSquare :: Integer -> Maybe Integer
perfectSquare value
  | value < 0 = Nothing
  | root * root == value = Just root
  | otherwise = Nothing
  where root = floor (sqrt (fromIntegral value :: Double))

usesOnlyX :: Expr -> Bool
usesOnlyX expression = case expression of
  Constant _ -> True
  Variable -> True
  Symbol _ -> False
  Add left right -> usesOnlyX left && usesOnlyX right
  Multiply left right -> usesOnlyX left && usesOnlyX right
  Power _ -> True
  SymbolPower _ _ -> False

type Monomial = Map.Map String Int
newtype MultiPolynomial = MultiPolynomial (Map.Map Monomial Integer)

toMultiPolynomial :: Expr -> MultiPolynomial
toMultiPolynomial expression = case expression of
  Constant value -> multiConstant value
  Variable -> multiPower "x" 1
  Symbol name -> multiPower name 1
  Add left right -> addMulti (toMultiPolynomial left) (toMultiPolynomial right)
  Multiply left right -> multiplyMulti (toMultiPolynomial left) (toMultiPolynomial right)
  Power degree -> multiPower "x" degree
  SymbolPower name degree -> multiPower name degree

fromMultiPolynomial :: MultiPolynomial -> Expr
fromMultiPolynomial (MultiPolynomial coefficients) = case terms of
  [] -> Constant 0
  first:rest -> foldl Add first rest
  where
    terms = map renderTerm (sortOn order (Map.toList coefficients))
    order (monomial', _) = (sum (Map.elems monomial'), Map.toAscList monomial')
    renderTerm (monomial', coefficient) = productOf (coefficientFactor coefficient : map symbolFactor (Map.toAscList monomial'))
    coefficientFactor 1 = Nothing
    coefficientFactor value = Just (Constant value)
    symbolFactor (name, 1) = Just (if name == "x" then Variable else Symbol name)
    symbolFactor (name, degree) = Just (if name == "x" then Power degree else SymbolPower name degree)

productOf :: [Maybe Expr] -> Expr
productOf factors = case [factor' | Just factor' <- factors] of
  [] -> Constant 1
  first:rest -> foldl Multiply first rest

multiConstant :: Integer -> MultiPolynomial
multiConstant 0 = MultiPolynomial Map.empty
multiConstant value = MultiPolynomial (Map.singleton Map.empty value)

multiPower :: String -> Int -> MultiPolynomial
multiPower _ 0 = multiConstant 1
multiPower name degree = MultiPolynomial (Map.singleton (Map.singleton name degree) 1)

addMulti :: MultiPolynomial -> MultiPolynomial -> MultiPolynomial
addMulti (MultiPolynomial left) (MultiPolynomial right) = MultiPolynomial (Map.filter (/= 0) (Map.unionWith (+) left right))

multiplyMulti :: MultiPolynomial -> MultiPolynomial -> MultiPolynomial
multiplyMulti (MultiPolynomial left) (MultiPolynomial right) = MultiPolynomial (Map.filter (/= 0) coefficients)
  where
    coefficients = Map.fromListWith (+)
      [ (Map.unionWith (+) leftMonomial rightMonomial, leftCoefficient * rightCoefficient)
      | (leftMonomial, leftCoefficient) <- Map.toList left
      , (rightMonomial, rightCoefficient) <- Map.toList right
      ]

derivativeMulti :: String -> MultiPolynomial -> MultiPolynomial
derivativeMulti variable (MultiPolynomial coefficients) = MultiPolynomial (Map.filter (/= 0) derivatives)
  where
    derivatives = Map.fromListWith (+)
      [ (Map.update decrement variable mono, coefficient * fromIntegral degree)
      | (mono, coefficient) <- Map.toList coefficients
      , Just degree <- [Map.lookup variable mono]
      ]
    decrement degree
      | degree == 1 = Nothing
      | otherwise = Just (degree - 1)
