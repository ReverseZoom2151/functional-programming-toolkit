-- | A small, pure Blackjack rules engine.
module Functional.Blackjack
  ( Suit (..)
  , Rank (..)
  , Card (..)
  , Hand
  , Round
  , Move (..)
  , Winner (..)
  , fullDeck
  , shuffleWithSeed
  , handValue
  , isBust
  , startRound
  , playerHand
  , hit
  , finishRound
  , playRound
  , renderCard
  ) where

data Suit = Hearts | Diamonds | Clubs | Spades
  deriving (Eq, Ord, Enum, Bounded, Show)

data Rank = Two | Three | Four | Five | Six | Seven | Eight | Nine | Ten | Jack | Queen | King | Ace
  deriving (Eq, Ord, Enum, Bounded, Show)

data Card = Card { rank :: Rank, suit :: Suit }
  deriving (Eq, Ord)

type Hand = [Card]

-- | A round before the dealer has completed their play.
data Round = Round Hand Hand [Card]

data Move = Hit | Stand
  deriving (Eq, Show)

data Winner = Player | Dealer | Push
  deriving (Eq, Show)

instance Show Card where
  show = renderCard

fullDeck :: [Card]
fullDeck = [Card r s | r <- [minBound .. maxBound], s <- [minBound .. maxBound]]

-- | Deterministically shuffle a deck from a seed. This is deliberately a
-- simple pseudo-random shuffle for games and reproducible demos, not a
-- cryptographic random-number generator.
shuffleWithSeed :: Integer -> [Card] -> [Card]
shuffleWithSeed _ [] = []
shuffleWithSeed seed cards = selected : shuffleWithSeed seed' remaining
  where
    seed' = nextSeed seed
    index = fromInteger (seed' `mod` toInteger (length cards))
    selected = cards !! index
    remaining = take index cards ++ drop (index + 1) cards

nextSeed :: Integer -> Integer
nextSeed seed = (1103515245 * abs seed + 12345) `mod` 2147483648

renderCard :: Card -> String
renderCard (Card r s) = show r ++ " of " ++ show s

-- | The best non-bust total, or the smallest total if every total is bust.
handValue :: Hand -> Int
handValue hand
  | null eligible = minimum totals
  | otherwise = maximum eligible
  where
    aceCount = length [() | Card Ace _ <- hand]
    base = sum (map baseValue hand)
    totals = [base + 10 * promoted | promoted <- [0 .. aceCount]]
    eligible = filter (<= 21) totals

baseValue :: Card -> Int
baseValue (Card r _) = case r of
  Two -> 2; Three -> 3; Four -> 4; Five -> 5; Six -> 6; Seven -> 7
  Eight -> 8; Nine -> 9; Ten -> 10; Jack -> 10; Queen -> 10; King -> 10
  Ace -> 1

isBust :: Hand -> Bool
isBust = (> 21) . handValue

-- | Consume a supplied deck deterministically. The player starts with two
-- cards, follows the supplied moves, then the dealer draws to at least 17.
playRound :: [Card] -> [Move] -> Either String (Winner, Hand, Hand)
playRound deck moves = do
  gameState <- startRound deck
  afterMoves <- playMoves gameState moves
  pure (finishRound afterMoves)

-- | Deal the opening cards in player/dealer/player/dealer order.
startRound :: [Card] -> Either String Round
startRound (p1:d1:p2:d2:rest) = Right (Round [p1, p2] [d1, d2] rest)
startRound _ = Left "a round needs at least four cards"

playerHand :: Round -> Hand
playerHand (Round hand _ _) = hand

-- | Draw one card for the player.
hit :: Round -> Either String Round
hit (Round hand dealer (next:rest)) = Right (Round (hand ++ [next]) dealer rest)
hit _ = Left "the deck ran out while the player was drawing"

-- | Complete dealer play and determine the winner. A dealer does not draw
-- when the player has already bust.
finishRound :: Round -> (Winner, Hand, Hand)
finishRound (Round player dealer deck)
  | isBust player = (Dealer, player, dealer)
  | otherwise = (winner player dealerHand, player, dealerHand)
  where
    (dealerHand, _) = playDealer dealer deck

playMoves :: Round -> [Move] -> Either String Round
playMoves gameState [] = Right gameState
playMoves gameState (Stand:_) = Right gameState
playMoves gameState (Hit:moves) = do
  nextState <- hit gameState
  if isBust (playerHand nextState)
    then Right nextState
    else playMoves nextState moves

playDealer :: Hand -> [Card] -> (Hand, [Card])
playDealer hand deck@(next:rest)
  | handValue hand < 17 = playDealer (hand ++ [next]) rest
  | otherwise = (hand, deck)
playDealer hand [] = (hand, [])

winner :: Hand -> Hand -> Winner
winner player dealer
  | isBust player = Dealer
  | isBust dealer = Player
  | handValue player > handValue dealer = Player
  | handValue player < handValue dealer = Dealer
  | otherwise = Push
