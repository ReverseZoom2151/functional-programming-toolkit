-- | Symbolic expressions and canonical single-variable polynomials.
module Functional.Algebra
  ( Expr (..)
  , Polynomial
  , eval
  , simplify
  , toPolynomial
  , fromPolynomial
  , renderExpr
  ) where

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
