module Main where

import Functional.Algebra
import Functional.Blackjack
import Functional.Sudoku
import Functional.Sudoku.Catalogue
import System.CPUTime (getCPUTime)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hFlush, stdout)

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
run ["blackjack"] = do
  seed <- getCPUTime
  case startRound (shuffleWithSeed seed fullDeck) of
    Left message -> failWith message
    Right gameState -> playBlackjack gameState
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
run ["repl"] = algebraRepl
run ["puzzles"] = printPuzzles catalogue
run ("puzzles":query) = printPuzzles (findPuzzles (unwords query))
run ("puzzle":name) = case lookupPuzzle (unwords name) of
  Nothing -> failWith "no catalogue puzzle has that exact name; try `puzzles`"
  Just puzzle -> do
    putStrLn (puzzleName puzzle ++ ": " ++ puzzleDescription puzzle)
    solveWithDiagnostics (puzzleBoard puzzle)
run ["sudoku", "--diagnose", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> solveWithDiagnostics board
run ["sudoku", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> case solve board of
      [] -> failWith "the puzzle has no solution"
      solution : _ -> putStrLn (renderBoard solution)
run _ = do
  putStrLn "fp-toolkit commands:"
  putStrLn "  blackjack"
  putStrLn "  blackjack-demo"
  putStrLn "  simplify-demo"
  putStrLn "  simplify EXPRESSION"
  putStrLn "  evaluate VALUE EXPRESSION"
  putStrLn "  repl"
  putStrLn "  puzzles [QUERY]"
  putStrLn "  puzzle NAME"
  putStrLn "  sudoku PUZZLE_FILE"
  putStrLn "  sudoku --diagnose PUZZLE_FILE"
  exitFailure

failWith :: String -> IO a
failWith message = putStrLn ("Error: " ++ message) >> exitFailure

withExpression :: [String] -> (Expr -> IO ()) -> IO ()
withExpression [] _ = failWith "an expression is required"
withExpression source action = case parseExpr (unwords source) of
  Left message -> failWith message
  Right expression -> action expression

playBlackjack :: Round -> IO ()
playBlackjack gameState = do
  putStrLn ("Your hand: " ++ show (playerHand gameState) ++ " (" ++ show (handValue (playerHand gameState)) ++ ")")
  if isBust (playerHand gameState)
    then announceResult (finishRound gameState)
    else do
      putStr "Hit or stand? [h/S] "
      answer <- getLine
      case answer of
        "h" -> drawCard gameState
        "H" -> drawCard gameState
        "hit" -> drawCard gameState
        "Hit" -> drawCard gameState
        "" -> announceResult (finishRound gameState)
        "s" -> announceResult (finishRound gameState)
        "S" -> announceResult (finishRound gameState)
        "stand" -> announceResult (finishRound gameState)
        "Stand" -> announceResult (finishRound gameState)
        _ -> putStrLn "Please enter h or s." >> playBlackjack gameState

drawCard :: Round -> IO ()
drawCard gameState = case hit gameState of
  Left message -> failWith message
  Right nextRound -> playBlackjack nextRound

announceResult :: (Winner, Hand, Hand) -> IO ()
announceResult (result, player, dealer) = do
  putStrLn ("Player: " ++ show player ++ " (" ++ show (handValue player) ++ ")")
  putStrLn ("Dealer: " ++ show dealer ++ " (" ++ show (handValue dealer) ++ ")")
  putStrLn ("Winner: " ++ show result)

algebraRepl :: IO ()
algebraRepl = do
  putStrLn "Algebra REPL — enter an expression to simplify; :help for commands."
  loop
  where
    loop = do
      putStr "algebra> "
      hFlush stdout
      input <- getLine
      case words input of
        [":quit"] -> putStrLn "Goodbye."
        [":help"] -> do
          putStrLn "EXPR            simplify an expression"
          putStrLn ":eval N EXPR    evaluate EXPR at x = N"
          putStrLn ":diff EXPR      differentiate EXPR"
          putStrLn ":quit            leave the REPL"
          loop
        (":eval":value:source) -> case reads value of
          [(x, "")] -> printExpression (unwords source) (print . eval x) >> loop
          _ -> putStrLn "N must be an integer." >> loop
        (":diff":source) -> printExpression (unwords source) (putStrLn . renderExpr . differentiate) >> loop
        _ -> printExpression input (putStrLn . renderExpr . simplify) >> loop

printExpression :: String -> (Expr -> IO ()) -> IO ()
printExpression source action = case parseExpr source of
  Left message -> putStrLn ("Error: " ++ message)
  Right expression -> action expression

printPuzzles :: [Puzzle] -> IO ()
printPuzzles [] = putStrLn "No catalogue puzzles match that query."
printPuzzles puzzles = mapM_ printPuzzle puzzles

printPuzzle :: Puzzle -> IO ()
printPuzzle puzzle = putStrLn (puzzleName puzzle ++ " — " ++ puzzleDescription puzzle)

solveWithDiagnostics :: Board -> IO ()
solveWithDiagnostics board = do
  let diagnostics = diagnose board
  putStrLn ("Solutions: " ++ show (solutionsFound diagnostics) ++ suffix diagnostics)
  putStrLn ("Classification: " ++ show (solutionSummary diagnostics))
  case solveUpTo 1 board of
    [] -> pure ()
    solution : _ -> putStrLn (renderBoard solution)

suffix :: SolverDiagnostics -> String
suffix diagnostics
  | searchLimitReached diagnostics = "+ (search capped at two)"
  | otherwise = ""
