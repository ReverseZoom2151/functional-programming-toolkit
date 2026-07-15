# Repository audit and migration plan

## Summary

The original repository is a course archive, not an application: it had no
package definition, no build entry point, no test command, and several files
were intentionally left as exercises. The new Cabal package is the maintained
product boundary; the pre-existing directories now live in the local-only
`resources/` archive.

## Source classification

| Area | Status | Migration decision |
| --- | --- | --- |
| `resources/blackjack/` | Partially working, but the deck and multiple-ace rules were incorrect | Rebuilt as `Functional.Blackjack` |
| `resources/sudoku/` | Solver framework present; core board operations unfinished | Rebuilt as `Functional.Sudoku` |
| `resources/simplify/` | Exercise skeleton with `undefined` throughout | Rebuilt as `Functional.Algebra` |
| `resources/tetris/` | Framework is present, but shape primitives and game loop are unfinished; its old UI needs extra packages | Rebuilt as dependency-free `Functional.Tetris` plus the separately scoped `fp-tetris` terminal executable |
| `resources/power/`, `resources/worksheets/`, `resources/bonus_worksheets/` | Learning exercises, some deliberately incomplete | Retained as archive |
| `resources/lectures & notes/`, `resources/higher_order/`, `resources/embedding/` | Lecture examples and specialised experiments | Retained as archive |

## Why this boundary

Finishing every historical worksheet would blur the project’s purpose and
would force unrelated, old teaching APIs into one build. The maintained package
instead demonstrates four complementary functional-programming techniques:

1. algebraic data modelling and pure state transitions (Blackjack);
2. constraint propagation through pure search (Sudoku); and
3. recursive data types plus canonical representations (Algebra).
4. immutable board transitions and collision rules (Tetris).

## Current verification and future boundary

- The toolkit has example tests plus QuickCheck invariants for its core
  domains, and GitHub Actions runs the Cabal build and test suite.
- Blackjack has a terminal front end with deterministic, seedable shuffling.
- Sudoku provides bounded diagnostics, a next-decision hint, a searchable
  curated catalogue, and a CPU-time benchmark for its diagnostic search.
- Algebra provides differentiation, substitution, and a terminal REPL.
- Tetris is a separately scoped terminal executable with a pure engine and
  regression tests for hard-drop and board-boundary behaviour.
