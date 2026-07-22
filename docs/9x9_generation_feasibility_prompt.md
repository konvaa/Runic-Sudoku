# 9×9 Generation Feasibility Spike — Prompt pro Fable

## Kontext (pro tebe, ne pro Fable)
GPT i já jsme se nezávisle shodli, že skutečné riziko Chapter 2+ není UI nebo progression tabulka, ale nevyzkoušená otázka: umí současný generator/solver vůbec vyrobit validní, jednoznačně řešitelný, kalibrovatelný 9×9 puzzle. Tenhle prompt oproti GPT draftu navíc: znovupoužívá `BoardConfig`/`PuzzleGenerator` z Batch 2 místo nového kódu, znovupoužívá `elderFutharkNineSet`, rozšiřuje existující `tool/` skripty místo psaní nových, a zužuje `requireSymbolCount` fix na minimální scope.

**Branch — jiná logika než u 12×12 UX spike.** Ten byl čistě zahoditelný. Tenhle ne — pokud generování funguje, stává se to reálným základem Chapter 2. Použij novou branch odvozenou od `feature/chapter-system-inventory`:

```
git checkout feature/chapter-system-inventory
git checkout -b feature/9x9-generation-feasibility
```

Po review sloučit zpět do `feature/chapter-system-inventory`, ne zahodit.

---

## Prompt pro Fable (zkopírovat celé níže)

**Goal**
Determine whether 9×9 puzzle generation and solving is feasible with the current architecture, and identify exactly what changes are required. This is a feasibility investigation, not Chapter 2 implementation.

**Branch strategy**
- Create and work only on a separate branch: `feature/9x9-generation-feasibility`.
- Base it on `feature/chapter-system-inventory` (includes Batch 2 / `BoardConfig`).
- Do not commit directly to `feature/chapter-system-inventory`.
- Do not merge back automatically. Stop after producing the feasibility result and wait for review.

**Scope — do not do**
- Do not build any Chapter 2 UI (9×9 board rendering, input panel, etc).
- Do not modify the production release branch.
- Do not register 9×9 in any shipped manifest, theme, or level pool.
- Do not deep-recalibrate `DifficultyTuning` constants for 9×9 — that is a separate, dedicated task requiring its own review. For this spike, only report a first read on whether difficulty tiers feel differentiated.
- Do not write a new/parallel generator implementation.

**Reuse existing infrastructure**
- `PuzzleGenerator` already accepts a `board: BoardConfig` parameter (Batch 2). Construct `BoardConfig(rows: 9, cols: 9, boxRows: 3, boxCols: 3, runeCount: 9)` and run the existing generator against it.
- Use `elderFutharkNineSet` (`lib/core/theme/rune_set.dart`, committed in Batch 2 — confirmed present) as the 9-symbol rune set. Do not create a new one.
- Extend existing dev tooling — `tool/generator_audit.dart` and `tool/calibrate_difficulty.dart` — with the 9×9 `BoardConfig` above, rather than writing new one-off test scripts. Both already accept a board parameter as of Batch 2.

**First blocker to resolve (scoped, minimal)**
- Step 0 inventory flagged: `requireSymbolCount` throws for `maxValue > 6`. Investigate this specifically and apply the minimal fix needed to support `runeCount = 9`. Do not perform a general refactor of the validation path — just unblock this one constraint.

**Test**
- Generate a small sample (10–20) of 9×9 puzzles across existing difficulty tiers, using the reused generator + 9×9 `BoardConfig` above.
- For each puzzle: confirm the board is valid, confirm the solution is unique, record generation time, and record which solver technique(s) were used (or whether it fell back to brute-force/backtracking).

**Stop condition**
If 9×9 generation fails because of a deeper architectural issue (not just the scoped `requireSymbolCount` fix), stop and report the blocker. Do not broadly rewrite `PuzzleGenerator`, `HumanLikeSolver`, `DifficultyTuning`, save logic, UI, or validation without review — surface the finding instead.

**Ignore for now**
Chapter 3, 4×3 boards, cursed/locked/sealed mechanics, expert pools. Out of scope — noise for this specific question.

**Report back**
1. Did `requireSymbolCount` block `runeCount = 9`? What was the minimal fix (if any)?
2. Generation metrics: number of attempts, number of successful puzzles, rejected candidates, attempts per successful puzzle, average generation time, max generation time.
3. Uniqueness validation pass/fail rate across the sample.
4. Does `HumanLikeSolver` solve 9×9 puzzles with human-style techniques, or does it fall back to brute-force?
5. First-read only: do the difficulty tiers feel differentiated at 9×9, or do they collapse together?
6. Files touched, and which of the Step 0 high-risk items (1–5) this work resolves vs. leaves untouched.
7. Example(s) of generated 9×9 puzzles, if successful.
8. Explicit verdict, one of:
   - **Green** — 9×9 generation works, uniqueness holds, performance is acceptable.
   - **Yellow** — it generates, but difficulty separation, speed, or solver behavior is borderline.
   - **Red** — the current architecture is more tightly bound to 6×6 than expected; roadmap needs to slow down and fix generator/solver architecture first.
9. Recommended next scoped step (not "fix everything" — name the specific next item).
