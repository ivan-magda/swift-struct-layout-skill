# Layout model and candidate selection

Use this reference to reason about padding and choose comparisons. In a source-only review, apply the model only under explicit assumptions and report hypotheses; compilation belongs to a requested measurement or optimization task.

## The three metrics

- `size`: bytes in the inline representation, including internal gaps.
- `stride`: distance between successive values in contiguous storage, including end rounding.
- `alignment`: the address alignment required for the value.

`MemoryLayout<T>` describes the representation of `T`, not its referenced allocations, CoW buffers, or total application footprint. An optimizer can also eliminate a local value or keep its parts in registers. [MemoryLayout](https://developer.apple.com/documentation/swift/memorylayout)

For ordinary native Swift aggregates with known field layouts, use this model:

```text
cursor = 0; A = 1
for each actual stored instance field in candidate order:
    offset = roundUp(cursor, field.alignment)
    cursor = offset + field.size
    A = max(A, field.alignment)
size = cursor
alignment = A
stride = max(1, roundUp(size, A))
```

This explains the current sequential implementation for suitable types; declaration order is not a universal language guarantee, including for `@frozen`. Frozen ABI obligations are a separate question: see [compatibility](compatibility.md). Empty fields may have observed key-path offsets different from the model cursor. Special aggregate alignment or storage needs a different model. Validate the baseline against the actual type before relying on candidate predictions. [ABI layout](https://github.com/swiftlang/swift/blob/main/docs/ABI/TypeLayout.rst), [IRGen implementation](https://github.com/swiftlang/swift/blob/main/lib/IRGen/StructLayout.cpp), [SE-0260 guarantees](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0260-library-evolution.md#guarantees)

## Nested values and misleading padding metrics

Advance by a native Swift child's **size**, not its stride. A subsequent parent field can occupy the child's tail padding if its alignment permits. It cannot fill arbitrary holes inside the child's representation. Imported C records retain their actual C layout; do not assume the same tail reuse. [ABI layout](https://github.com/swiftlang/swift/blob/main/docs/ABI/TypeLayout.rst), [Clang record layout implementation](https://github.com/swiftlang/swift/blob/main/lib/IRGen/GenStruct.cpp)

These are model examples assuming 8-byte `UInt64`/`Int64` alignment and 1-byte `Bool`/`UInt8` storage. They are not measurements of the user's project:

| Field order | Size | Stride | Consequence |
| --- | ---: | ---: | --- |
| `Bool, Int64, Bool, Int64` | 32 | 32 | Zero tail padding still hides internal gaps |
| `Int64, Int64, Bool, Bool` | 18 | 24 | Reordering can reduce the slot |
| `Int64, Bool` | 9 | 16 | Seven tail bytes alone do not imply a smaller attainable stride |
| Child: `UInt8, UInt64` | 16 | 16 | Baseline child |
| Child: `UInt64, UInt8` | 9 | 16 | Same stride, smaller inline child |
| Parent: baseline child followed by seven `UInt8` fields | 23 | 24 | Parent before |
| Parent: reordered child followed by seven `UInt8` fields | 16 | 16 | Useful parent improvement |

Thus `stride - size` measures tail rounding, not removable waste. Even `stride - sum(field.size)` only measures padding at the current level; field sizes include their own internal gaps. Follow a child size reduction through the significant parents and wrappers. Compare a child reorder before proposing flattening or replacing the representation.

## Strict counterexample to alignment sorting

Take fields `wide`, `word`, `bytes` with `(size, alignment)` of `(9,8)`, `(4,4)`, `(3,1)`. For example, `wide` can be a native `{UInt64, UInt8}` and `bytes` three `UInt8` fields.

| Order | Offsets | Size | Stride |
| --- | --- | ---: | ---: |
| `wide, word, bytes` (alignment 8→4→1) | 0, 12, 16 | 19 | 24 |
| `wide, bytes, word` (alignment 8→1→4) | 0, 9, 12 | 16 | 16 |

There are no equal alignments to explain away the failure. Descending alignment is a useful candidate, not a general optimum. Under the ordinary model, when every field size is a multiple of its alignment and alignments form the usual nested powers of two, descending alignment reaches the stride lower bound. Nested fields can violate that premise.

## Choose the objective, then bound the search

1. Name the important storage: element stride for `[T]`, child size plus actual parent layout for embedding, or the full `T?`/enum/existential representation. State required targets, concrete generic substitutions, and order constraints.
2. Always include the original order. Compare descending alignment and a few targeted moves that let small fields follow a child with a reusable tail. Preserve meaningful groups and comments where possible.
3. For a small case, enumerate allowed permutations within an explicit time or candidate budget. For larger cases, use bounded heuristics. Report the explored space and whether the result is the best found or proven within that model.
4. Use `max(1, roundUp(sum(field.size), maxAlignment))` as an ordinary-model stride lower bound. It may be unattainable. Reaching it proves minimum modeled stride, not minimum size, minimum edits, best parent layout, or fastest execution. Continue comparing if a secondary size/parent objective remains.
5. Prefer a less disruptive candidate among equivalent useful results. Define any edit-distance tie-break before claiming a minimum: grouping identical `(size, alignment)` fields can discard a better arrangement of named properties. There is no universal optimum or minimal-diff promise across targets and constraints.
6. For a measured task, compile and measure selected final candidates in their real context, then recheck affected parents/wrappers. Arithmetic search does not require compiling every permutation. Smaller stride alone proves no CPU speedup.

## Inputs that require extra care

| Input | Required treatment |
| --- | --- |
| Wrappers, macros, `lazy`, `#if`, generated declarations | Determine actual stored instance fields, including backing storage and active configuration. Computed and static properties are not instance fields. `Mirror` may be customized and is not a complete physical-storage inventory. |
| `MemoryLayout.offset(of:) == nil` | Record unavailable through this API; it means neither offset zero nor absent storage. Do not manufacture a numeric offset. [Offset API](https://developer.apple.com/documentation/swift/memorylayout/offset(of:)) |
| Generic or resilient fields | Measure concrete substitutions and relevant module boundaries. Neither a type name nor `@frozen` guarantees compile-time-known size. [SE-0260](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0260-library-evolution.md#guarantees), [metadata](https://github.com/swiftlang/swift/blob/main/docs/ABI/TypeMetadata.rst) |
| `Optional` and enum payloads | Measure the enclosing representation. Extra inhabitants, spare bits, and padding are distinct; `T?` is not universally `T` plus a Boolean. Padding is not application-owned storage. [Enum layout](https://github.com/swiftlang/swift/blob/main/docs/ABI/TypeLayout.rst), [runtime metadata](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/Metadata.cpp) |
| SIMD and special storage | Use measured size/alignment, not logical lane count. Current standard `SIMD3` uses four-lane storage; its unused lane is not automatically reusable tail padding. Raw-layout, over-aligned, noncopyable synchronization, and intentional separation cases need specialized reasoning. [SIMD definitions](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/SIMDVectorTypes.swift.gyb), [SE-0229](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0229-simd.md) |

Compiler-source links describe implementations on moving branches. Confirm behavior with the project's actual toolchain rather than treating those links as version-independent numeric tables.
