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
  bustScore <- check "Blackjack selects the lowest all-bust ace total" (handValue [Card Ace Spades, Card Ace Hearts, Card King Clubs, Card Queen Diamonds] == 22)
  deckSize <- check "Blackjack builds a standard 52-card deck" (length fullDeck == 52)
  roundResult <- check "Blackjack resolves a deterministic round" (case playRound [Card Ten Hearts, Card Nine Clubs, Card Seven Spades, Card Seven Diamonds, Card Two Hearts] [Hit] of Right (Player, player, dealer) -> handValue player == 19 && handValue dealer == 16; _ -> False)
  shortDeck <- check "Blackjack rejects an incomplete initial deck" (case playRound [] [] of Left _ -> True; Right _ -> False)
  pure (aceScore && bustScore && deckSize && roundResult && shortDeck)

sudokuTests :: IO Bool
sudokuTests = case parseBoard easyPuzzle of
  Left _ -> check "Sudoku parser accepts a valid puzzle" False
  Right board -> do
    solved <- check "Sudoku solver finds the known unique solution" (length (solve board) == 1)
    malformed <- check "Sudoku parser rejects malformed input" (case parseBoard "not a puzzle" of Left _ -> True; Right _ -> False)
    inconsistent <- check "Sudoku solver rejects conflicting clues" (case parseBoard (replicate 81 '1') of Right broken -> null (solve broken); Left _ -> False)
    pure (solved && malformed && inconsistent)
  where
    easyPuzzle = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"

algebraTests :: IO Bool
algebraTests = do
  let expression = Multiply (Add Variable (Constant 1)) (Add Variable (Constant 1))
  preservesValue <- check "Simplification preserves evaluation" (eval 7 expression == eval 7 (simplify expression))
  canonicalZero <- check "Canonical zero has no redundant operations" (renderExpr (simplify (Add (Constant 0) (Constant 0))) == "0")
  parserRoundTrip <- check "Parser understands polynomial syntax" (case parseExpr "2 * x^2 + x - 3" of Right parsed -> eval 4 parsed == 33; Left _ -> False)
  invalidSyntax <- check "Parser rejects invalid syntax" (case parseExpr "x ^" of Left _ -> True; Right _ -> False)
  normalisesProduct <- check "Simplification combines polynomial products" (renderExpr (simplify (Multiply Variable Variable)) == "x^2")
  pure (preservesValue && canonicalZero && parserRoundTrip && invalidSyntax && normalisesProduct)

check :: String -> Bool -> IO Bool
check label passed = do
  putStrLn ((if passed then "PASS: " else "FAIL: ") ++ label)
  pure passed
