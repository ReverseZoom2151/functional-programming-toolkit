-- | A small curated catalogue of named Sudoku puzzles.
module Functional.Sudoku.Catalogue
  ( Puzzle (..)
  , catalogue
  , findPuzzles
  , lookupPuzzle
  ) where

import Data.Char (toLower)
import Data.List (find, isInfixOf)
import Data.Maybe (mapMaybe)
import Functional.Sudoku (Board, parseBoard)

data Puzzle = Puzzle
  { puzzleName :: String
  , puzzleDescription :: String
  , puzzleBoard :: Board
  }

catalogue :: [Puzzle]
catalogue = mapMaybe makePuzzle definitions
  where
    makePuzzle (name, description, source) =
      Puzzle name description <$> eitherToMaybe (parseBoard source)

definitions :: [(String, String, String)]
definitions =
  [ ( "easy"
    , "A gentle, uniquely solvable starter puzzle."
    , "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
    )
  , ( "hard"
    , "A deeper search puzzle from the original course material."
    , "8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4.."
    )
  ]

-- | Search names and descriptions case-insensitively. An empty query returns
-- the whole catalogue, which makes it useful for listing puzzles.
findPuzzles :: String -> [Puzzle]
findPuzzles query = filter matches catalogue
  where
    needle = normalise query
    matches puzzle = null needle || needle `isInfixOf` normalise (puzzleName puzzle) || needle `isInfixOf` normalise (puzzleDescription puzzle)

-- | Resolve a puzzle by its complete name, ignoring case.
lookupPuzzle :: String -> Maybe Puzzle
lookupPuzzle name = find ((== normalise name) . normalise . puzzleName) catalogue

normalise :: String -> String
normalise = map toLower

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Left _) = Nothing
eitherToMaybe (Right value) = Just value
