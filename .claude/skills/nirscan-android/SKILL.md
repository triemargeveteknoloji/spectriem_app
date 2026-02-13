---
name: nirscan-android
description: TI DLP NIRscan Nano Android SDK reference implementation. Use when debugging BLE communication, understanding GATT protocol, implementing scan operations, or troubleshooting sensor issues. Source: kstechnologies/NIRScanNano_Android GitHub repo.
---

# NIRScan Nano Android SDK Reference

> ⚠️ **LEGACY REFERENCE - USE WITH CAUTION**
>
> This skill is based on the kstechnologies GitHub repo which may use **older firmware UUIDs**.
> Some UUID values (especially GSCIS service: `0x47`, `0x4E`, `0x4F`) do NOT match our tested device.
>
> **Verified UUIDs:** See `nirscan-apk-analysis.md` and `nano_gatt.dart` - these are tested with real hardware.
>
> | Service | This Skill | Verified (our code) |
> |---------|------------|---------------------|
> | ACTIVE_SCAN_CONF | `43484147` | `43484118` ✅ |
> | REQ_SCAN_CONF | `4348414E` | `43484116` ✅ |
> | RET_SCAN_CONF | `4348414F` | `43484117` ✅ |
>
> **When in doubt, trust `nano_gatt.dart` over this skill.**

Reference implementation for TI DLP NIRscan Nano EVM BLE communication from kstechnologies/NIRScanNano_Android.

## Quick Reference

### Key Files in Reference Repo

| File | Purpose |
|------|---------|
| `KSTNanoSDK.java` | GATT UUIDs, data structures, constants |
| `NanoBLEService.java` | BLE service, characteristic handling |
| `NewScanActivity.java` | Scan workflow, results handling |
| `ScanConfActivity.java` | Config management UI |

### Architecture Pattern

```
Activity ──► LocalBroadcast ──► NanoBLEService ──► GATT
    │                               │
    │◄── LocalBroadcast ◄───────────┤
```

All BLE operations use Android's LocalBroadcastManager for decoupled communication.

## Reference Files

- **[references/gatt-uuids.md](references/gatt-uuids.md)** - Complete GATT UUID list and characteristic purposes
- **[references/ble-service.md](references/ble-service.md)** - BLE service patterns, broadcast actions, command flow
- **[references/scan-config.md](references/scan-config.md)** - Scan configuration structure and management

## Common Operations

### Start Scan

```java
// NanoBLEService.java pattern
byte[] scanData = {0x00};  // Start command
characteristic.setValue(scanData);
gatt.writeCharacteristic(characteristic);
// Listen for ACTION_SCAN_STARTED broadcast
```

### Read Active Config

```java
// Characteristic: GSCIS_ACTIVE_SCAN_CONF (0x43484147)
// Returns 2-byte little-endian index
byte[] value = characteristic.getValue();
int activeIndex = (value[1] << 8) | (value[0] & 0xFF);
```

### Set Active Config

```java
// Write 2-byte little-endian index
byte[] configIndex = {(byte)(index & 0xFF), (byte)((index >> 8) & 0xFF)};
characteristic.setValue(configIndex);
gatt.writeCharacteristic(characteristic);
```

### Multi-Packet Reception

```java
// Header packet: [0x00, sizeLow, sizeHigh]
// Data packets: [packetIndex, ...data]
if (data[0] == 0x00) {
    totalSize = (data[2] << 8) | (data[1] & 0xFF);
    buffer = new byte[totalSize];
} else {
    int offset = (data[0] - 1) * (packetSize - 1);
    System.arraycopy(data, 1, buffer, offset, data.length - 1);
}
```

## Scan Result Codes

| Code | Meaning |
|------|---------|
| 0xFF | Success (scan index in data[1:5]) |
| 0x00 | Scan in progress |
| 0x01 | **Lamp power failure** |
| 0x02 | ADC overflow/saturation |
| 0x03 | Pattern stream error |
| 0x04 | DLP subsystem failure |

## Error Status Flags (GGIS_ERROR_STATUS)

| Bit | Flag | Meaning |
|-----|------|---------|
| 0x001 | SCAN_ERROR | Scan error (see scan result codes) |
| 0x002 | ADC_ERROR | ADC communication error |
| 0x004 | SD_CARD_ERROR | SD card read/write error |
| 0x008 | EEPROM_ERROR | EEPROM communication error |
| 0x010 | BT_ERROR | Bluetooth stack error |
| 0x020 | SPEC_LIB_ERROR | Spectrum library error |
| 0x040 | HW_ERROR | General hardware error |
| 0x080 | TMP006_ERROR | Temperature sensor error |
| 0x100 | HDC1000_ERROR | Humidity sensor error |
| 0x200 | BATTERY_ERROR | Battery discharged |
| 0x400 | MEMORY_ERROR | Memory allocation error |
| 0x800 | UART_ERROR | UART communication error |

## Calibration Timing

> **ONEMLI (TI User's Guide s.53-57):** Kalibrasyon verileri **her cihaz
> baglantiginda** VE **her yeni tarama oncesinde** cekilmelidir.
> Ayni kural scan konfigurasyonlari icin de gecerlidir.
>
> Kalibrasyon UC adimdan olusur:
> 1. Spectrum Calibration Coefficients (wavelength-to-pixel polynomial)
> 2. Reference Calibration Coefficients
> 3. Reference Calibration Matrix
>
> Detayli karsilastirma: `.claude/research/ble-workflow-comparison.md`
