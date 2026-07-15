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
| `resources/tetris/` | Framework is present, but shape primitives and game loop are unfinished; UI needs extra packages | Retained as archived future work |
| `resources/power/`, `resources/worksheets/`, `resources/bonus_worksheets/` | Learning exercises, some deliberately incomplete | Retained as archive |
| `resources/lectures & notes/`, `resources/higher_order/`, `resources/embedding/` | Lecture examples and specialised experiments | Retained as archive |

## Why this boundary

Finishing every historical worksheet would blur the project’s purpose and
would force unrelated, old teaching APIs into one build. The maintained package
instead demonstrates three complementary functional-programming techniques:

1. algebraic data modelling and pure state transitions (Blackjack);
2. constraint propagation through pure search (Sudoku); and
3. recursive data types plus canonical representations (Algebra).

## Next milestones

- Add property tests.
- Add an interactive Blackjack front end with injectable randomness.
- Consider a separate `tetris` package only after its unfinished shape layer
  has been independently completed and tested.
