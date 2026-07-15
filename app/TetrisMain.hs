module Main where

import Functional.Games.Tetris
import System.IO (hFlush, stdout)
import System.Timeout (timeout)

main :: IO ()
main = do
  putStrLn "Terminal Tetris — l/r rotate down drop hold, q quits."
  loop (newGame [1 ..])

loop :: Game -> IO ()
loop game = do
  putStrLn (renderGame game)
  if gameOver game
    then putStrLn "Thanks for playing."
    else do
      putStr "move> "
      hFlush stdout
      command <- timeout (gravityDelayMicros game) getLine
      case command of
        Nothing -> loop (step Tick game)
        Just "q" -> putStrLn "Goodbye."
        Just "l" -> loop (step Leftward game)
        Just "r" -> loop (step Rightward game)
        Just "u" -> loop (step Rotate game)
        Just "d" -> loop (step Downward game)
        Just " " -> loop (step Drop game)
        Just "drop" -> loop (step Drop game)
        Just "hold" -> loop (step Hold game)
        Just _ -> putStrLn "Use l, r, u, d, drop, hold, or q." >> loop game
