# Concept map: one toolkit, four pure domains

## Product thesis

**Functional Programming Toolkit** is a collection of complete,
terminal-friendly Haskell programs. Each domain keeps its rules in a pure,
reusable library module; executables only handle input, output, and process
boundaries.

```
                 terminal commands
                         │
       ┌─────────────────┴─────────────────┐
       │                                   │
 app/Main.hs                       app/TetrisMain.hs
 toolkit CLI + REPL                 standalone game loop
       │                                   │
 ┌─────┼──────────────┐                    │
 │     │              │                    │
Blackjack  Sudoku   Algebra              Tetris
rules      search   symbolic AST          board state
       │     │          │                    │
       └─────┴──────────┴────────────────────┘
                         │
                 examples + properties
```

## Shared contract

Every maintained domain has:

1. an explicit domain model;
2. pure transformations that are independently testable;
3. explicit handling for invalid input or unavailable actions;
4. a deliberately thin terminal adapter where interactivity is useful; and
5. regression tests for known behaviour and edge conditions.

## Domain map

| Domain | Core module | Terminal capability | Functional focus |
| --- | --- | --- | --- |
| Blackjack | `Functional.Blackjack` | Interactive game and deterministic demo | Algebraic data types, seeded shuffle, state transitions |
| Sudoku | `Functional.Sudoku`, `Functional.Sudoku.Catalogue` | File solving, diagnostics, hints, named-puzzle search | Constraint search, bounded exploration, `Map` indexing |
| Algebra | `Functional.Algebra` | Simplify/evaluate commands and a REPL | Recursive ASTs, polynomial normal forms, substitution |
| Tetris | `Functional.Tetris` | Standalone `fp-tetris` game | Immutable board transitions, collision rules, rendering |

## Capability map

| Capability | Entry point | Evidence |
| --- | --- | --- |
| Reproducible Blackjack rounds | `shuffleWithSeed`, `playRound` | Unit examples and a deck-preservation property |
| Sudoku solution classification | `diagnose`, `solveUpTo` | Unique, impossible, and ambiguous puzzle tests |
| Explainable Sudoku next step | `nextHint`, `sudoku --hint FILE` | Known constrained-cell example |
| Search performance signal | `fp-bench` | CPU-time measurement of the bundled hard puzzle |
| Symbolic exploration | `differentiate`, `substitute`, `fp-toolkit repl` | Parser, semantic, and derivative examples |
| Terminal Tetris | `fp-tetris` | Hard-drop and wall-boundary regression tests |

## Product boundary

The package is intentionally terminal-first and dependency-light. It does not
contain a web application or graphical interface. New capabilities belong here
only when they add a coherent reusable domain or make an existing domain more
correct, understandable, or maintainable.

Promising future work is therefore guided by evidence, not feature count:

- extend the curated Sudoku set only alongside tests and solver measurements;
- add algebra operations only when they preserve the canonical-expression
  model and semantic properties; and
- improve Tetris gameplay only with corresponding pure-engine tests.
