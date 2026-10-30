# Compatibility before a stored-property reorder

Use this reference when deciding whether a candidate is admissible. A review produces findings; a request to optimize already authorizes the necessary in-scope checks and edits. Respect explicit limits such as no builds or no source changes. Do not introduce another approval checkpoint for work the user already requested.

## ABI and ownership of the representation

Identify release history, library-evolution settings, visibility, and which clients can be rebuilt. These are separate facts:

| Context | Decision for a local reorder |
| --- | --- |
| Native local type; all consumers controlled and rebuilt | Candidate after behavior checks |
| `public`, library evolution disabled | Rebuild affected clients; `public` alone does not promise compatible replacement of a binary library |
| ABI-public, non-frozen type with library evolution | Storage may evolve; still check source API and actual external dependencies |
| Released frozen ABI in a library whose binary compatibility must be preserved | Reject the reorder within a compatible refactor, including changes to private stored fields |
| New frozen type before release | Choose and check representation before committing its ABI |
| Fixed C/GPU/disk/network/shared-memory schema | Preserve the schema; changing it requires a separately scoped migration |

ABI-public includes `public` and `@usableFromInline`. Consider `@inlinable` bodies as external clients. Platform Swift ABI stability does not automatically give each app type a separately replaceable binary-library contract. [Library evolution overview](https://www.swift.org/blog/library-evolution/), [implementation contract](https://github.com/swiftlang/swift/blob/main/docs/LibraryEvolution.rst)

`@frozen` restricts changes to a published declaration; it does not promise declaration-order bytes, C layout, trivial copying, or a statically known size for generic/resilient contents. For C layout, declare the record in C and import it. [SE-0260](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0260-library-evolution.md#guarantees)

Search actual consumers of raw dumps, hardcoded offsets, rebinding, `unsafeBitCast`, mmap, Metal buffers, persisted records, network packets, and foreign binary interfaces. Unsafe API use is an investigation trigger: dynamically derived offsets can adapt, while an external expectation of the old schema cannot. `BitwiseCopyable` does not make native memory a portable serialization format. [SE-0426](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-bitwise-copyable.md)

For manually managed storage of multiple `T` values, inspect allocation `byteCount`, binding/capacity counts, element-offset calculations, and copy lengths. Typed pointer steps use `MemoryLayout<T>.stride`. Allocate with `UnsafeMutablePointer<T>.allocate(capacity:)` or enough raw bytes for `count * stride`, with the required alignment. A reorder can expose a latent `count * size` allocation bug: `{Bool, Int64}` can change from size16/stride16 to size9/stride16 after reordering. Four full slots still need 64 bytes, while `4 * size` now allocates only 36. Fix the affected consumer within the authorized scope before keeping the reorder; otherwise retain the original layout and report the dependency. [MemoryLayout allocation guidance](https://developer.apple.com/documentation/swift/memorylayout)

Keep single-value byte views distinct from element storage: `withUnsafeBytes(of:)` correctly exposes `size` bytes, not `stride`. Check its consumers for changed lengths or external-format assumptions; do not mechanically replace every use of `size`. For affected unsafe consumers, run focused checks with Address Sanitizer when available, alongside the capacity/offset review. ASan can miss accesses through uninstrumented runtime code, so a passing run does not replace checking the byte arithmetic.

## Initializers: compilation is insufficient

Inspect `Type(...)`, contextual `.init`, `Type.init`, passed factory functions, maps, and tests. Synthesized memberwise parameter order follows stored properties, but not every declaration becomes a parameter: defaults, initialized `let` properties, access control, and custom initializers matter. A synthesized memberwise initializer is not automatically public; it can be internal, fileprivate, or private. [Swift initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Memberwise-Initializers-for-Structure-Types), [access control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/#Default-Memberwise-Initializers-for-Structure-Types), [SE-0242](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0242-default-values-memberwise.md)

The silent same-type case must be checked by meaning:

```swift
// Before: struct Pair { var first: Int; var second: Int }
let make: (Int, Int) -> Pair = Pair.init
let value = make(10, 20)
// Reordering storage to second, first can keep this compiling,
// while value.first becomes 20 and value.second becomes 10.
```

Preserve argument-to-field mapping, not merely function types. An explicit initializer with the existing signature can decouple source API from storage order; check its actual assignments and effects.

Reordering labeled call arguments can reorder side effects. `T(a: makeA(), b: makeB())` changed to `T(b: makeB(), a: makeA())` changes ordinary explicit r-value evaluation order. Preserve the required sequence with evaluated temporaries or an appropriate explicit initializer. Default arguments and formal-access arguments have additional rules; inspect the concrete call. [SE-0411 argument evaluation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0411-isolated-default-values.md#argument-evaluation)

Stored-property default expressions can also have observable ordering effects, including with an explicit initializer. Check registration, counters, time/random reads, wrapper construction, and init accessors. An explicit initializer is not proof that defaults are bypassed. Distinguish current observed behavior from a universal language ordering guarantee. Wrappers affect synthesis through backing storage, and init accessors add initialization dependencies. [Property-initialization discussion](https://forums.swift.org/t/can-i-rely-on-the-order-of-property-initialization/50449/8), [SE-0258](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0258-property-wrappers.md#codable-hashable-and-equatable-synthesis), [SE-0400](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0400-init-accessors.md)

## Serialization, reflection, equality, and hashing

| Consumer | What to preserve or verify |
| --- | --- |
| Ordinary keyed `Codable` | Key names, included values, and mapping. Storage reordering usually preserves keyed JSON/plist meaning when these are unchanged. `Codable` alone is not a blocker. |
| Custom/positional codec or exact bytes | Check traversal, callbacks, first decoding error, streaming order, signed bytes, and snapshots as required by the real contract. Keyed semantics do not establish byte-for-byte stability. |
| `Mirror`, `dump`, descriptions, schema generators | Check positional/indexed consumers and snapshots. Default traversal can change; custom reflection can expose another order and is not a physical field inventory. |
| Synthesized `Equatable` | Pure component equality preserves the Boolean result, but component call order, short-circuit cost, and custom side effects can change. |
| Synthesized `Hashable` | Component combination order can change. Preserve equality/hash consistency; exact hashes and Set/Dictionary iteration order are not stable serialization contracts. |
| Custom ordering or macros | Read the implementation. Swift does not provide built-in synthesized `Comparable` for structs. |

Keyed synthesis is described in [SE-0166](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md). Current compiler synthesis traverses `CodingKeys`; implicit keys follow stored declarations. Explicit `CodingKeys` can preserve traversal when storage moves, but exact encoder output and callback/error behavior still need the relevant check. Sorting output JSON keys does not preserve the order in which user callbacks ran. [Codable synthesis implementation](https://github.com/swiftlang/swift/blob/main/lib/Sema/DerivedConformance/DerivedConformanceCodable.cpp)

Reflection order is an observable dependency to inspect, not a general memory-layout guarantee. [Mirror](https://developer.apple.com/documentation/swift/mirror), [How Mirror Works](https://www.swift.org/blog/how-mirror-works/)

For synthesis contracts, see [SE-0185](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md), [SE-0206](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0206-hashable-enhancements.md), and the enum-only scope of [SE-0266](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0266-synthesized-comparable-for-enumerations.md). Do not repair a pre-existing persisted-hash assumption by promising a particular new hash.

## Generated and expanded sources

For generated declarations, locate the generator or schema and its regeneration process. Make an authorized change at the maintained source and regenerate; editing only generated output is not a durable optimization. Inspect macro expansion, wrappers, active `#if` branches, and generated initializer/schema order before deciding what storage exists or which consumers change.

If the generator is external, the schema is fixed, or relevant clients are unavailable, record the concrete constraint and keep the candidate as a finding. Do not broaden a local reorder into a schema migration, dependency rewrite, or changed library-distribution settings.

## Decision record

Report the outcome as an admissible candidate, a rejected local reorder with the specific contract, or an unresolved candidate with the missing evidence. After an authorized edit, verify meaningful field mappings/effects and affected consumers as well as compilation and the chosen layout metric. A successful build alone cannot detect the same-type `Type.init` swap above.
