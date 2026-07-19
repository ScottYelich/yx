# YBS Step: GUID Hex Utility (extend GUIDFactory.swift)

**Step ID:** `ybs-step_sw3d0e1f2a3b`
**Language:** Swift
**Prerequisites:** Step sw3c complete (KeyStore.swift exists)

---

## What This Step Builds

**Extend** `Sources/{{CONFIG:swift_module_name}}/Primitives/GUIDFactory.swift` — add `guidToHex()` function.

The file already exists. ADD one static method to the existing GUIDFactory struct/class.

---

## Add to `Sources/{{CONFIG:swift_module_name}}/Primitives/GUIDFactory.swift`

```swift
extension GUIDFactory {
    
    /// Convert GUID bytes to uppercase hex string.
    /// - Parameter guid: 6-byte GUID Data
    /// - Returns: Uppercase hex (e.g., "E32E3CA702DE")
    ///
    /// Traceability:
    /// - protocol/specs/architecture/api-contracts.md (Type Conversion)
    static func guidToHex(_ guid: Data) -> String {
        return guid.map { String(format: "%02X", $0) }.joined()
    }
}
```

---

## Test

Add to `Tests/{{CONFIG:swift_module_name}}Tests/GUIDFactoryTests.swift` (existing file — APPEND):

```swift
// Add in extension of GUIDFactoryTests:
func testGUIDToHex() {
    let guid = Data([0xE3, 0x2E, 0x3C, 0xA7, 0x02, 0xDE])
    XCTAssertEqual(GUIDFactory.guidToHex(guid), "E32E3CA702DE")
    XCTAssertEqual(GUIDFactory.guidToHex(Data(repeating: 0, count: 6)), "000000000000")
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter GUIDFactory
```

Test must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw3d0e1f2a3b-DONE.txt`:

```
STEP: ybs-step_sw3d0e1f2a3b
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Primitives/GUIDFactory.swift (extended), Tests/GUIDFactoryTests.swift (extended)
VERIFICATION: PASSED
NEXT: ybs-step_sw4a0b1c2d3e
```

Update `BUILD_STATUS.md`: add `- [x] sw3d0e1f2a3b`.
