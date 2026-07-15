-- | A tiny reproducible benchmark for each catalogue puzzle's bounded
-- diagnostic path. Timings are useful for comparing changes on one machine,
-- not for cross-machine claims.
module Main where

import Control.Exception (evaluate)
import Functional.Puzzles.Sudoku (diagnose)
import Functional.Puzzles.SudokuCatalogue (Puzzle (..), catalogue)
import System.CPUTime (getCPUTime)

main :: IO ()
main = mapM_ benchmarkPuzzle catalogue

benchmarkPuzzle :: Puzzle -> IO ()
benchmarkPuzzle puzzle = do
  start <- getCPUTime
  result <- evaluate (diagnose (puzzleBoard puzzle))
  end <- getCPUTime
  let milliseconds = fromIntegral (end - start) / 1.0e9 :: Double
  putStrLn (puzzleName puzzle ++ ": " ++ show result ++ " — " ++ show milliseconds ++ " ms")
