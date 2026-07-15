-- | A dependency-free, pure Tetris game engine for the terminal executable.
module Functional.Tetris
  ( Action (..), Game, newGame, step, renderGame, gameOver, score ) where

import Data.List (nub)

type Point = (Int, Int)
type Board = [Point]

data Kind = I | J | L | O | S | T | Z deriving (Eq, Enum, Bounded)
data Piece = Piece Kind Point Int deriving Eq
data Game = Game Board Piece [Kind] Int Bool deriving Eq
data Action = Leftward | Rightward | Rotate | Downward | Drop deriving (Eq, Show)

width, height :: Int
width = 10
height = 20

newGame :: [Int] -> Game
newGame randoms = case kinds of
  first:rest -> Game [] (Piece first (3, 0) 0) rest 0 False
  [] -> error "cyclic piece supply expected"
  where
    kinds = map (toEnum . (`mod` 7) . abs) randoms ++ cycle [I, J, L, O, S, T, Z]

score :: Game -> Int
score (Game _ _ _ points _) = points

gameOver :: Game -> Bool
gameOver (Game _ _ _ _ finished) = finished

step :: Action -> Game -> Game
step _ game@(Game _ _ _ _ True) = game
step action game = case action of
  Leftward -> move (-1, 0) game
  Rightward -> move (1, 0) game
  Rotate -> rotate game
  Downward -> descend game
  Drop -> dropPiece game

move :: Point -> Game -> Game
move delta game@(Game board piece supply points done)
  | valid board shifted = Game board shifted supply points done
  | otherwise = game
  where shifted = translate delta piece

rotate :: Game -> Game
rotate game@(Game board (Piece kind pos turns) supply points done)
  | valid board spun = Game board spun supply points done
  | otherwise = game
  where spun = Piece kind pos ((turns + 1) `mod` 4)

descend :: Game -> Game
descend (Game board piece supply points done)
  | valid board lowered = Game board lowered supply points done
  | otherwise = spawn (clearLines (nub (board ++ cells piece))) supply points
  where lowered = translate (0, 1) piece

dropPiece :: Game -> Game
dropPiece game = let next = descend game in if next == game then game else dropPiece next

spawn :: (Board, Int) -> [Kind] -> Int -> Game
spawn (board, cleared) (kind:rest) points = Game board (Piece kind (3, 0) 0) rest (points + 100 * cleared * cleared) blocked
  where blocked = not (valid board (Piece kind (3, 0) 0))
spawn _ [] _ = error "infinite piece supply expected"

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
renderGame (Game board piece _ points done) = unlines (header : map row [0 .. height - 1])
  where occupied = board ++ cells piece
        header = "Tetris — " ++ show points ++ " points" ++ if done then " — GAME OVER" else ""
        row y = '|' : [if (x, y) `elem` occupied then '#' else ' ' | x <- [0 .. width - 1]] ++ "|"
