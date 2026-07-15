<div align="center">

# Functional Programming Toolkit

### A small, tested Haskell playground for games, constraint solving, and symbolic algebra.

[![Haskell CI](https://github.com/ReverseZoom2151/functional-programming-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ReverseZoom2151/functional-programming-toolkit/actions/workflows/ci.yml)

</div>

`functional-programming-toolkit` is a buildable Haskell project with three
complete, terminal-friendly domains. Each one keeps the important behaviour
pure, exposes a focused API, and is backed by examples plus property tests.

| Domain | What you can do | Functional idea |
| --- | --- | --- |
| **Blackjack** | Play a terminal game or simulate deterministic rounds | Algebraic data types and explicit state transitions |
| **Sudoku** | Solve files or named puzzles; distinguish no/unique/multiple solutions | Backtracking search with bounded exploration |
| **Algebra** | Parse, evaluate, and canonicalise single-variable expressions | Recursive ASTs and normal forms |

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
fp-toolkit simplify EXPRESSION
fp-toolkit evaluate VALUE EXPRESSION
```

Algebra input supports integers, `x`, `+`, `-`, `*`, parentheses, and
non-negative powers of `x`. Quote expressions in your shell.

## Project layout

```text
src/Functional/
  Blackjack.hs          Pure game rules and seedable shuffle
  Sudoku.hs             Parser, solver, and bounded diagnostics
  Sudoku/Catalogue.hs   Searchable named puzzle collection
  Algebra.hs            Expression parser, evaluator, and normaliser
app/Main.hs             Command-line boundary
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

The library and executable use only `base`. The test suite adds QuickCheck and
checks 100 generated cases for each of these invariants:

- shuffling preserves every card in a deck;
- simplification preserves expression evaluation;
- rendered algebra parses back to the same meaning; and
- Sudoku's bounded solver never exceeds its requested limit.

GitHub Actions runs the build and test suite on every push and pull request.

## From course archive to maintained project

The project began as selected COMS10016 Functional Programming coursework.
The original files remain in local-only `resources/` for reference; they are
not part of the build. The maintained codebase is deliberately narrower and
complete.

- [Concept map](docs/CONCEPT_MAP.md) — why each course idea was adopted,
  deferred, or kept as reference material.
- [Migration audit](docs/AUDIT.md) — the original archive’s status and the
  maintained project boundary.

---

The name **Functional Programming Toolkit** is intentional: it describes a
growing set of small, complete Haskell programs without tying the repository to
one game, one assignment, or one course module.
