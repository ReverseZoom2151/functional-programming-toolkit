-- | Symbolic expressions and canonical single-variable polynomials.
module Functional.Algebra
  ( Expr (..)
  , Polynomial
  , eval
  , simplify
  , differentiate
  , substitute
  , toPolynomial
  , fromPolynomial
  , renderExpr
  , parseExpr
  ) where

import Data.Char (isDigit, isSpace)

data Expr
  = Constant Integer
  | Variable
  | Add Expr Expr
  | Multiply Expr Expr
  | Power Int
  deriving (Eq, Show)

newtype Polynomial = Polynomial [Integer] deriving (Eq)

eval :: Integer -> Expr -> Integer
eval x expression = case expression of
  Constant n -> n
  Variable -> x
  Add left right -> eval x left + eval x right
  Multiply left right -> eval x left * eval x right
  Power power -> x ^ power

simplify :: Expr -> Expr
simplify = fromPolynomial . toPolynomial

-- | Differentiate an expression with respect to @x@ and return its canonical
-- polynomial form.
differentiate :: Expr -> Expr
differentiate = fromPolynomial . derivative . toPolynomial

-- | Replace every occurrence of @x@ in an expression with another expression.
-- This is useful for composition as well as symbolic exploration in the REPL.
substitute :: Expr -> Expr -> Expr
substitute replacement expression = case expression of
  Constant n -> Constant n
  Variable -> replacement
  Add left right -> Add (substitute replacement left) (substitute replacement right)
  Multiply left right -> Multiply (substitute replacement left) (substitute replacement right)
  Power n -> powerOf replacement n

toPolynomial :: Expr -> Polynomial
toPolynomial expression = case expression of
  Constant n -> Polynomial [n]
  Variable -> Polynomial [0, 1]
  Power n -> Polynomial (replicate n 0 ++ [1])
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
  Power n -> "x^" ++ show n
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
parseFactor ('x':rest) = parsePower rest
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

parsePower :: Parser Expr
parsePower ('^':rest) = do
  (digits, remaining) <- parseDigits rest
  Right (Power (read digits), remaining)
parsePower rest = Right (Variable, rest)

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
