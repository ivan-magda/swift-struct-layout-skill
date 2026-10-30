# Measure layout in the relevant build

Use this workflow when the task requests layout confirmation or a measured optimization. For a quick review or audit, finish the source review without compiling probes, running tests, or benchmarking unless the user requests measurement. A source-based estimate must state its assumptions.

## Choose a measurement entry point

1. Identify the storage objective: element stride, an enclosing value, allocated bytes, process footprint, or operation time. Select the concrete types and configurations that affect it.
2. Choose the smallest available build/run entry point that sees the **real declaration** with its dependencies and access control. An existing executable or test target may work. A filtered test run can still build dependencies or other targets; inspect the actual build scope.
3. Keep compatible probes in one module/configuration run when visibility permits. Reuse the project's build directory and incremental cache. Avoid a fresh project or full build per type, routine cleans, and deleting shared DerivedData.
4. Record the baseline, compare permitted candidates, then compile selected candidates. Arithmetic over measured field layouts can reduce the number of compiler runs. Preserve the original order as a candidate and bound the search.
5. After an authorized edit, measure the resulting real type and its relevant consumers again. Run the project's required checks and behavior checks for the affected contracts. Compilation alone cannot establish preserved initializer mapping or effects.

A copied declaration is a **standalone experiment**. It does not validate the original type's module context, macros, wrappers, conditional fields, resilience, or consumers. Label it accordingly. Do not change access control just to expose a probe. When the target or SDK is unavailable, retain useful source findings and reproducible probe instructions, and name the measurement that remains unavailable. Cross-compiling is not running on that target.

## Keep provenance with the result

Save the commands and raw output alongside this context:

| Context | Record |
| --- | --- |
| Source | Revision or snapshot, declaration and dependent-type changes, concrete generic substitutions, selected conditional compilation branches |
| Compiler and language | Compiler version/build and selected language mode separately; a Swift 6 compiler can compile in an earlier language mode |
| Target and SDK | Target triple, architecture, platform/deployment target, SDK path/version or explicit compiler-default selection |
| Build | Debug/release, optimization and layout-relevant flags, defines, module boundary, library-evolution setting, and relevant frozen/public status |
| Execution | Whether the probe ran, host/device/simulator, OS/runtime version, and hardware when relevant to the claim |
| Evidence | Exact probe or entry point, field layouts and unavailable offsets, measured wrappers/parents, before/after values and objective |

`swiftc --version` and `swiftc -print-target-info` help capture toolchain context. Read the actual project build settings and invocation too: these commands do not establish its language mode, flags, SDK override, or resilience settings.

Reuse compiled work when compatible, but refresh evidence after a change to the measured declaration, dependent field types, concrete generics, compiler, SDK, target, build configuration, conditional branches, or layout-relevant flags. A cached old stdout does not establish a new parent layout after its child changes. A custom cache or new build system is unnecessary.

## Probe actual storage

Report `MemoryLayout<T>.size`, `.stride`, and `.alignment`. Obtain the sizes and alignments of the **actual stored field types** in that build before modeling alternatives. Do not fill gaps with remembered sizes for String, Array, SIMD, Optional, enums, or resilient and generic values.

Resolve wrappers, macros, `lazy`, generated sources, and conditional compilation to their stored instance fields where possible. Exclude computed and static properties. `Mirror` can have a custom implementation; it cannot prove that a list covers physical storage. State unresolved fields instead of inventing a complete model.

Use `MemoryLayout<T>.offset(of:)` where the API supports a field. Keep `nil` as “unavailable through this API.” Do not force unwrap it, replace it with zero, or infer that the property has no storage. Zero-sized fields can have offsets that differ from a simple sequential model. Avoid raw-memory access merely to fill an offset table.

Measure relevant `T?`, payload enums, concrete generic instantiations, and enclosing structs separately. A child's smaller `size` can improve a parent even when the child's `stride` stays equal. Tail padding, spare bits, and extra inhabitants have different roles; a universal “payload plus one byte” rule is insufficient.

## Match the claim to the evidence

| Claim | Required evidence and limits |
| --- | --- |
| Inline layout | Measured `size / stride / alignment` for the type in the named build |
| Occupied element slots | For a native contiguous buffer, `count × stride`; label this **element-slot arithmetic** |
| Reserved element slots | Actual observed `capacity × stride` for each native buffer; capacity can differ between variants |
| Allocation bytes | Allocator or supported profiling evidence, including headers, rounding and lifetimes as relevant; slot arithmetic omits these |
| Process footprint or peak memory | A representative scenario and a suitable process/device memory measurement; include referenced allocations, CoW and lifetime effects |
| Faster operation or application | A representative workload and timing evidence on suitable hardware |

`MemoryLayout` covers the inline value, including inline references and handles. It does not traverse owned String/Array/class allocations. Do not extract a presumed Array allocator pointer with `unsafeBitCast`; Array representation and malloc ownership do not form a supported measurement API.

For an array-slot objective, a confirmed reduction in the relevant stride plus preserved behavior can complete the task. A CPU benchmark is unnecessary for that claim. A slot reduction alone does not establish lower allocation bytes, footprint, or faster application behavior.

## When the task asks about CPU time

Use release settings and representative inputs, sizes, access patterns and hardware. Define the measured operation and the practical threshold if the user supplies one. Keep preparation outside the timed region, preserve observable results, and verify equivalent logical outputs.

Collect repeated raw individual samples, alternate A/B order, and repeat processes. Retain units, sample order, environment and the inputs needed to reproduce the run. Report the effect with its variability and limitations; aggregated medians cannot recover discarded samples. Overlapping sample ranges alone do not settle whether an effect exists.

Inspect optimized IR or assembly to check that the intended work remains inside the measured repetitions. `@inline(never)`, a sink or a salt alone does not prove that the optimizer retained it. Recheck this after relevant compiler or harness changes. Reject hoisted or eliminated-work runs before comparing timings. Host timings and simulator results do not establish iPhone device performance. Equal time or a slowdown can be a valid investigation result.

## Run the supplied standalone example

[`../examples/layout-probe.swift`](../examples/layout-probe.swift) compares `Bool, Int64, Bool` with `Int64, Bool, Bool`. It reports the two scalar field layouts, each struct's size/stride/alignment, optional key-path offsets, and the measured stride difference. It contains no universal expected-layout assertions and does not benchmark an application.

From the skill package root, run this POSIX-shell sequence with a Swift toolchain that supports language mode 6:

```sh
probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/swift-layout-probe.XXXXXX") || exit 1
trap 'rm -f "$probe_dir/layout-probe"; rmdir "$probe_dir"' EXIT

swiftc --version
swiftc -print-target-info
uname -a
printf '%s\n' 'language mode: 6; optimization: -O; SDK/target: compiler defaults'
swiftc -swift-version 6 -O examples/layout-probe.swift -o "$probe_dir/layout-probe" &&
  "$probe_dir/layout-probe"
```

The temporary executable uses the native compiler defaults; record any SDK or target overrides if you adapt the command. The example declares its own internal types in one module, without library evolution. Cleanup removes only the executable and temporary directory created here. Keep project build caches for repeated real-type probes. Results from this example describe these declarations on the executing target, not the original types in another project or another target.
