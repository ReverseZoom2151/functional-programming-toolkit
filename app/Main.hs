module Main where

import Functional.Games.Blackjack
import Functional.Puzzles.Sudoku
import Functional.Puzzles.SudokuCatalogue
import Functional.Symbolic.Algebra
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
run ("expand":source) = withExpression source $ \expression ->
  putStrLn (renderExpr (expand expression))
run ("factor":source) = withExpression source $ \expression ->
  putStrLn (renderExpr (factor expression))
run ("evaluate":value:source) = case reads value of
  [(x, "")] -> withExpression source $ \expression -> print (eval x expression)
  _ -> failWith "VALUE must be an integer"
run ("evaluate-with":arguments) = case break (== "--") arguments of
  (bindingSource, "--":expressionSource) -> case traverse parseBinding bindingSource of
    Left message -> failWith message
    Right bindings -> withExpression expressionSource $ \expression -> case evalWith bindings expression of
      Left message -> failWith message
      Right value -> print value
  _ -> failWith "use evaluate-with NAME=VALUE ... -- EXPRESSION"
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
run ["sudoku", "--hint", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> printHint board
run ["sudoku", "--rate", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> print (analyseDifficulty board)
run ["sudoku", "--import", fileName] = do
  input <- readFile fileName
  case parseBoard input of
    Left message -> failWith message
    Right board -> putStrLn (renderBoard board)
run ["sudoku", "--export", sourceFile, destinationFile] = do
  input <- readFile sourceFile
  case parseBoard input of
    Left message -> failWith message
    Right board -> writeFile destinationFile (exportBoard board ++ "\n")
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
  putStrLn "  expand EXPRESSION"
  putStrLn "  factor EXPRESSION"
  putStrLn "  evaluate VALUE EXPRESSION"
  putStrLn "  evaluate-with NAME=VALUE ... -- EXPRESSION"
  putStrLn "  repl"
  putStrLn "  puzzles [QUERY]"
  putStrLn "  puzzle NAME"
  putStrLn "  sudoku PUZZLE_FILE"
  putStrLn "  sudoku --diagnose PUZZLE_FILE"
  putStrLn "  sudoku --hint PUZZLE_FILE"
  putStrLn "  sudoku --rate PUZZLE_FILE"
  putStrLn "  sudoku --import PUZZLE_FILE"
  putStrLn "  sudoku --export INPUT_FILE OUTPUT_FILE"
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
          putStrLn ":expand EXPR     expand EXPR into canonical polynomial form"
          putStrLn ":factor EXPR     factor a common monomial from EXPR"
          putStrLn ":eval N EXPR    evaluate EXPR at x = N"
          putStrLn ":diff EXPR      differentiate EXPR"
          putStrLn ":quit            leave the REPL"
          loop
        (":eval":value:source) -> case reads value of
          [(x, "")] -> printExpression (unwords source) (print . eval x) >> loop
          _ -> putStrLn "N must be an integer." >> loop
        (":expand":source) -> printExpression (unwords source) (putStrLn . renderExpr . expand) >> loop
        (":factor":source) -> printExpression (unwords source) (putStrLn . renderExpr . factor) >> loop
        (":diff":source) -> printExpression (unwords source) (putStrLn . renderExpr . differentiate) >> loop
        _ -> printExpression input (putStrLn . renderExpr . simplify) >> loop

printExpression :: String -> (Expr -> IO ()) -> IO ()
printExpression source action = case parseExpr source of
  Left message -> putStrLn ("Error: " ++ message)
  Right expression -> action expression

parseBinding :: String -> Either String (String, Integer)
parseBinding source = case break (== '=') source of
  ([], _) -> Left "variable bindings need a name"
  (_, []) -> Left "variable bindings must use NAME=VALUE"
  (name, _:value) -> case reads value of
    [(number, "")] -> Right (name, number)
    _ -> Left ("invalid value for " ++ name)

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

printHint :: Board -> IO ()
printHint board = case nextHint board of
  Nothing -> putStrLn "No next hint: the board is solved or inconsistent."
  Just hint -> putStrLn
    ( "Next decision: row " ++ show (hintRow hint)
   ++ ", column " ++ show (hintColumn hint)
   ++ " accepts " ++ show (hintCandidates hint)
    )
