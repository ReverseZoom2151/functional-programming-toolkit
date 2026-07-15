-- | A small, pure Blackjack rules engine.
module Functional.Blackjack
  ( Suit (..)
  , Rank (..)
  , Card (..)
  , Hand
  , Move (..)
  , Winner (..)
  , fullDeck
  , handValue
  , isBust
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

data Move = Hit | Stand
  deriving (Eq, Show)

data Winner = Player | Dealer | Push
  deriving (Eq, Show)

instance Show Card where
  show = renderCard

fullDeck :: [Card]
fullDeck = [Card r s | r <- [minBound .. maxBound], s <- [minBound .. maxBound]]

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
  (playerStart, dealerStart, rest) <- dealInitial deck
  (playerHand, afterPlayer) <- playPlayer playerStart rest moves
  let (dealerHand, _) = playDealer dealerStart afterPlayer
  pure (winner playerHand dealerHand, playerHand, dealerHand)

dealInitial :: [Card] -> Either String (Hand, Hand, [Card])
dealInitial (p1:d1:p2:d2:rest) = Right ([p1, p2], [d1, d2], rest)
dealInitial _ = Left "a round needs at least four cards"

playPlayer :: Hand -> [Card] -> [Move] -> Either String (Hand, [Card])
playPlayer hand deck [] = Right (hand, deck)
playPlayer hand deck (Stand:_) = Right (hand, deck)
playPlayer hand (next:rest) (Hit:moves)
  | isBust hand' = Right (hand', rest)
  | otherwise = playPlayer hand' rest moves
  where hand' = hand ++ [next]
playPlayer _ [] (Hit:_) = Left "the deck ran out while the player was drawing"

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
