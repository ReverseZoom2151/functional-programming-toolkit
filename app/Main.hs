module Main where

import Functional.Algebra
import Functional.Blackjack
import Functional.Sudoku
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = getArgs >>= run

run :: [String] -> IO ()
run ["blackjack-demo"] = do
  let deck = [Card Ace Spades, Card Nine Hearts, Card King Clubs, Card Seven Diamonds]
  case playRound deck [Stand] of
    Left message -> putStrLn message
    Right (result, player, dealer) -> do
      putStrLn ("Player: " ++ show player ++ " (" ++ show (handValue player) ++ ")")
      putStrLn ("Dealer: " ++ show dealer ++ " (" ++ show (handValue dealer) ++ ")")
      putStrLn ("Winner: " ++ show result)
run ["simplify-demo"] = do
  let expression = Add (Multiply (Constant 2) (Power 2)) (Add (Variable) (Constant 3))
  putStrLn ("Expression: " ++ renderExpr expression)
  putStrLn ("Canonical:  " ++ renderExpr (simplify expression))
  putStrLn ("At x = 4:   " ++ show (eval 4 expression))
run ("simplify":source) = withExpression source $ \expression ->
  putStrLn (renderExpr (simplify expression))
run ("evaluate":value:source) = case reads value of
  [(x, "")] -> withExpression source $ \expression -> print (eval x expression)
  _ -> failWith "VALUE must be an integer"
run ["sudoku", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> case solve board of
      [] -> failWith "the puzzle has no solution"
      solution : _ -> putStrLn (renderBoard solution)
run _ = do
  putStrLn "fp-toolkit commands:"
  putStrLn "  blackjack-demo"
  putStrLn "  simplify-demo"
  putStrLn "  simplify EXPRESSION"
  putStrLn "  evaluate VALUE EXPRESSION"
  putStrLn "  sudoku PUZZLE_FILE"
  exitFailure

failWith :: String -> IO a
failWith message = putStrLn ("Error: " ++ message) >> exitFailure

withExpression :: [String] -> (Expr -> IO ()) -> IO ()
withExpression [] _ = failWith "an expression is required"
withExpression source action = case parseExpr (unwords source) of
  Left message -> failWith message
  Right expression -> action expression
