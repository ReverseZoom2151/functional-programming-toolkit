module Main where

import Functional.Algebra
import Functional.Blackjack
import Functional.Sudoku
import System.Exit (exitFailure)

main :: IO ()
main = do
  results <- sequence [blackjackTests, sudokuTests, algebraTests]
  if and results then putStrLn "All toolkit tests passed." else exitFailure

blackjackTests :: IO Bool
blackjackTests = do
  aceScore <- check "Blackjack scores multiple aces correctly" (handValue [Card Ace Spades, Card Ace Hearts, Card Nine Clubs] == 21)
  deckSize <- check "Blackjack builds a standard 52-card deck" (length fullDeck == 52)
  pure (aceScore && deckSize)

sudokuTests :: IO Bool
sudokuTests = case parseBoard easyPuzzle of
  Left _ -> check "Sudoku parser accepts a valid puzzle" False
  Right board -> do
    solved <- check "Sudoku solver finds a solution" (not (null (solve board)))
    malformed <- check "Sudoku parser rejects malformed input" (case parseBoard "not a puzzle" of Left _ -> True; Right _ -> False)
    pure (solved && malformed)
  where
    easyPuzzle = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"

algebraTests :: IO Bool
algebraTests = do
  let expression = Multiply (Add Variable (Constant 1)) (Add Variable (Constant 1))
  preservesValue <- check "Simplification preserves evaluation" (eval 7 expression == eval 7 (simplify expression))
  canonicalZero <- check "Canonical zero has no redundant operations" (renderExpr (simplify (Add (Constant 0) (Constant 0))) == "0")
  pure (preservesValue && canonicalZero)

check :: String -> Bool -> IO Bool
check label passed = do
  putStrLn ((if passed then "PASS: " else "FAIL: ") ++ label)
  pure passed
