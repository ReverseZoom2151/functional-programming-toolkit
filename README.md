# Functional Programming Toolkit

A modern, buildable Haskell project grown from the most useful work in the
COMS10016 Functional Programming course archive. It turns selected coursework
into small, composable examples of pure modelling, search, and normalisation.

## What is here

- `src/Functional/Blackjack.hs` — a pure Blackjack rules engine with correct
  multi-ace scoring and deterministic rounds.
- `src/Functional/Sudoku.hs` — a 9×9 Sudoku parser, bounded backtracking
  solver, and uniqueness diagnostics.
- `src/Functional/Sudoku/Catalogue.hs` — named, searchable built-in puzzles.
- `src/Functional/Algebra.hs` — symbolic single-variable expressions and
  canonical polynomial simplification.
- `app/Main.hs` — a small command-line interface.
- `test/Main.hs` — example and QuickCheck property tests for public behaviour
  and invariants.
- `resources/` — the original course archive, retained locally as reference
  material but excluded from Git so the maintained project stays focused.

## Quick start

Install GHC and Cabal, then run:

```bash
cabal test
cabal run fp-toolkit -- blackjack
cabal run fp-toolkit -- blackjack-demo
cabal run fp-toolkit -- simplify-demo
cabal run fp-toolkit -- simplify "2 * x^2 + x - 3"
cabal run fp-toolkit -- evaluate 4 "2 * x^2 + x - 3"
cabal run fp-toolkit -- puzzles
cabal run fp-toolkit -- puzzles starter
cabal run fp-toolkit -- puzzle hard
cabal run fp-toolkit -- sudoku examples/easy-sudoku.txt
cabal run fp-toolkit -- sudoku --diagnose examples/easy-sudoku.txt
```

## Design

The public modules keep the interesting logic pure and isolate I/O in the CLI.
That makes the rules engine, solver, and simplifier easy to test and reuse.
See [the migration audit](docs/AUDIT.md) for the project boundary and the status
of the historical material. [The concept map](docs/CONCEPT_MAP.md) explains
which course ideas were promoted into the toolkit, which remain local reference
material, and why.

### Algebra input

The algebra commands accept integers, `x`, `+`, `-`, `*`, parentheses, and
non-negative powers of `x`, such as `2 * x^2 + x - 3`. Quote expressions in
your shell so their spaces and operators are passed to the program unchanged.

### Sudoku catalogue and diagnostics

`puzzles` lists the curated catalogue; add a query to search names and
descriptions. `puzzle NAME` solves a named puzzle and reports whether it has
no solution, a unique solution, or multiple solutions. The `--diagnose` form
provides the same bounded diagnostic for a puzzle file.

## Development

```bash
cabal build all
cabal test all
```

The library and executable intentionally use only `base`. The test suite adds
QuickCheck for property-based verification; Cabal fetches it automatically.

The interactive Blackjack game uses a seedable pseudo-random shuffle, so the
rules and deck handling remain deterministic and testable; it is intended for
local play, not security-sensitive randomness.
