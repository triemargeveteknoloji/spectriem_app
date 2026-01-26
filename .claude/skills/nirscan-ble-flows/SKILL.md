# NIRScan Nano BLE Communication Flows

**Purpose:** Reference guide for implementing BLE communication with DLP NIRscan Nano sensor based on official Android app analysis.

**Source:** Reverse-engineered from NIRScan Nano v1.0 official Android app (com.kstechnologies.NanoScan)

**Use this skill when:**
- Implementing BLE connection to NIRscan Nano
- Troubleshooting communication issues
- Understanding the scan/calibration flow
- Porting to Flutter/React Native

## Quick Reference

### Device Name
```
BLE Advertisement Name: "NIRScanNano"
```

### CCCD UUID (Enable Notifications)
```
00002902-0000-1000-8000-00805f9b34fb
```

### Custom Service UUID Pattern
```
434841XX-444C-5020-4E49-52204E616E6F
```
Where XX = characteristic-specific byte

## Core Communication Principles

### 1. Sequential Execution
⚠️ **CRITICAL:** All BLE operations must be sequential. Wait for callback before next operation.

### 2. Multi-Packet Protocol
Many characteristics return large data in chunks:
```
Packet 0: [0x00, sizeLow, sizeHigh]  // Size announcement
Packet 1: [0x01, ...data]            // Data chunk
Packet 2: [0x02, ...data]            // Data chunk
...continue until total == size
```

### 3. Request-Response Pattern
Most operations follow:
```
1. Write to REQ_* characteristic
2. Receive notification on RET_* characteristic
```

## Flow 1: Initial Connection & Setup

**Purpose:** Connect to device and enable all notifications

```
┌─────────────────────────────────────────────┐
│ 1. BLE SCAN                                 │
│    - Filter: name == "NIRScanNano"         │
│    - Get MAC address                        │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. CONNECT TO GATT                          │
│    bluetoothDevice.connectGatt()            │
│    Wait: onConnectionStateChange            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. DISCOVER SERVICES                        │
│    gatt.discoverServices()                  │
│    Wait: onServicesDiscovered               │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. ENABLE NOTIFICATIONS (SEQUENTIAL!)       │
│    Must be done in this exact order:        │
│                                             │
│    For each characteristic:                 │
│      descriptor.setValue(ENABLE_NOTIF)      │
│      gatt.writeDescriptor(descriptor)       │
│      Wait: onDescriptorWrite                │
└─────────────────────────────────────────────┘
```

**Notification Enable Order:**
```
1.  GCIS_RET_REF_CAL_COEFF          (43484110)
2.  GCIS_RET_REF_CAL_MATRIX         (43484112)
3.  GSDIS_START_SCAN                (4348411D) - notify
4.  GSDIS_RET_SCAN_NAME             (43484120)
5.  GSDIS_RET_SCAN_TYPE             (43484122)
6.  GSDIS_RET_SCAN_DATE             (43484124)
7.  GSDIS_RET_PKT_FMT_VER           (43484126)
8.  GSDIS_RET_SER_SCAN_DATA_STRUCT  (43484128)
9.  GSCIS_RET_STORED_CONF_LIST      (43484115)
10. GSDIS_SD_STORED_SCAN_IND_LIST_DATA (4348411B)
11. GSDIS_CLEAR_SCAN                (4348411E) - notify
12. GSCIS_RET_SCAN_CONF_DATA        (43484117)
```

**Code Pattern:**
```dart
// Enable notification on characteristic
final descriptor = characteristic.descriptors.firstWhere(
  (d) => d.uuid == Guid('00002902-0000-1000-8000-00805f9b34fb')
);
await descriptor.write([0x01, 0x00]); // ENABLE_NOTIFICATION_VALUE
// Wait for onDescriptorWrite callback before proceeding to next
```

## Flow 2: Get Device Information

**Purpose:** Read device metadata (manufacturer, serial, versions)

```
Sequential reads:
┌─────────────────────────────────────────────┐
│ Read DIS_MANUF_NAME      (00002A29)         │
│   ↓ onCharacteristicRead                    │
│ Read DIS_MODEL_NUMBER    (00002A24)         │
│   ↓ onCharacteristicRead                    │
│ Read DIS_SERIAL_NUMBER   (00002A25)         │
│   ↓ onCharacteristicRead                    │
│ Read DIS_HW_REV          (00002A27)         │
│   ↓ onCharacteristicRead                    │
│ Read DIS_TIVA_FW_REV     (00002A26)         │
│   ↓ onCharacteristicRead                    │
│ Read DIS_SPECC_REV       (00002A28)         │
│   ↓ All data collected                      │
└─────────────────────────────────────────────┘
```

**Result:**
```dart
class DeviceInfo {
  String manufacturer;  // e.g., "Texas Instruments"
  String modelNumber;   // e.g., "DLPNIRNANOEVM"
  String serialNumber;
  String hardwareRev;
  String tivaFirmwareRev;
  String spectrumRev;
}
```

## Flow 3: Get Device Status

**Purpose:** Read battery, temperature, humidity, error status

```
Sequential reads:
┌─────────────────────────────────────────────┐
│ Read BAS_BATT_LVL           (00002A19)      │
│   ↓ Parse: int battery = data[0]           │
│                                             │
│ Read GGIS_TEMP_MEASUREMENT  (43484101)      │
│   ↓ Parse: temp = ((data[1]<<8)|data[0])/100.0 │
│                                             │
│ Read GGIS_HUMID_MEASUREMENT (43484102)      │
│   ↓ Parse: humid = ((data[1]<<8)|data[0])/100.0│
│                                             │
│ Read GGIS_DEV_STATUS        (43484103)      │
│   ↓ Parse: hex string of status flags      │
│                                             │
│ Read GGIS_ERR_STATUS        (43484104)      │
│   ↓ Parse: hex string of error flags       │
└─────────────────────────────────────────────┘
```

**Parsing Functions:**
```dart
// Temperature & Humidity (same format)
double parseTemp(List<int> data) {
  int raw = (data[1] << 8) | (data[0] & 0xFF);
  return raw / 100.0;
}

// Battery
int parseBattery(List<int> data) {
  return data[0]; // Percentage 0-100
}

// Status flags (as hex string for debugging)
String parseStatus(List<int> data) {
  return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
```

**Result:**
```dart
class DeviceStatus {
  int battery;        // 0-100 %
  double temperature; // Celsius
  double humidity;    // Percentage
  String deviceStatus; // Hex flags
  String errorStatus;  // Hex flags
}
```

## Flow 4: Perform New Scan (CRITICAL)

**Purpose:** Trigger scan, retrieve data, process with calibration

### Step 4A: Get Reference Calibration (First Time Only)

```
┌─────────────────────────────────────────────┐
│ 1. REQUEST COEFFICIENTS                     │
│    Write [dummy] to GCIS_REQ_REF_CAL_COEFF  │
│      UUID: 4348410F                         │
│                                             │
│    Receive on GCIS_RET_REF_CAL_COEFF (43484110)│
│      Packet 0: [0x00, sizeLow, sizeHigh]    │
│      Packet N: [N, ...data]                 │
│      Accumulate until complete              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. REQUEST MATRIX                           │
│    Write [dummy] to GCIS_REQ_REF_CAL_MATRIX │
│      UUID: 43484111                         │
│                                             │
│    Receive on GCIS_RET_REF_CAL_MATRIX (43484112)│
│      Same multi-packet format               │
│      Accumulate until complete              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. CACHE TO FILE                            │
│    Store refCoeff + refMatrix locally       │
│    Reuse for subsequent scans               │
└─────────────────────────────────────────────┘
```

**Multi-Packet Accumulator Pattern:**
```dart
class MultiPacketReceiver {
  int? expectedSize;
  List<int> buffer = [];
  
  void onPacket(List<int> data) {
    if (data[0] == 0x00) {
      // Size packet
      expectedSize = (data[2] << 8) | (data[1] & 0xFF);
      buffer.clear();
    } else {
      // Data packet (skip first byte - packet number)
      buffer.addAll(data.skip(1));
    }
  }
  
  bool isComplete() => buffer.length == expectedSize;
  List<int> getData() => buffer;
}
```

### Step 4B: Set Device Time (Optional)

```
┌─────────────────────────────────────────────┐
│ Write 8 bytes to GDTS_TIME (4348410C)       │
│   Format: [year, month, day, dow,           │
│            hour, minute, second, 0x00]      │
│                                             │
│   Example: 2026-01-26 Sunday 14:30:00       │
│   → [26, 1, 26, 0, 14, 30, 0, 0]           │
└─────────────────────────────────────────────┘
```

### Step 4C: Trigger Scan

```
┌─────────────────────────────────────────────┐
│ Write [dummy] to GSDIS_START_SCAN (write)   │
│   UUID: 4348411D                            │
│                                             │
│ Notification on GSDIS_START_SCAN (notify)   │
│   Response: [0xFF, idx0, idx1, idx2, idx3]  │
│   Save scanIndex = [idx0, idx1, idx2, idx3] │
└─────────────────────────────────────────────┘
```

### Step 4D: Retrieve Scan Metadata

```
Sequential requests with scanIndex:

┌─────────────────────────────────────────────┐
│ 1. SCAN NAME                                │
│    Write scanIndex to GSDIS_REQ_SCAN_NAME   │
│      (4348411F)                             │
│    Receive via GSDIS_RET_SCAN_NAME          │
│      (43484120) → String                    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. SCAN TYPE                                │
│    Write scanIndex to GSDIS_REQ_SCAN_TYPE   │
│      (43484121)                             │
│    Receive via GSDIS_RET_SCAN_TYPE          │
│      (43484122) → Hex string                │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. SCAN DATE                                │
│    Write scanIndex to GSDIS_REQ_SCAN_DATE   │
│      (43484123)                             │
│    Receive via GSDIS_RET_SCAN_DATE          │
│      (43484124) → [YY,MM,DD,HH,MM,SS]      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. PACKET FORMAT VERSION                    │
│    Write scanIndex to GSDIS_REQ_PKT_FMT_VER │
│      (43484125)                             │
│    Receive via GSDIS_RET_PKT_FMT_VER        │
│      (43484126) → Hex string                │
└─────────────────────────────────────────────┘
```

### Step 4E: Retrieve Scan Data

```
┌─────────────────────────────────────────────┐
│ Write scanIndex to                          │
│   GSDIS_REQ_SER_SCAN_DATA_STRUCT (43484127) │
│                                             │
│ Receive via GSDIS_RET_SER_SCAN_DATA_STRUCT  │
│   (43484128) - multi-packet                 │
│                                             │
│   Packet 0: [0x00, sizeLow, sizeHigh]       │
│   Packet N: [N, ...data]                    │
│   Accumulate until complete                 │
└─────────────────────────────────────────────┘
```

### Step 4F: Process Scan Data

```
┌─────────────────────────────────────────────┐
│ NATIVE PROCESSING REQUIRED                  │
│                                             │
│ Input:                                      │
│   - scanData: List<int> (raw bytes)         │
│   - refCoeff: List<int> (calibration)       │
│   - refMatrix: List<int> (calibration)      │
│                                             │
│ Native call:                                │
│   dlpSpecScanInterpReference(               │
│     scanData, refCoeff, refMatrix)          │
│                                             │
│ Output:                                     │
│   - wavelengths: List<double>               │
│   - intensities: List<double>               │
│   - references: List<double>                │
└─────────────────────────────────────────────┘
```

**⚠️ Native Processing Note:**
Official app uses `libdlpspectrum.so` native library. Options for Flutter:
1. Use FFI to call native library
2. Port algorithm to Dart (reverse engineer)
3. Request algorithm documentation from TI

## Flow 5: Get Stored Scans List

**Purpose:** List scans stored on device SD card

```
┌─────────────────────────────────────────────┐
│ 1. GET COUNT                                │
│    Read GSDIS_NUM_SD_STORED_SCANS (43484119)│
│    Parse: count = (data[1]<<8)|data[0]      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. REQUEST INDICES LIST                     │
│    Write [dummy] to                         │
│      GSDIS_SD_STORED_SCAN_IND_LIST (4348411A)│
│                                             │
│    Receive via                              │
│      GSDIS_SD_STORED_SCAN_IND_LIST_DATA     │
│      (4348411B) - multi-packet              │
│                                             │
│    Each scan index = 4 bytes                │
│    Parse: indices = chunked(data, 4)        │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. GET METADATA FOR EACH SCAN               │
│    For each scanIndex:                      │
│                                             │
│      Write scanIndex to                     │
│        GSDIS_REQ_SCAN_NAME (4348411F)       │
│      Receive name via                       │
│        GSDIS_RET_SCAN_NAME (43484120)       │
│                                             │
│      Write scanIndex to                     │
│        GSDIS_REQ_SCAN_DATE (43484123)       │
│      Receive date via                       │
│        GSDIS_RET_SCAN_DATE (43484124)       │
└─────────────────────────────────────────────┘
```

**Result:**
```dart
class StoredScanInfo {
  List<int> index;  // 4 bytes
  String name;
  DateTime date;
}

List<StoredScanInfo> getStoredScans() {
  // Returns list of available scans
}
```

## Flow 6: Retrieve Stored Scan

**Purpose:** Download previously stored scan from device

```
Same as Flow 4D + 4E + 4F, but:
- scanIndex comes from stored scans list
- No need to trigger new scan
- Just request metadata and data
```

## Flow 7: Delete Scan

**Purpose:** Remove scan from device storage

```
┌─────────────────────────────────────────────┐
│ Write scanIndex (4 bytes) to                │
│   GSDIS_CLEAR_SCAN (write) (4348411E)       │
│                                             │
│ Receive confirmation via                    │
│   GSDIS_CLEAR_SCAN (notify) (4348411E)      │
└─────────────────────────────────────────────┘
```

## Flow 8: Manage Scan Configurations

**Purpose:** View and select scan configurations stored on device

```
┌─────────────────────────────────────────────┐
│ 1. GET COUNT                                │
│    Read GSCIS_NUM_STORED_CONF (43484113)    │
│    Parse: count = (data[1]<<8)|data[0]      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. REQUEST LIST                             │
│    Write [dummy] to                         │
│      GSCIS_REQ_STORED_CONF_LIST (43484114)  │
│                                             │
│    Receive via                              │
│      GSCIS_RET_STORED_CONF_LIST (43484115)  │
│      - multi-packet                         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. GET SPECIFIC CONFIG                      │
│    Write configIndex (2 bytes) to           │
│      GSCIS_REQ_SCAN_CONF_DATA (43484116)    │
│                                             │
│    Receive via                              │
│      GSCIS_RET_SCAN_CONF_DATA (43484117)    │
│                                             │
│    Parse with native:                       │
│      dlpSpecScanReadConfiguration(data)     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. SET ACTIVE CONFIG                        │
│    Write configIndex (2 bytes) to           │
│      GSCIS_ACTIVE_SCAN_CONF (43484118)      │
│                                             │
│    This config will be used for next scan   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 5. READ ACTIVE CONFIG                       │
│    Read GSCIS_ACTIVE_SCAN_CONF (43484118)   │
│    Returns: 2-byte configIndex              │
└─────────────────────────────────────────────┘
```

## Flow 9: Update Temperature/Humidity Thresholds

**Purpose:** Set device warning thresholds

```
┌─────────────────────────────────────────────┐
│ TEMPERATURE THRESHOLD                       │
│   Convert: float to int16 (×100)            │
│   Example: 45.5°C → 4550                    │
│   Encode: [low_byte, high_byte]             │
│                                             │
│   Write to GGIS_TEMP_THRESH (43484105)      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ HUMIDITY THRESHOLD                          │
│   Convert: float to int16 (×100)            │
│   Example: 65.0% → 6500                     │
│   Encode: [low_byte, high_byte]             │
│                                             │
│   Write to GGIS_HUMID_THRESH (43484106)     │
└─────────────────────────────────────────────┘
```

**Encoding:**
```dart
List<int> encodeThreshold(double value) {
  int raw = (value * 100).toInt();
  return [
    raw & 0xFF,        // Low byte
    (raw >> 8) & 0xFF  // High byte
  ];
}
```

## Complete UUID Reference

See `.claude/research/nirscan-apk-analysis.md` for full UUID listing.

## Common Pitfalls

### ❌ Don't Do This
```dart
// Starting scan without waiting for notifications setup
await connect();
await discoverServices();
await startScan(); // ERROR - notifications not ready!
```

### ✅ Do This
```dart
await connect();
await discoverServices();
await setupNotifications(); // Wait for all 12 steps!
await startScan(); // Now safe
```

---

### ❌ Don't Do This
```dart
// Parallel characteristic reads
Future.wait([
  characteristic1.read(),
  characteristic2.read(),
]);
```

### ✅ Do This
```dart
// Sequential reads
final data1 = await characteristic1.read();
final data2 = await characteristic2.read();
```

---

### ❌ Don't Do This
```dart
// Not handling multi-packet responses
onNotification(List<int> data) {
  processData(data); // Incomplete data!
}
```

### ✅ Do This
```dart
final receiver = MultiPacketReceiver();

onNotification(List<int> data) {
  receiver.onPacket(data);
  if (receiver.isComplete()) {
    processData(receiver.getData());
  }
}
```

## Testing Without Device

Create mock service that:
1. Returns fake device info
2. Simulates scan timing (~2 seconds)
3. Returns synthetic spectral data
4. Reuses cached calibration data

```dart
class MockNirScanService implements NirScanService {
  @override
  Future<void> startScan() async {
    await Future.delayed(Duration(seconds: 2));
    // Return synthetic scan data
  }
}
```

## Implementation Checklist

- [ ] Define all GATT UUIDs as constants
- [ ] Implement sequential notification setup (12 steps)
- [ ] Implement multi-packet receiver
- [ ] Implement calibration caching
- [ ] Handle scan flow (trigger → metadata → data)
- [ ] Integrate native processing (FFI or port)
- [ ] Add error handling for status/error flags
- [ ] Test connection stability (reconnection logic)
- [ ] Implement stored scans management
- [ ] Add configuration selection
- [ ] Test with mock service
- [ ] Test with real device

## Related Documentation

- **Research:** `.claude/research/nirscan-apk-analysis.md` - Full APK analysis
- **Sensor Spec:** `.claude/skills/dlpnirnanoevm-sensor/` - Hardware specifications
- **Project:** `CLAUDE.md` - Project structure

## Version History

- **v1.0** (2026-01-26): Initial extraction from Android app v1.0
