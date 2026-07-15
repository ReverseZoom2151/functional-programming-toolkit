# Concept map: turning the course archive into one project

## Product thesis

**Functional Programming Toolkit** is a small collection of complete,
terminal-friendly programs whose important behaviour is pure, testable, and
reusable. It is not a repackaging of every worksheet. The local `resources/`
archive is the course's source material; the maintained package adopts only the
ideas that improve the product or its engineering discipline.

```
Course archive (local resources/)
        │
        ├── domain modelling ──> Blackjack rules engine
        ├── search + safe failure ──> Sudoku solver
        ├── recursion + normal forms ──> Algebra engine
        ├── folds / laws / test design ──> module tests and invariants
        └── specialised experiments ──> separately scoped future demos
```

## Selection rule

An archived idea is promoted only when it satisfies all three conditions:

1. It creates a clear user capability or materially improves correctness,
   maintainability, or testability.
2. It fits the package's pure-core/thin-CLI architecture without adding an
   unrelated runtime or teaching-only API.
3. It can be completed and verified to production-quality behaviour.

This prevents the project from becoming an unmaintainable museum of exercises.

## Archive-to-product map

| Archive area | Strong idea | Product decision | Concrete destination |
| --- | --- | --- | --- |
| `blackjack/` and card examples | Algebraic card model, deterministic deck operations, game loop separation | **Adopted** | `Functional.Blackjack`; pure rounds plus the interactive CLI |
| `sudoku/` and `lists.hs` | Candidate sets, constraint checking, recursive search | **Adopted** | `Functional.Sudoku`; parser, solver, and solution rendering |
| `simplify/` and `poly.hs` | Expression ASTs, polynomial normalisation, semantic properties | **Adopted** | `Functional.Algebra`; parser, evaluator, and canonical simplifier |
| Worksheets 1–4; pattern-matching, functions, tuples, records, guards | Types that make illegal states hard to represent; total pattern matching | **Adopted as a design standard** | Public types and explicit `Either String` failure paths; no duplicate tutorial module |
| Worksheets 5–6; `folds.hs`; `binary_trees.hs` | Structural recursion, folds, tree recursion, inductive properties | **Adopted as an implementation/test standard** | Algebra normalisation and solver traversal stay recursive and receive behavioural tests; extract a generic tree API only when a product feature needs one |
| Worksheets 7; `example_io.hs` | Keep file/terminal I/O at the boundary | **Adopted as an architecture standard** | `app/Main.hs` owns input/output; library modules remain pure |
| Worksheets 8–9; `functors.hs`, `applicatives.hs`, `monads.hs`, `monad_laws_checker.hs` | Contextual computation, validation, composition, law-driven testing | **Use selectively** | Future command parsing and richer validation may use `Either`; add property/law testing when an abstraction is introduced, not before |
| `bonus_worksheets/bonus_1.hs` | Recursion and list proofs | **Reference only** | Existing tests are clearer than reproducing educational derivations in the public API |
| `bonus_worksheets/bonus_2.hs` and `monoids.hs` | Semigroups, monoids, compositional aggregation | **Future utility only** | Add an aggregate score/statistics feature only if the CLI gains sessions or reports |
| `bonus_worksheets/bonus_3.hs` | `Map`-backed tries and sets | **Future feature candidate** | A dictionary/autocomplete or puzzle catalogue module, if the toolkit gains searchable saved content |
| `higher_order/`, `map.hs`, `function_composition.hs` | Higher-order transformations and point-free composition | **Adopted as style guidance** | Use when it improves clarity; do not add a standalone reimplementation of Prelude |
| `power/` and `measure_time.hs` | Comparing equivalent algorithms and measuring cost | **Future engineering tool** | Add a benchmark suite only when Sudoku/search performance warrants an evidence-based optimisation |
| `tetris/` | State machine, shape invariants, rendering boundary, score bookkeeping | **Separate future demo** | Rebuild as its own executable after completing the shape API and choosing a supported UI; do not import incomplete `CodeWorld`/ANSI dependencies into the toolkit core |
| `embedding/` | Typed domains and hardware-oriented embedding with Clash | **Separate future repository or package** | Valuable, but its `Clash` dependency and domain do not serve the terminal toolkit |
| `lectures & notes/cheatsheet.hs`, `functional_recipes.hs`, basic declarations | Pedagogical explanations and incomplete walkthroughs | **Archive only** | Link or cite them from future learning notes; never compile them as production code |

## Cohesive architecture

```
                 app/Main.hs
        command parsing + terminal interaction
                           │
     ┌─────────────┬───────┴─────────┬─────────────┐
     │             │                 │             │
Blackjack      Sudoku             Algebra      future domains
pure state     parse/search        parse/normalise   (separate modules)
rules          constraints         expressions
     │             │                 │
     └─────────────┴─────────────────┴─────────────┘
                    tests + invariants
```

All maintained domains follow the same contract:

- an explicit domain model;
- pure transformations that can be tested independently;
- explicit error values for invalid input or unavailable actions;
- an optional CLI adapter; and
- tests for a known result, an edge case, and an invalid input path.

## Value-led roadmap

### Next, if the toolkit grows

1. **Puzzle catalogue** — use the `Map`/trie work to provide named built-in
   Sudoku puzzles and simple prefix lookup. This earns the data-structure
   complexity through a real CLI capability.
2. **Solver diagnostics** — expose solution counts/uniqueness and simple
   search statistics. This makes the Sudoku material more useful and creates a
   natural place for folds and monoidal aggregation.
3. **Property tests** — introduce QuickCheck only when properties such as
   “shuffle preserves a deck” or “simplification preserves evaluation” are
   more valuable than hand-written examples alone.

### Deliberately deferred

- Tetris, until its unfinished shape layer has a complete specification and a
  supported renderer.
- Clash embedding, because it is a different product domain.
- A generic data-structures library, unless an actual command needs it.
- Copying lecture/worksheet definitions that duplicate Prelude or exist only as
  partially completed learning material.

## Traceability

The maintained source is intentionally independent of `resources/`, which is
ignored by Git. This map preserves the intellectual provenance without making
the build depend on an archive that contains exercises, duplicate module names,
and optional third-party teaching dependencies.
