-- | A dependency-free, pure Tetris game engine for the terminal executable.
module Functional.Games.Tetris
  ( Action (..)
  , Game
  , newGame
  , newGameWithQueue
  , step
  , renderGame
  , gameOver
  , score
  , linesCleared
  , level
  , nextPiece
  , heldPiece
  , gravityDelayMicros
  ) where

import Data.List (nub, sortOn)

type Point = (Int, Int)
type Board = [Point]

data Kind = I | J | L | O | S | T | Z deriving (Eq, Enum, Bounded)
data Piece = Piece Kind Point Int deriving Eq
data Game = Game Board Piece [Kind] (Maybe Kind) Bool Int Int Bool deriving Eq
data Action = Leftward | Rightward | Rotate | Downward | Drop | Hold | Tick deriving (Eq, Show)

width, height :: Int
width = 10
height = 20

newGame :: [Int] -> Game
newGame randoms = spawnNext [] (bagSupply randoms) Nothing True 0 0

-- | Create a deterministic replay game from tetromino labels. This is useful
-- for reproducible terminal sessions and focused engine tests.
newGameWithQueue :: String -> Either String Game
newGameWithQueue labels = case traverse charKind labels of
  Nothing -> Left "piece queues may contain only I, J, L, O, S, T, or Z"
  Just [] -> Left "piece queues must contain at least one tetromino"
  Just kinds -> Right (spawnNext [] (cycle kinds) Nothing True 0 0)

score :: Game -> Int
score (Game _ _ _ _ _ points _ _) = points

linesCleared :: Game -> Int
linesCleared (Game _ _ _ _ _ _ lines' _) = lines'

-- | The current level rises every ten cleared lines, starting at level one.
level :: Game -> Int
level game = 1 + linesCleared game `div` 10

-- | A compact preview of the next queued tetromino.
nextPiece :: Game -> Char
nextPiece (Game _ _ (kind:_) _ _ _ _ _) = kindName kind
nextPiece (Game _ _ [] _ _ _ _ _) = '?'

-- | The held tetromino, if the player has stored one.
heldPiece :: Game -> Maybe Char
heldPiece (Game _ _ _ held _ _ _ _) = kindName <$> held

-- | The terminal delay between gravity ticks. Higher levels fall faster while
-- retaining a small floor so input remains responsive.
gravityDelayMicros :: Game -> Int
gravityDelayMicros game = max 100000 (1000000 - 75000 * (level game - 1))

gameOver :: Game -> Bool
gameOver (Game _ _ _ _ _ _ _ finished) = finished

step :: Action -> Game -> Game
step _ game@(Game _ _ _ _ _ _ _ True) = game
step action game = case action of
  Leftward -> move (-1, 0) game
  Rightward -> move (1, 0) game
  Rotate -> rotate game
  Downward -> descend game
  Drop -> dropPiece game
  Hold -> holdPiece game
  Tick -> descend game

move :: Point -> Game -> Game
move delta game@(Game board piece supply held canHold points lines' done)
  | valid board shifted = Game board shifted supply held canHold points lines' done
  | otherwise = game
  where shifted = translate delta piece

rotate :: Game -> Game
rotate game@(Game board (Piece kind pos turns) supply held canHold points lines' done)
  | valid board spun = Game board spun supply held canHold points lines' done
  | otherwise = game
  where spun = Piece kind pos ((turns + 1) `mod` 4)

descend :: Game -> Game
descend (Game board piece supply held canHold points lines' done)
  | valid board lowered = Game board lowered supply held canHold points lines' done
  | otherwise = spawn (clearLines (nub (board ++ cells piece))) supply held points lines'
  where lowered = translate (0, 1) piece

dropPiece :: Game -> Game
dropPiece game@(Game board piece _ _ _ _ _ _)
  | valid board (translate (0, 1) piece) = dropPiece (descend game)
  | otherwise = descend game

holdPiece :: Game -> Game
holdPiece game@(Game board (Piece kind _ _) supply held canHold points lines' done)
  | not canHold = game
  | otherwise = case held of
      Nothing -> spawnNext board supply (Just kind) False points lines'
      Just stored -> activate board stored supply (Just kind) False points lines' done

spawn :: (Board, Int) -> [Kind] -> Maybe Kind -> Int -> Int -> Game
spawn (board, cleared) supply held points lines' =
  spawnNext board supply held True nextScore nextLines
  where
    nextScore = points + 100 * cleared * cleared * (1 + lines' `div` 10)
    nextLines = lines' + cleared

spawnNext :: Board -> [Kind] -> Maybe Kind -> Bool -> Int -> Int -> Game
spawnNext board (kind:rest) held canHold points lines' =
  activate board kind rest held canHold points lines' False
spawnNext _ [] _ _ _ _ = error "infinite piece supply expected"

activate :: Board -> Kind -> [Kind] -> Maybe Kind -> Bool -> Int -> Int -> Bool -> Game
activate board kind supply held canHold points lines' done =
  Game board piece supply held canHold points lines' (done || not (valid board piece))
  where piece = Piece kind (3, 0) 0

valid :: Board -> Piece -> Bool
valid board piece = all inside occupied && all (`notElem` board) occupied
  where occupied = cells piece
        inside (x, y) = x >= 0 && x < width && y >= 0 && y < height

translate :: Point -> Piece -> Piece
translate (dx, dy) (Piece kind (x, y) turns) = Piece kind (x + dx, y + dy) turns

cells :: Piece -> [Point]
cells (Piece kind (ox, oy) turns) = [(ox + x, oy + y) | (x, y) <- rotatePoints turns (base kind)]

rotatePoints :: Int -> [Point] -> [Point]
rotatePoints turns cells' = iterate rotateOnce cells' !! turns
  where rotateOnce shape = let rotated = [(-y, x) | (x, y) <- shape]
                            in normalise rotated
        normalise shape = [(x - minimum (map fst shape), y - minimum (map snd shape)) | (x, y) <- shape]

base :: Kind -> [Point]
base I = [(0,0),(0,1),(0,2),(0,3)]
base J = [(0,0),(0,1),(0,2),(1,2)]
base L = [(1,0),(1,1),(1,2),(0,2)]
base O = [(0,0),(1,0),(0,1),(1,1)]
base S = [(1,0),(2,0),(0,1),(1,1)]
base T = [(0,0),(1,0),(2,0),(1,1)]
base Z = [(0,0),(1,0),(1,1),(2,1)]

clearLines :: Board -> (Board, Int)
clearLines board = (shifted, length full)
  where full = [y | y <- [0 .. height - 1], length [() | (_, y') <- board, y' == y] == width]
        shifted = [(x, y + length [() | row <- full, row > y]) | (x, y) <- board, y `notElem` full]

renderGame :: Game -> String
renderGame game@(Game board piece _ _ _ points _ done) = unlines (header : map row [0 .. height - 1])
  where occupied = board ++ cells piece
        held = maybe "-" (: []) (heldPiece game)
        header = "Tetris — " ++ show points ++ " points — level " ++ show (level game) ++ " — lines " ++ show (linesCleared game) ++ " — next " ++ [nextPiece game] ++ " — hold " ++ held ++ if done then " — GAME OVER" else ""
        row y = '|' : [if (x, y) `elem` occupied then '#' else ' ' | x <- [0 .. width - 1]] ++ "|"

bagSupply :: [Int] -> [Kind]
bagSupply randoms = concatMap shuffleBag (chunksOf 7 seeds)
  where
    seeds = cycle (if null randoms then [0 .. 6] else randoms)
    shuffleBag bagSeeds = map snd (sortOn fst (zip (map abs bagSeeds) [I, J, L, O, S, T, Z]))

chunksOf :: Int -> [a] -> [[a]]
chunksOf n values = take n values : chunksOf n (drop n values)

kindName :: Kind -> Char
kindName I = 'I'
kindName J = 'J'
kindName L = 'L'
kindName O = 'O'
kindName S = 'S'
kindName T = 'T'
kindName Z = 'Z'

charKind :: Char -> Maybe Kind
charKind 'I' = Just I
charKind 'J' = Just J
charKind 'L' = Just L
charKind 'O' = Just O
charKind 'S' = Just S
charKind 'T' = Just T
charKind 'Z' = Just Z
charKind _ = Nothing
