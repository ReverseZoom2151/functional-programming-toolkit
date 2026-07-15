-- | A tiny reproducible benchmark for the solver's bounded diagnostic path.
module Main where

import Control.Exception (evaluate)
import Functional.Sudoku (diagnose)
import Functional.Sudoku.Catalogue (lookupPuzzle, puzzleBoard)
import System.CPUTime (getCPUTime)

main :: IO ()
main = case lookupPuzzle "hard" of
  Nothing -> putStrLn "The hard catalogue puzzle is unavailable."
  Just puzzle -> do
    start <- getCPUTime
    result <- evaluate (diagnose (puzzleBoard puzzle))
    end <- getCPUTime
    let milliseconds = fromIntegral (end - start) / 1.0e9 :: Double
    putStrLn ("Solver diagnostic: " ++ show result)
    putStrLn ("CPU time: " ++ show milliseconds ++ " ms")
