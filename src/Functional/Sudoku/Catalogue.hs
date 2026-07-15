-- | A small curated catalogue of named Sudoku puzzles.
module Functional.Sudoku.Catalogue
  ( Puzzle (..)
  , catalogue
  , findPuzzles
  , lookupPuzzle
  ) where

import Data.Char (toLower)
import qualified Data.Map.Strict as Map
import Data.List (isInfixOf, nubBy)
import Data.Maybe (mapMaybe)
import Functional.Sudoku (Board, parseBoard)

data Puzzle = Puzzle
  { puzzleName :: String
  , puzzleDescription :: String
  , puzzleBoard :: Board
  }

catalogue :: [Puzzle]
catalogue = Map.elems catalogueByName

catalogueByName :: Map.Map String Puzzle
catalogueByName = Map.fromList [(normalise (puzzleName puzzle), puzzle) | puzzle <- parsedCatalogue]

parsedCatalogue :: [Puzzle]
parsedCatalogue = mapMaybe makePuzzle definitions
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
findPuzzles query
  | null needle = catalogue
  | otherwise = deduplicate (prefixMatches ++ descriptionMatches)
  where
    needle = normalise query
    prefixMatches = Map.findWithDefault [] needle prefixIndex
    descriptionMatches = filter (isInfixOf needle . normalise . puzzleDescription) catalogue

-- | Resolve a puzzle by its complete name, ignoring case.
lookupPuzzle :: String -> Maybe Puzzle
lookupPuzzle name = Map.lookup (normalise name) catalogueByName

prefixIndex :: Map.Map String [Puzzle]
prefixIndex = Map.fromListWith (++)
  [ (prefix, [puzzle])
  | puzzle <- catalogue
  , prefix <- prefixes (normalise (puzzleName puzzle))
  ]

prefixes :: String -> [String]
prefixes name = [take length' name | length' <- [1 .. length name]]

deduplicate :: [Puzzle] -> [Puzzle]
deduplicate = nubBy sameName
  where sameName left right = puzzleName left == puzzleName right

normalise :: String -> String
normalise = map toLower

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Left _) = Nothing
eitherToMaybe (Right value) = Just value
