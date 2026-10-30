// Standalone declaration experiment. Run instructions: ../references/measurement.md
// The two declarations contain the same logical fields in different orders.
// Confirm compatibility and measure the real project type before changing it.

struct OriginalEvent {
    var isEnabled: Bool
    var value: Int64
    var isFinal: Bool
}

struct ReorderedEvent {
    var value: Int64
    var isEnabled: Bool
    var isFinal: Bool
}

func report<T>(
    _ type: T.Type,
    name: String,
    offsets: [(String, Int?)] = []
) {
    print("\(name): size=\(MemoryLayout<T>.size) stride=\(MemoryLayout<T>.stride) alignment=\(MemoryLayout<T>.alignment)")
    for (field, offset) in offsets {
        if let offset {
            print("  \(field): offset=\(offset)")
        } else {
            print("  \(field): offset unavailable through MemoryLayout.offset(of:)")
        }
    }
}

print("Standalone native layout experiment; values apply to this compiled target.")
report(Bool.self, name: "Bool field")
report(Int64.self, name: "Int64 field")
report(OriginalEvent.self, name: "OriginalEvent", offsets: [
    ("isEnabled", MemoryLayout<OriginalEvent>.offset(of: \.isEnabled)),
    ("value", MemoryLayout<OriginalEvent>.offset(of: \.value)),
    ("isFinal", MemoryLayout<OriginalEvent>.offset(of: \.isFinal)),
])
report(ReorderedEvent.self, name: "ReorderedEvent", offsets: [
    ("value", MemoryLayout<ReorderedEvent>.offset(of: \.value)),
    ("isEnabled", MemoryLayout<ReorderedEvent>.offset(of: \.isEnabled)),
    ("isFinal", MemoryLayout<ReorderedEvent>.offset(of: \.isFinal)),
])

let strideDifference = MemoryLayout<OriginalEvent>.stride - MemoryLayout<ReorderedEvent>.stride
print("Original minus reordered stride: \(strideDifference) bytes per element slot.")
print("This experiment measures inline layout; allocation, footprint and timing require separate evidence.")
