module Main where

import Functional.Algebra
import Functional.Blackjack
import Functional.Sudoku
import Functional.Sudoku.Catalogue
import Data.List (sort)
import System.Exit (exitFailure)
import Test.QuickCheck (Arbitrary (arbitrary), Gen, Testable, choose, frequency, isSuccess, quickCheckResult, sized)

main :: IO ()
main = do
  results <- sequence [blackjackTests, sudokuTests, catalogueTests, algebraTests, propertyTests]
  if and results then putStrLn "All toolkit tests passed." else exitFailure

blackjackTests :: IO Bool
blackjackTests = do
  aceScore <- check "Blackjack scores multiple aces correctly" (handValue [Card Ace Spades, Card Ace Hearts, Card Nine Clubs] == 21)
  bustScore <- check "Blackjack selects the lowest all-bust ace total" (handValue [Card Ace Spades, Card Ace Hearts, Card King Clubs, Card Queen Diamonds] == 22)
  deckSize <- check "Blackjack builds a standard 52-card deck" (length fullDeck == 52)
  shufflePreservesDeck <- check "Blackjack shuffle is deterministic and preserves every card" (let shuffled = shuffleWithSeed 42 fullDeck in shuffled == shuffleWithSeed 42 fullDeck && sort shuffled == sort fullDeck)
  roundResult <- check "Blackjack resolves a deterministic round" (case playRound [Card Ten Hearts, Card Nine Clubs, Card Seven Spades, Card Seven Diamonds, Card Two Hearts] [Hit] of Right (Player, player, dealer) -> handValue player == 19 && handValue dealer == 16; _ -> False)
  shortDeck <- check "Blackjack rejects an incomplete initial deck" (case playRound [] [] of Left _ -> True; Right _ -> False)
  bustStopsDealer <- check "Blackjack does not draw for the dealer after a player bust" (case startRound [Card King Hearts, Card Nine Clubs, Card Queen Spades, Card Seven Diamonds, Card Two Hearts] >>= hit of Right gameState -> let (_, _, dealer) = finishRound gameState in length dealer == 2; Left _ -> False)
  pure (aceScore && bustScore && deckSize && shufflePreservesDeck && roundResult && shortDeck && bustStopsDealer)

sudokuTests :: IO Bool
sudokuTests = case parseBoard easyPuzzle of
  Left _ -> check "Sudoku parser accepts a valid puzzle" False
  Right board -> do
    solved <- check "Sudoku solver finds the known unique solution" (length (solve board) == 1)
    unique <- check "Sudoku diagnostics classify a unique puzzle" (solutionSummary (diagnose board) == UniqueSolution)
    malformed <- check "Sudoku parser rejects malformed input" (case parseBoard "not a puzzle" of Left _ -> True; Right _ -> False)
    inconsistent <- check "Sudoku solver rejects conflicting clues" (case parseBoard (replicate 81 '1') of Right broken -> null (solve broken); Left _ -> False)
    noSolution <- check "Sudoku diagnostics classify an impossible puzzle" (case parseBoard (replicate 81 '1') of Right broken -> solutionSummary (diagnose broken) == NoSolution; Left _ -> False)
    ambiguous <- check "Sudoku diagnostics cap an ambiguous search at two solutions" (case parseBoard ambiguousPuzzle of Right puzzle -> diagnose puzzle == SolverDiagnostics MultipleSolutions 2 True; Left _ -> False)
    pure (solved && unique && malformed && inconsistent && noSolution && ambiguous)
  where
    easyPuzzle = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
    solvedPuzzle = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    ambiguousPuzzle = map eraseOneOrTwo solvedPuzzle
    eraseOneOrTwo '1' = '.'
    eraseOneOrTwo '2' = '.'
    eraseOneOrTwo value = value

catalogueTests :: IO Bool
catalogueTests = do
  expectedEntries <- check "Puzzle catalogue contains the curated puzzles" (map puzzleName catalogue == ["easy", "hard"])
  caseInsensitive <- check "Puzzle catalogue lookup ignores case" (case lookupPuzzle "HARD" of Just puzzle -> puzzleName puzzle == "hard"; Nothing -> False)
  descriptionSearch <- check "Puzzle catalogue searches descriptions" (map puzzleName (findPuzzles "starter") == ["easy"])
  pure (expectedEntries && caseInsensitive && descriptionSearch)

algebraTests :: IO Bool
algebraTests = do
  let expression = Multiply (Add Variable (Constant 1)) (Add Variable (Constant 1))
  preservesValue <- check "Simplification preserves evaluation" (eval 7 expression == eval 7 (simplify expression))
  canonicalZero <- check "Canonical zero has no redundant operations" (renderExpr (simplify (Add (Constant 0) (Constant 0))) == "0")
  parserRoundTrip <- check "Parser understands polynomial syntax" (case parseExpr "2 * x^2 + x - 3" of Right parsed -> eval 4 parsed == 33; Left _ -> False)
  invalidSyntax <- check "Parser rejects invalid syntax" (case parseExpr "x ^" of Left _ -> True; Right _ -> False)
  normalisesProduct <- check "Simplification combines polynomial products" (renderExpr (simplify (Multiply Variable Variable)) == "x^2")
  pure (preservesValue && canonicalZero && parserRoundTrip && invalidSyntax && normalisesProduct)

propertyTests :: IO Bool
propertyTests = do
  shuffleInvariant <- runProperty "Blackjack shuffle preserves the deck" prop_shufflePreservesDeck
  simplificationInvariant <- runProperty "Algebra simplification preserves evaluation" prop_simplifyPreservesEvaluation
  parserInvariant <- runProperty "Rendered algebra parses with the same meaning" prop_renderParsePreservesEvaluation
  solverBoundInvariant <- runProperty "Sudoku bounded solver respects its limit" prop_solveUpToRespectsLimit
  pure (shuffleInvariant && simplificationInvariant && parserInvariant && solverBoundInvariant)

newtype SmallExpr = SmallExpr Expr

instance Show SmallExpr where
  show (SmallExpr expression) = renderExpr expression

instance Arbitrary SmallExpr where
  arbitrary = SmallExpr <$> sized genExpr

newtype SmallInteger = SmallInteger Integer deriving Show

instance Arbitrary SmallInteger where
  arbitrary = SmallInteger <$> choose (-10, 10)

genExpr :: Int -> Gen Expr
genExpr size
  | size <= 0 = frequency
      [ (4, Constant <$> choose (-8, 8))
      , (2, pure Variable)
      , (1, Power <$> choose (0, 6))
      ]
  | otherwise = frequency
      [ (3, genExpr 0)
      , (4, Add <$> subexpression <*> subexpression)
      , (4, Multiply <$> subexpression <*> subexpression)
      ]
  where
    subexpression = genExpr (size `div` 2)

prop_shufflePreservesDeck :: SmallInteger -> Bool
prop_shufflePreservesDeck (SmallInteger seed) =
  sort (shuffleWithSeed seed fullDeck) == sort fullDeck

prop_simplifyPreservesEvaluation :: SmallExpr -> SmallInteger -> Bool
prop_simplifyPreservesEvaluation (SmallExpr expression) (SmallInteger value) =
  eval value (simplify expression) == eval value expression

prop_renderParsePreservesEvaluation :: SmallExpr -> SmallInteger -> Bool
prop_renderParsePreservesEvaluation (SmallExpr expression) (SmallInteger value) =
  case parseExpr (renderExpr expression) of
    Left _ -> False
    Right parsed -> eval value parsed == eval value expression

prop_solveUpToRespectsLimit :: SmallInteger -> Bool
prop_solveUpToRespectsLimit (SmallInteger limit) =
  length (solveUpTo bound easyBoard) <= bound
  where
    bound = fromInteger (abs limit `mod` 4)
    Right easyBoard = parseBoard "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"

runProperty :: Testable property => String -> property -> IO Bool
runProperty label property = do
  putStrLn ("PROPERTY: " ++ label)
  result <- quickCheckResult property
  pure (isSuccess result)

check :: String -> Bool -> IO Bool
check label passed = do
  putStrLn ((if passed then "PASS: " else "FAIL: ") ++ label)
  pure passed
