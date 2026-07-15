-- | A pure, backtracking Sudoku solver for ordinary 9x9 puzzles.
module Functional.Puzzles.Sudoku
  ( Board
  , Hint (..)
  , Difficulty (..)
  , DifficultyReport (..)
  , SolutionSummary (..)
  , SolverDiagnostics (..)
  , parseBoard
  , exportBoard
  , solve
  , solveUpTo
  , diagnose
  , nextHint
  , analyseDifficulty
  , renderBoard
  ) where

import Data.Char (isSpace, digitToInt)
import Data.List (intercalate, minimumBy, (\\))
import Data.Ord (comparing)

type Cell = Maybe Int
newtype Board = Board [[Cell]] deriving (Eq)

-- | The most constrained unresolved cell in a valid board. Coordinates are
-- one-based so they can be shown directly to a terminal user.
data Hint = Hint
  { hintRow :: Int
  , hintColumn :: Int
  , hintCandidates :: [Int]
  }
  deriving (Eq, Show)

-- | The meaningful result of looking for up to two solutions.
data SolutionSummary = NoSolution | UniqueSolution | MultipleSolutions
  deriving (Eq, Show)

-- | A bounded, user-facing view of the solver's result. When
-- 'searchLimitReached' is true, 'solutionsFound' is a lower bound.
data SolverDiagnostics = SolverDiagnostics
  { solutionSummary :: SolutionSummary
  , solutionsFound :: Int
  , searchLimitReached :: Bool
  }
  deriving (Eq, Show)

-- | A solver-derived difficulty band. The band is based on actual branching
-- rather than a hand-maintained label in the catalogue.
data Difficulty = Beginner | Intermediate | Advanced | Expert
  deriving (Eq, Ord, Show)

data DifficultyReport = DifficultyReport
  { difficulty :: Difficulty
  , emptyCells :: Int
  , searchNodes :: Int
  , branchingDecisions :: Int
  }
  deriving (Eq, Show)

parseBoard :: String -> Either String Board
parseBoard input = do
  cells <- traverse parseCell symbols
  if length cells /= 81
    then Left "a Sudoku board must contain exactly 81 cells"
    else Right (Board (chunksOf 9 cells))
  where
    symbols = filter (not . isSpace) input
    parseCell '.' = Right Nothing
    parseCell '0' = Right Nothing
    parseCell c
      | c >= '1' && c <= '9' = Right (Just (digitToInt c))
      | otherwise = Left ("invalid Sudoku character: " ++ [c])

-- | Export a board as exactly 81 compact characters. Empty cells are dots,
-- making the result suitable for files, version control, and round-tripping
-- through 'parseBoard'.
exportBoard :: Board -> String
exportBoard (Board boardRows) = concatMap (map renderCell) boardRows
  where
    renderCell Nothing = '.'
    renderCell (Just value) = head (show value)

solve :: Board -> [Board]
solve = solveUpTo maxBound

-- | Find at most the requested number of solutions. A positive bound makes
-- this suitable for uniqueness checks without exhaustively enumerating every
-- solution of an ambiguous puzzle.
solveUpTo :: Int -> Board -> [Board]
solveUpTo limit _ | limit <= 0 = []
solveUpTo limit board
  | not (consistent board) = []
  | otherwise = case openCells board of
      [] -> [board]
      choices -> take limit (concatMap (solveUpTo limit . setCell board position) (candidates board position))
        where position = minimumBy (comparing (length . candidates board)) choices

-- | Determine whether a puzzle has no solution, exactly one solution, or at
-- least two solutions. Search is deliberately capped at two solutions.
diagnose :: Board -> SolverDiagnostics
diagnose board = case solveUpTo 2 board of
  [] -> SolverDiagnostics NoSolution 0 False
  [_] -> SolverDiagnostics UniqueSolution 1 False
  _ -> SolverDiagnostics MultipleSolutions 2 True

-- | Suggest the next search decision by choosing the empty cell with the
-- fewest legal candidates. A solved or inconsistent board has no hint.
nextHint :: Board -> Maybe Hint
nextHint board
  | not (consistent board) = Nothing
  | otherwise = case openCells board of
      [] -> Nothing
      positions -> Just (Hint (row + 1) (column + 1) (candidates board position))
        where
          position@(row, column) = minimumBy (comparing (length . candidates board)) positions

-- | Estimate difficulty by measuring the first successful solve path. A
-- forced move has one candidate; a branching decision has more than one.
analyseDifficulty :: Board -> DifficultyReport
analyseDifficulty board = DifficultyReport band blanks nodes decisions
  where
    blanks = length (openCells board)
    (_, nodes, decisions) = searchWork board
    band
      | decisions == 0 = Beginner
      | decisions <= 5 && nodes <= 100 = Intermediate
      | decisions <= 30 && nodes <= 1000 = Advanced
      | otherwise = Expert

searchWork :: Board -> (Maybe Board, Int, Int)
searchWork board
  | not (consistent board) = (Nothing, 1, 0)
  | otherwise = case openCells board of
      [] -> (Just board, 1, 0)
      positions -> tryCandidates position (candidates board position) 1 decision
        where
          position = minimumBy (comparing (length . candidates board)) positions
          decision = if length (candidates board position) > 1 then 1 else 0
          tryCandidates _ [] nodes decisions = (Nothing, nodes, decisions)
          tryCandidates cell (value:values) nodes decisions = case searchWork (setCell board cell value) of
            (Just solution, childNodes, childDecisions) -> (Just solution, nodes + childNodes, decisions + childDecisions)
            (Nothing, childNodes, childDecisions) -> tryCandidates cell values (nodes + childNodes) (decisions + childDecisions)

renderBoard :: Board -> String
renderBoard (Board boardRows) = intercalate "\n" (concatMap renderBand (chunksOf 3 boardRows))
  where
    renderBand band = map renderRow band ++ ["------+-------+------"]
    renderRow row = intercalate " | " (map (concatMap renderCell) (chunksOf 3 row))
    renderCell Nothing = ". "
    renderCell (Just n) = show n ++ " "

consistent :: Board -> Bool
consistent board = all noDuplicates (rows board ++ columns board ++ boxes board)
  where
    noDuplicates group = let values = [n | Just n <- group] in length values == length (unique values)

unique :: Eq a => [a] -> [a]
unique = foldr add []
  where add x xs | x `elem` xs = xs | otherwise = x : xs

openCells :: Board -> [(Int, Int)]
openCells (Board rows') = [(r, c) | (r, row) <- zip [0 ..] rows', (c, Nothing) <- zip [0 ..] row]

candidates :: Board -> (Int, Int) -> [Int]
candidates board (r, c) = [1 .. 9] \\ used
  where
    used = [n | Just n <- rowAt board r ++ columnAt board c ++ boxAt board r c]

setCell :: Board -> (Int, Int) -> Int -> Board
setCell (Board rows') (r, c) value = Board (replaceAt r (replaceAt c (Just value) (rows' !! r)) rows')

rows :: Board -> [[Cell]]
rows (Board rows') = rows'

columns :: Board -> [[Cell]]
columns board = [[rowAt board r !! c | r <- [0 .. 8]] | c <- [0 .. 8]]

columnAt :: Board -> Int -> [Cell]
columnAt board c = [rowAt board r !! c | r <- [0 .. 8]]

boxAt :: Board -> Int -> Int -> [Cell]
boxAt board r c = [rowAt board r' !! c' | r' <- [baseRow .. baseRow + 2], c' <- [baseCol .. baseCol + 2]]
  where
    baseRow = r - r `mod` 3
    baseCol = c - c `mod` 3

boxes :: Board -> [[Cell]]
boxes board = [boxAt board r c | r <- [0, 3, 6], c <- [0, 3, 6]]

rowAt :: Board -> Int -> [Cell]
rowAt (Board rows') r = rows' !! r

replaceAt :: Int -> a -> [a] -> [a]
replaceAt index replacement values = take index values ++ replacement : drop (index + 1) values

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs = take n xs : chunksOf n (drop n xs)
