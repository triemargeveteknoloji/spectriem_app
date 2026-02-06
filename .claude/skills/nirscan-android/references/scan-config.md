# Scan Configuration Management

> ⚠️ **LEGACY - UUID VALUES MAY BE OUTDATED**
>
> The UUID examples in this file (e.g., `0x43484147`) may not match current firmware.
> **For verified UUIDs, see:** `lib/services/ble/nano_gatt.dart`
> **Data format info (config structure) is still valid.**

Scan configuration structures and management from KSTNanoSDK.java and ScanConfActivity.java.

## ScanConfiguration Structure

```java
public class ScanConfiguration {
    byte[] configName;           // 40 bytes, null-padded string
    byte scanType;               // 0=Column, 1=Hadamard
    int scanConfigIndex;         // Config index (NOT sequential!)
    int numSections;             // Number of wavelength sections (1-5)
    
    // Per-section arrays (size = numSections)
    float[] wavelengthStart;     // Start wavelength in nm
    float[] wavelengthEnd;       // End wavelength in nm
    int[] numPatterns;           // Number of patterns per section
    int[] width;                 // Digital resolution (2-60)
    int[] numRepeat;             // Number of averages (1-50)
    int[] exposure;              // Exposure time
}
```

## Config Index System

**CRITICAL:** Config indices are NOT sequential (0, 1, 2...). They are assigned by the device and stored in the config data itself.

### Fetching Valid Config Indices

1. Read `NUM_STORED_CONF` to get count
2. Request config list via `REQ_STORED_CONF_LIST`
3. Receive multi-packet response on `RET_STORED_CONF_LIST`
4. Parse config indices from packets

### Config List Packet Format

```java
// Each packet in config list:
// byte[0] = packet index (0 for header, 1+ for data)
// byte[1-2] = config index (little-endian)
// byte[3+] = config name (null-padded)

// Header packet (packet index 0):
[0x00, sizeLow, sizeHigh]

// Data packets:
[packetIndex, indexLow, indexHigh, ...configName...]
```

### Parsing Config Indices

```java
// From KSTNanoSDK.java style
List<Integer> configIndices = new ArrayList<>();

for (byte[] packet : configListPackets) {
    if (packet[0] == 0x00) continue; // Skip header
    
    int configIndex = (packet[2] << 8) | (packet[1] & 0xFF);
    configIndices.add(configIndex);
}
```

## Active Config Operations

### Reading Active Config

```java
// Characteristic: GSCIS_ACTIVE_SCAN_CONF (0x43484147)
byte[] value = activeConfigChar.getValue();
int activeIndex = (value[1] << 8) | (value[0] & 0xFF);
```

### Setting Active Config

```java
// Write 2-byte little-endian index
int targetIndex = configIndices.get(0); // First valid config
byte[] data = new byte[2];
data[0] = (byte)(targetIndex & 0xFF);
data[1] = (byte)((targetIndex >> 8) & 0xFF);

activeConfigChar.setValue(data);
gatt.writeCharacteristic(activeConfigChar);
```

### Verifying Config Change

```java
// After write, read back to verify
byte[] verify = activeConfigChar.getValue();
int newIndex = (verify[1] << 8) | (verify[0] & 0xFF);
if (newIndex != targetIndex) {
    // Config change failed!
}
```

## Config Data Request

### Requesting Specific Config

```java
// Write config index to REQ_SCAN_CONF (0x4348414E)
byte[] request = new byte[2];
request[0] = (byte)(configIndex & 0xFF);
request[1] = (byte)((configIndex >> 8) & 0xFF);

reqScanConfChar.setValue(request);
gatt.writeCharacteristic(reqScanConfChar);

// Response arrives on RET_SCAN_CONF (0x4348414F)
```

### Config Data Packet Format

> ⚠️ **GÜNCELLEME (2026-02-04):** Aşağıdaki format eski/yanlış. Gerçek format TPL serialization kullanıyor.
> **Doğru format için bkz:** `dlpnirnanoevm-sensor/refs/data-formats.md` → "Scan Config TPL Format"

Config verisi **TPL (Troy's Packing Library)** formatında serialize edilir:

```
TPL HEADER
0-3     "tpl\0"              Magic header
4-7     size (LE uint32)     Block size
8-19    "S(cvc#c#vc)\0"      Format string

LENGTH PREFIXES
20-23   serial_len (8)       Serial number length
24-27   name_len (40)        Config name length

STRUCT DATA
28      scan_type            0=Column, 1=Hadamard
29-30   config_index         LE uint16
31-38   serial_number        8 bytes
39-78   config_name          40 bytes (null-padded)
79+     section_data         Variable

NOT: Response TÜM config'leri içerebilir (concatenated TPL blocks).
```

~~Eski (yanlış) format:~~
```
Offset  Size  Field
0       40    configName (null-padded string)
40      1     scanType
41      2     numSections (little-endian)
43      4     wavelengthStart[0] (float, little-endian)
...
```

## Scan Types

| Value | Type | Description |
|-------|------|-------------|
| 0 | Column | Standard column scan |
| 1 | Hadamard | Hadamard transform scan |

## Configuration Limits

| Parameter | Min | Max | Default |
|-----------|-----|-----|---------|
| numSections | 1 | 5 | 1 |
| wavelengthStart | 900 | 1700 | 900 |
| wavelengthEnd | 900 | 1700 | 1700 |
| numPatterns | 2 | 624 | 228 |
| width | 2 | 60 | 6 |
| numRepeat | 1 | 50 | 6 |

## Common Issues

### Config Index Mismatch

**Symptom:** Active config shows index 6 but device has configs at indices 4, 6.

**Cause:** Legacy configs may have non-sequential indices from previous firmware/usage.

**Solution:** Always fetch config list and use actual indices, never assume 0,1,2...

### Config Write Fails Silently

**Symptom:** Write succeeds (GATT_SUCCESS) but config doesn't change.

**Possible Causes:**
1. Device is busy (scan in progress)
2. Config index invalid (not in stored list)
3. Write to wrong characteristic

**Debug Steps:**
1. Verify characteristic has write property
2. Read back immediately after write
3. Ensure no scan is in progress
4. Try with known-good config index from list

### Lamp Failure After Config Change

**Symptom:** Scan returns 0x01 (lamp failure) after switching configs.

**Possible Causes:**
1. Config parameters out of range for current calibration
2. Hardware issue unrelated to config
3. Config incompatible with current lamp state

**Debug Steps:**
1. Try default factory config first
2. Check device error status (0x4348415A)
3. Power cycle device
4. Verify config parameters are within limits
