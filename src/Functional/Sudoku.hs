-- | A pure, backtracking Sudoku solver for ordinary 9x9 puzzles.
module Functional.Sudoku
  ( Board
  , Hint (..)
  , SolutionSummary (..)
  , SolverDiagnostics (..)
  , parseBoard
  , solve
  , solveUpTo
  , diagnose
  , nextHint
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
