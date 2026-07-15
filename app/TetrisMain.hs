module Main where

import Functional.Games.Tetris
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  putStrLn "Terminal Tetris — l/r rotate down drop, q quits."
  loop (newGame [1 ..])

loop :: Game -> IO ()
loop game = do
  putStrLn (renderGame game)
  if gameOver game
    then putStrLn "Thanks for playing."
    else do
      putStr "move> "
      hFlush stdout
      command <- getLine
      case command of
        "q" -> putStrLn "Goodbye."
        "l" -> loop (step Leftward game)
        "r" -> loop (step Rightward game)
        "u" -> loop (step Rotate game)
        "d" -> loop (step Downward game)
        " " -> loop (step Drop game)
        "drop" -> loop (step Drop game)
        _ -> putStrLn "Use l, r, u, d, drop, or q." >> loop game
