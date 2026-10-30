# Source-only triage

Use this for quick reviews and requested module/app audits. The product is a justified shortlist, not a patch or a claim of measured savings. Read-only source inspection needs no Swift compiler invocation, interpreter, dependency resolution, tests or benchmark. Existing profiling/layout artifacts may help; identify their date, inputs and configuration instead of treating them as current by default.

## Bound the inspection

Identify the requested source roots/modules and exclusions. Read applicable project instructions and build settings as text. A source-only audit can proceed when the project cannot build. Do not start a build-aware indexing service if doing so would compile or resolve dependencies beyond this mode.

Use the available file and symbol search tools. With a shell, a starting point is:

```sh
rg --files Sources -g '*.swift' -g '!**/.build/**' -g '!**/Generated/**'
rg -n '\bstruct\b|\btypealias\b' Sources -g '*.swift'
```

Adapt roots and generated-file exclusions to the actual project. This is discovery, not a complete Swift parser: macros, conditional branches, multi-binding declarations, inferred types and generated storage need closer inspection. Count declarations only when the count is reproducible; never turn a regex match count into proof of complete physical-storage coverage.

For a selected type, follow usages far enough to distinguish a single instance, many array elements, a header shared by a buffer, and a child embedded in many parents. A million elements in a collection do not imply a million copies of its header. A class's `MemoryLayout` describes its reference, not the instance body; class-instance packing is outside this workflow.

## Rank opportunities

Consider these together, without an invented weighted score:

| Evidence | Implication |
|---|---|
| Large live value buffer, explicit memory budget or retained parent array | Small slot savings may matter; name the source of the count/budget |
| Small fields interrupt aligned fields | Possible internal padding; consider a reorder |
| Nested value, Optional or payload with size not divisible by alignment | A child size reduction may improve enclosing storage; sorting alone can miss candidates |
| Rare/single value or tiny bounded list | Layout savings may not justify compatibility work |
| String, Array, Data or class references | Inline layout is only part of ownership; payload memory may dominate |
| Frozen/exported type, raw consumers, generated source, intentional spacing | Investigate the contract or generator before recommending a rewrite |

Distinguish source bounds from observations: `limit = 100` in one fetch path does not establish the total live count in the process. A loop or UI callback is not proof of CPU hotness. When scale is unknown, report potential savings per slot or defer arithmetic.

Avoid two tempting filters: a large `stride-size` gap can be unavoidable tail padding, while a zero gap can hide internal holes. Do not ignore a child merely because its own stride is already at a lower bound. See [layout](layout.md) for examples.

## State the evidence level

For simple fully described fields, explain a possible order and optionally compute a conditional layout. A numeric finding has three parts: the input sizes/alignments and target assumptions, the exact named candidate order, and a checked offset/size/stride calculation for that order using [the layout model](layout.md). Include a compact offset sequence when it makes the claim auditable. Sum of field sizes is a lower bound, not generally the candidate's size: alignment can introduce gaps after a child or Optional. Lightweight arithmetic (including a calculator or small arithmetic script) is compatible with source-only review; Swift compilation is not. A qualitative candidate is sufficient when numeric inputs are missing. For SDK/resilient types, wrappers, macros, lazy storage or unspecified generic substitutions, name the missing data instead of filling a universal size table.

Do not infer byte-for-byte compatibility from a declaration or from a successful search for unsafe API names. Before an actual change, use [compatibility](compatibility.md).

For a broader audit, give the best-supported few candidates first, then explain what was excluded or uncertain. A short result can be:

> `Telemetry.Event`, retained in `History.events`, is worth measuring: a byte-sized flag separates aligned fields and the documented window holds many events. Try grouping flags while preserving initializer semantics. Exact stride and total capacity are unmeasured. Next: one probe for Event and its hot parent in the shipping configuration.

If no candidate is persuasive, say “No worthwhile candidate found in the inspected scope,” with the scope and reasons. That is a completed review. Propose a targeted deeper check only when it could change the decision; do not make full profiling a ritual before any local layout investigation.
