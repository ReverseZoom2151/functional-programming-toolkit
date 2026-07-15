# Product boundary and verification

## Maintained surface

This repository is a Cabal package containing a reusable Haskell library and
three executables:

| Deliverable | Responsibility |
| --- | --- |
| Library | Pure Blackjack, Sudoku, algebra, and Tetris domain logic |
| `fp-toolkit` | Main terminal commands, interactive Blackjack, and algebra REPL |
| `fp-bench` | CPU-time diagnostic comparison across every curated Sudoku puzzle |
| `fp-tetris` | Separately scoped terminal Tetris game loop |

The package depends only on `base` and `containers`; the test suite adds
QuickCheck. There is no web, GUI, or external-service runtime.

## Verification contract

Run the complete local quality gate with:

```bash
cabal check
cabal build all
cabal test all
```

The tests combine focused examples with generated properties:

- Blackjack shuffling preserves every card;
- algebra simplification and rendering preserve expression meaning;
- Sudoku bounded search respects its requested limit;
- Sudoku examples cover parser failure, compact interchange, classification,
  catalogue lookup, ratings, and next-decision hints; and
- Tetris examples cover hard-drop spawning, seven-bag ordering, hold, timed
  gravity, line clearing, preview, level progression, and wall collision
  behaviour.

GitHub Actions runs the build and test suite for pushes and pull requests.

## Change standard

A change is ready to publish only when its domain behaviour is represented in
the pure library, its terminal boundary stays small, relevant regression tests
pass, and the documented command remains accurate. This keeps the toolkit
cohesive as it grows.
