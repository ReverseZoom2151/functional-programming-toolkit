# Functional Programming Toolkit

A modern, buildable Haskell project grown from the most useful work in the
COMS10016 Functional Programming course archive. It turns selected coursework
into small, composable examples of pure modelling, search, and normalisation.

## What is here

- `src/Functional/Blackjack.hs` — a pure Blackjack rules engine with correct
  multi-ace scoring and deterministic rounds.
- `src/Functional/Sudoku.hs` — a 9×9 Sudoku parser and backtracking solver.
- `src/Functional/Algebra.hs` — symbolic single-variable expressions and
  canonical polynomial simplification.
- `app/Main.hs` — a small command-line interface.
- `test/Main.hs` — smoke tests for the public behaviours and edge cases.
- `resources/` — the original course archive, retained locally as reference
  material but excluded from Git so the maintained project stays focused.

## Quick start

Install GHC and Cabal, then run:

```bash
cabal test
cabal run fp-toolkit -- blackjack-demo
cabal run fp-toolkit -- simplify-demo
cabal run fp-toolkit -- sudoku examples/easy-sudoku.txt
```

## Design

The public modules keep the interesting logic pure and isolate I/O in the CLI.
That makes the rules engine, solver, and simplifier easy to test and reuse.
See [the migration audit](docs/AUDIT.md) for the project boundary and the status
of the historical material.

## Development

```bash
cabal build all
cabal test all
```

The project intentionally uses only `base`, so a fresh GHC/Cabal installation
is sufficient to build it.
