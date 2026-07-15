<div align="center">

# Functional Programming Toolkit

### A tested terminal Haskell toolkit for games, constraint solving, and symbolic algebra.

[![Haskell CI](https://github.com/ReverseZoom2151/functional-programming-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ReverseZoom2151/functional-programming-toolkit/actions/workflows/ci.yml)

</div>

`functional-programming-toolkit` is a buildable Haskell project with four
complete, terminal-friendly domains. Each one keeps the important behaviour
pure, exposes a focused API, and is backed by examples plus property tests.

| Domain | What you can do | Functional idea |
| --- | --- | --- |
| **Blackjack** | Play a terminal game or simulate deterministic rounds | Algebraic data types and explicit state transitions |
| **Sudoku** | Solve four curated puzzles or files; diagnose solutions and request the next hint | Backtracking search with bounded exploration |
| **Algebra** | Parse, evaluate, expand, factor, differentiate, and canonicalise expressions | Recursive ASTs and normal forms |
| **Tetris** | Play a separately scoped terminal game with preview and levels | Pure state machine, collision checking, and rendering |

## Run it

You need [GHC](https://www.haskell.org/ghc/) and
[Cabal](https://www.haskell.org/cabal/). Then:

```bash
git clone https://github.com/ReverseZoom2151/functional-programming-toolkit.git
cd functional-programming-toolkit
cabal test
```

Try the interactive Blackjack game:

```bash
cabal run fp-toolkit -- blackjack
```

Explore the bundled Sudoku catalogue and solve a puzzle:

```bash
cabal run fp-toolkit -- puzzles
cabal run fp-toolkit -- puzzle hard
```

Work with an expression directly from the terminal:

```bash
cabal run fp-toolkit -- simplify "2 * x^2 + x - 3"
# ((-3 + x) + (2 * x^2))

cabal run fp-toolkit -- evaluate 4 "2 * x^2 + x - 3"
# 33
```

Open the algebra REPL or the standalone Tetris executable:

```bash
cabal run fp-toolkit -- repl
cabal run fp-tetris
```

The Tetris controls are `l`, `r`, `u` (rotate), `d` (down), `drop` or a space
to hard-drop, and `q` to quit. The header previews the next tetromino and
shows score, cleared lines, and level (which rises every ten lines). Its game
rules are pure; the executable only owns the input loop and terminal rendering.

## Why it is functional

The executable is intentionally thin. It reads a command, calls a pure module,
then prints a result. That keeps behaviour easy to understand, test, and reuse.

For example, Sudoku diagnostics stop after two solutions—the exact amount of
information needed to distinguish no solution, one solution, and many:

```haskell
diagnose :: Board -> SolverDiagnostics
diagnose board = case solveUpTo 2 board of
  []  -> SolverDiagnostics NoSolution 0 False
  [_] -> SolverDiagnostics UniqueSolution 1 False
  _   -> SolverDiagnostics MultipleSolutions 2 True
```

Likewise, algebraic simplification is a compositional pipeline rather than a
collection of ad-hoc rewrite rules:

```haskell
simplify :: Expr -> Expr
simplify = fromPolynomial . toPolynomial
```

The Tetris hard drop is also a small pure transition: it recurses only while
the active piece can fall, then locks that one piece and spawns its successor.

```haskell
step :: Action -> Game -> Game
step Drop = dropPiece
```

And the Blackjack game remains reproducible because shuffling is a pure,
seeded transformation:

```haskell
shuffleWithSeed :: Integer -> [Card] -> [Card]
```

## Command reference

```text
fp-toolkit blackjack
fp-toolkit blackjack-demo
fp-toolkit puzzles [QUERY]
fp-toolkit puzzle NAME
fp-toolkit sudoku PUZZLE_FILE
fp-toolkit sudoku --diagnose PUZZLE_FILE
fp-toolkit sudoku --hint PUZZLE_FILE
fp-toolkit simplify EXPRESSION
fp-toolkit expand EXPRESSION
fp-toolkit factor EXPRESSION
fp-toolkit evaluate VALUE EXPRESSION
fp-toolkit repl
fp-bench
fp-tetris
```

Algebra input supports integers, `x`, `+`, `-`, `*`, parentheses, and
non-negative powers of `x`. Quote expressions in your shell. In the REPL,
use `:help`, `:expand EXPR`, `:factor EXPR`, `:eval N EXPR`, `:diff EXPR`, and
`:quit`. `factor` extracts a common integer coefficient and shared power of
`x`; `expand` emits the canonical polynomial form. `fp-bench` measures every
catalogue puzzle using CPU time, so use it to compare solver changes on one
machine rather than treating timings as universal results.

## Project layout

```text
src/Functional/
  Games/                Blackjack rules and Tetris engine
  Puzzles/              Sudoku solver and searchable catalogue
  Symbolic/             Algebra parser, evaluator, normaliser, and factoring
app/Main.hs             Main toolkit command-line boundary and algebra REPL
app/TetrisMain.hs       Separately scoped terminal Tetris boundary
bench/Main.hs           Repeatable Sudoku diagnostic benchmark
test/Main.hs            Examples and QuickCheck properties
examples/               Sample Sudoku input
docs/                   Audit and architecture decisions
```

## Quality bar

```bash
cabal check
cabal build all
cabal test all
```

The library uses only `base` and `containers`; the test suite adds QuickCheck
and checks 100 generated cases for each of these invariants:

- shuffling preserves every card in a deck;
- simplification preserves expression evaluation;
- rendered algebra parses back to the same meaning; and
- Sudoku's bounded solver never exceeds its requested limit.

Focused examples also cover Tetris hard-drop, line clearing, wall behaviour,
preview, and level progression; Sudoku hints, diagnostics, and catalogue
search; plus algebra differentiation, substitution, expansion, and factoring.

GitHub Actions runs the build and test suite on every push and pull request.

## Design notes

The toolkit favours a small, reusable core and thin terminal boundaries. Its
[concept map](docs/CONCEPT_MAP.md) explains the shared architecture and the
[product boundary](docs/AUDIT.md) records what the package guarantees.

---

The name **Functional Programming Toolkit** is intentional: it describes a
growing set of small, complete Haskell programs without tying the repository to
one game or one narrow use case.
