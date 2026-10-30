---
name: swift-struct-layout-skill
description: Use when reviewing or optimizing native Swift struct memory layout, padding, MemoryLayout size/stride/alignment, large value buffers, or layout regressions; for a selected type or a requested module/app audit. Also relevant when designing a high-volume value type. Not triggered by SwiftUI screen layout or the mere presence of a struct.
---

# Swift struct layout

Find worthwhile, permissible layout changes. Match the evidence to the claim: a smaller element slot does not establish lower process footprint or faster code.

## Choose depth from the request

Scope (type, module, app), depth, and permission to edit are independent.

| Request | Work and result |
|---|---|
| Quick review, audit, find candidates | **Source-only by default.** Read declarations and usages; return ranked hypotheses, evidence, unknowns, and the next useful measurement |
| Confirm layout, optimize and verify | Measure the real type in the relevant configuration; compare permitted candidates. Edit only when the task authorizes it |
| Prove speed or footprint improvement | Measure the specified workload/metric; layout alone is insufficient |

Source-only review runs **no Swift compilation or interpretation, project builds, tests, or benchmarks**. A completed shortlist, including no worthwhile candidates, is a full result. If deeper work is useful, propose the concrete next check. Already-authorized optimization includes necessary ordinary local verification; do not add repeated approval gates. Respect explicit no-build/no-edit limits and time budgets.

## Source-only review

Use [triage](references/triage.md) for broad audits and prioritization. For each worthwhile candidate provide:

- Type/location and relevant storage or consumer.
- Why it matters: supported live count, hot parent, budget, or workload evidence.
- A plausible minimal change, compatibility concern, and unknowns.
- What measurement would decide whether to proceed.

Mark arithmetic as a **model with assumptions**. A numeric finding pairs the exact proposed field order with a checked offset/size calculation; use [the layout model](references/layout.md). Unknown field layouts stay unknown; a qualitative candidate needs no invented byte count. Report inspected scope and exclusions; uninspected or opaque types are not proven optimal. References' example numbers are not measurements of the user's project.

## Confirm and change

1. **Choose the metric.** Arrays usually pay stride; embedding may benefit from smaller size at unchanged child stride. Check relevant parents, concrete generic substitutions, Optional or enum representations. Keep external allocations separate from inline storage.
2. **Establish permissible changes.** Read [compatibility](references/compatibility.md) before editing: released ABI, external schemas, `Type.init` references, argument/default-expression effects, codecs and order-sensitive consumers. Preserve existing contracts and authorization.
3. **Measure actual storage.** Follow [measurement](references/measurement.md). Record compiler, language mode, target/SDK, build configuration and method. Resolve wrappers/macros/lazy/conditional fields. `offset(of:) == nil` means unavailable, not zero. A copied declaration is an experiment, not validation of its original module.
4. **Compare bounded candidates.** Read [layout](references/layout.md) when reasoning about packing. Include the original order. Alignment-sort is a candidate, not a general optimum; `stride-size` is not an opportunity filter. Try a child reorder before replacing a nested representation. Validate the model against the baseline, then compile promising candidates; not every permutation needs compilation.
5. **Verify the authorized result.** Preserve values and observable effect order, not just compilation. Recheck final layout and affected consumers/tests. Batch compatible probes, retain valid build caches, and avoid clean builds by default. Do not reuse stale layout output after relevant source/configuration changes.

Finish without changes when benefit is absent, immaterial, or blocked by a contract. With an unavailable target, return useful analysis and explicit unperformed checks. Widening/narrowing fields, bit packing, SoA and schema migration need their own justification; they are not automatic reorder steps.

## Report the result

State scope/depth and the decision first. Include evidence or labeled assumptions; measured before/after and environment when available; actual changes and checks; remaining uncertainty and the next step if needed.

`count × Δstride` estimates occupied element-slot savings. Capacity, allocator overhead, owned buffers, process footprint and time require their respective evidence. Add a persistent layout test only for a real budget or representation contract, not an incidental observed number.

For a standalone illustration, see [the runnable probe](examples/layout-probe.swift) and its [running instructions](references/measurement.md#run-the-supplied-standalone-example).
