# NIRScan Nano APK Analysis

**Source:** NIRScan Nano_1.0_APKPure.apk
**Analysis Date:** 2026-01-26
**Package:** com.kstechnologies.NanoScan

## Overview

The official NIRScan Nano Android app uses native Android BLE (BluetoothGatt) with a comprehensive GATT profile. The app is structured with:
- Main app package: `com.kstechnologies.NanoScan`
- SDK library: `com.kstechnologies.nirscannanolibrary.KSTNanoSDK`
- Native library: `libdlpspectrum.so` (spectrum processing)

## GATT Profile - Complete UUID List

All custom UUIDs follow pattern: `434841XX-444C-5020-4E49-52204E616E6F`

### Device Information Service (DIS)
Standard Bluetooth UUIDs:

```
DIS_MANUF_NAME      = 00002A29-0000-1000-8000-00805F9B34FB  (Read: Manufacturer)
DIS_MODEL_NUMBER    = 00002A24-0000-1000-8000-00805F9B34FB  (Read: Model)
DIS_SERIAL_NUMBER   = 00002A25-0000-1000-8000-00805F9B34FB  (Read: Serial)
DIS_HW_REV          = 00002A27-0000-1000-8000-00805F9B34FB  (Read: Hardware Rev)
DIS_TIVA_FW_REV     = 00002A26-0000-1000-8000-00805F9B34FB  (Read: TIVA Firmware)
DIS_SPECC_REV       = 00002A28-0000-1000-8000-00805F9B34FB  (Read: Spectrum Rev)
```

### Battery Service (BAS)
```
BAS_BATT_LVL        = 00002A19-0000-1000-8000-00805F9B34FB  (Read: Battery %)
```

### General Information Service (GGIS)
Device status and environmental sensors:

```
GGIS_TEMP_MEASUREMENT   = 43484101-444C-5020-4E49-52204E616E6F  (Read: Temperature)
GGIS_HUMID_MEASUREMENT  = 43484102-444C-5020-4E49-52204E616E6F  (Read: Humidity)
GGIS_DEV_STATUS         = 43484103-444C-5020-4E49-52204E616E6F  (Read: Device Status)
GGIS_ERR_STATUS         = 43484104-444C-5020-4E49-52204E616E6F  (Read: Error Status)
GGIS_TEMP_THRESH        = 43484105-444C-5020-4E49-52204E616E6F  (Read/Write: Temp Threshold)
GGIS_HUMID_THRESH       = 43484106-444C-5020-4E49-52204E616E6F  (Read/Write: Humid Threshold)
GGIS_HOURS_OF_USE       = 43484107-444C-5020-4E49-52204E616E6F  (Read: Usage Hours)
GGIS_NUM_BATT_RECHARGE  = 43484108-444C-5020-4E49-52204E616E6F  (Read: Battery Cycles)
GGIS_LAMP_HOURS         = 43484109-444C-5020-4E49-52204E616E6F  (Read: Lamp Hours)
GGIS_ERR_LOG            = 4348410A-444C-5020-4E49-52204E616E6F  (Read: Error Log)
```

### Date/Time Service (GDTS)
```
GDTS_TIME               = 4348410C-444C-5020-4E49-52204E616E6F  (Write: Set Time)
```

### Calibration Information Service (GCIS)
Reference and spectrum calibration data:

```
GCIS_REQ_SPEC_CAL_COEFF = 4348410D-444C-5020-4E49-52204E616E6F  (Write: Request)
GCIS_RET_SPEC_CAL_COEFF = 4348412E-444C-5020-4E49-52204E616E6F  (Notify: Response)
GCIS_REQ_REF_CAL_COEFF  = 4348410F-444C-5020-4E49-52204E616E6F  (Write: Request)
GCIS_RET_REF_CAL_COEFF  = 43484110-444C-5020-4E49-52204E616E6F  (Notify: Response)
GCIS_REQ_REF_CAL_MATRIX = 43484111-444C-5020-4E49-52204E616E6F  (Write: Request)
GCIS_RET_REF_CAL_MATRIX = 43484112-444C-5020-4E49-52204E616E6F  (Notify: Response)
```

### Scan Configuration Service (GSCIS)
Manage scan configurations stored on device:

```
GSCIS_NUM_STORED_CONF       = 43484113-444C-5020-4E49-52204E616E6F  (Read: Count)
GSCIS_REQ_STORED_CONF_LIST  = 43484114-444C-5020-4E49-52204E616E6F  (Write: Request List)
GSCIS_RET_STORED_CONF_LIST  = 43484115-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSCIS_REQ_SCAN_CONF_DATA    = 43484116-444C-5020-4E49-52204E616E6F  (Write: Request Config)
GSCIS_RET_SCAN_CONF_DATA    = 43484117-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSCIS_ACTIVE_SCAN_CONF      = 43484118-444C-5020-4E49-52204E616E6F  (Read/Write: Active Config)
```

### Scan Data Service (GSDIS)
Main scanning operations and data retrieval:

```
GSDIS_NUM_SD_STORED_SCANS           = 43484119-444C-5020-4E49-52204E616E6F  (Read: Stored Scan Count)
GSDIS_SD_STORED_SCAN_IND_LIST       = 4348411A-444C-5020-4E49-52204E616E6F  (Write: Request Indices)
GSDIS_SD_STORED_SCAN_IND_LIST_DATA  = 4348411B-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSDIS_SET_SCAN_NAME_STUB            = 4348411C-444C-5020-4E49-52204E616E6F  (Write: Set Name)
GSDIS_START_SCAN                    = 4348411D-444C-5020-4E49-52204E616E6F  (Write/Notify: Start Scan)
GSDIS_CLEAR_SCAN                    = 4348411E-444C-5020-4E49-52204E616E6F  (Write/Notify: Delete Scan)
GSDIS_REQ_SCAN_NAME                 = 4348411F-444C-5020-4E49-52204E616E6F  (Write: Request)
GSDIS_RET_SCAN_NAME                 = 43484120-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSDIS_REQ_SCAN_TYPE                 = 43484121-444C-5020-4E49-52204E616E6F  (Write: Request)
GSDIS_RET_SCAN_TYPE                 = 43484122-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSDIS_REQ_SCAN_DATE                 = 43484123-444C-5020-4E49-52204E616E6F  (Write: Request)
GSDIS_RET_SCAN_DATE                 = 43484124-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSDIS_REQ_PKT_FMT_VER               = 43484125-444C-5020-4E49-52204E616E6F  (Write: Request)
GSDIS_RET_PKT_FMT_VER               = 43484126-444C-5020-4E49-52204E616E6F  (Notify: Response)
GSDIS_REQ_SER_SCAN_DATA_STRUCT      = 43484127-444C-5020-4E49-52204E616E6F  (Write: Request)
GSDIS_RET_SER_SCAN_DATA_STRUCT      = 43484128-444C-5020-4E49-52204E616E6F  (Notify: Response)
```

## Critical Communication Flows

### Flow 1: Device Connection & Setup

```
1. BLE Scan
   - Filter: device.getName() == "NIRScanNano"
   - Store MAC address to SharedPreferences

2. Connect to GATT
   - bluetoothDevice.connectGatt(context, false, gattCallback)

3. Service Discovery
   - gatt.discoverServices()
   - Enumerate all characteristics

4. Enable Notifications (Sequential!)
   Order matters - must be done sequentially:
   a. GCIS_RET_REF_CAL_COEFF
   b. GCIS_RET_REF_CAL_MATRIX
   c. GSDIS_START_SCAN
   d. GSDIS_RET_SCAN_NAME
   e. GSDIS_RET_SCAN_TYPE
   f. GSDIS_RET_SCAN_DATE
   g. GSDIS_RET_PKT_FMT_VER
   h. GSDIS_RET_SER_SCAN_DATA_STRUCT
   i. GSCIS_RET_STORED_CONF_LIST
   j. GSDIS_SD_STORED_SCAN_IND_LIST_DATA
   k. GSDIS_CLEAR_SCAN
   l. GSCIS_RET_SCAN_CONF_DATA

   Each step waits for onDescriptorWrite callback before proceeding.

5. Broadcast ACTION_NOTIFY_DONE when setup complete
```

**Key Pattern:** Use CCCD descriptor `00002902-0000-1000-8000-00805f9b34fb` to enable notifications:
```java
BluetoothGattDescriptor descriptor = characteristic.getDescriptor(CCCD_UUID);
descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
gatt.writeDescriptor(descriptor);
```

### Flow 2: Get Device Info

```
Sequential characteristic reads:
1. Read DIS_MANUF_NAME
2. Read DIS_MODEL_NUMBER
3. Read DIS_SERIAL_NUMBER
4. Read DIS_HW_REV
5. Read DIS_TIVA_FW_REV
6. Read DIS_SPECC_REV

Each read triggers next in onCharacteristicRead callback.
Finally broadcast ACTION_INFO with all data.
```

### Flow 3: Get Device Status

```
Sequential characteristic reads:
1. Read BAS_BATT_LVL
2. Read GGIS_TEMP_MEASUREMENT
3. Read GGIS_HUMID_MEASUREMENT
4. Read GGIS_DEV_STATUS
5. Read GGIS_ERR_STATUS

Broadcast ACTION_STATUS with all data.
```

**Temperature Parsing:**
```java
temp = ((data[1] << 8) | (data[0] & 0xFF)) / 100.0f;
```

**Humidity Parsing:**
```java
humidity = ((data[1] << 8) | (data[0] & 0xFF)) / 100.0f;
```

### Flow 4: Perform New Scan

```
1. Request Reference Calibration (if not cached)
   a. Write dummy byte to GCIS_REQ_REF_CAL_COEFF
   b. Receive multi-packet response via GCIS_RET_REF_CAL_COEFF notification
      - First packet: [0x00, sizeLow, sizeHigh]
      - Next packets: [packetNum, ...data]
      - Accumulate until size reached

   c. Write dummy byte to GCIS_REQ_REF_CAL_MATRIX
   d. Receive multi-packet response via GCIS_RET_REF_CAL_MATRIX notification
      - Same packet format

   e. Cache calibration data to file

2. Set Time (optional)
   - Write 8 bytes to GDTS_TIME: [year, month, day, dow, hour, min, sec, 0x00]

3. Start Scan
   - Write dummy byte to GSDIS_START_SCAN (write characteristic)
   - Notification comes on GSDIS_START_SCAN (notify characteristic)
   - Response: [0xFF, indexByte1, indexByte2, indexByte3, indexByte4]

4. Request Scan Metadata (sequential)
   a. Write scan index (4 bytes) to GSDIS_REQ_SCAN_NAME
   b. Receive scan name via GSDIS_RET_SCAN_NAME notification

   c. Write scan index to GSDIS_REQ_SCAN_TYPE
   d. Receive type via GSDIS_RET_SCAN_TYPE notification

   e. Write scan index to GSDIS_REQ_SCAN_DATE
   f. Receive date via GSDIS_RET_SCAN_DATE notification

   g. Write scan index to GSDIS_REQ_PKT_FMT_VER
   h. Receive version via GSDIS_RET_PKT_FMT_VER notification

5. Request Scan Data
   a. Write scan index to GSDIS_REQ_SER_SCAN_DATA_STRUCT
   b. Receive multi-packet response via GSDIS_RET_SER_SCAN_DATA_STRUCT
      - First packet: [0x00, sizeLow, sizeHigh]
      - Next packets: [packetNum, ...data]
      - Accumulate until size reached

6. Process Scan Data
   Call native function:
   ```java
   ScanResults results = KSTNanoSDK_dlpSpecScanInterpReference(
       scanData,      // Raw scan data bytes
       refCoeff,      // Reference calibration coefficients
       refMatrix      // Reference calibration matrix
   );
   ```

   Returns: wavelengths, intensities, references
```

### Flow 5: Get Stored Scans List

```
1. Read GSDIS_NUM_SD_STORED_SCANS
   - Returns count as 2 bytes: [low, high]

2. Write request to GSDIS_SD_STORED_SCAN_IND_LIST

3. Receive indices via GSDIS_SD_STORED_SCAN_IND_LIST_DATA notification
   - Multi-packet response
   - Each scan index is 4 bytes

4. For each scan index:
   - Write index to GSDIS_REQ_SCAN_NAME
   - Receive name via GSDIS_RET_SCAN_NAME
   - Write index to GSDIS_REQ_SCAN_DATE
   - Receive date via GSDIS_RET_SCAN_DATE
```

### Flow 6: Delete Scan

```
1. Write scan index (4 bytes) to GSDIS_CLEAR_SCAN (write characteristic)
2. Receive confirmation via GSDIS_CLEAR_SCAN (notify characteristic)
```

### Flow 7: Manage Scan Configurations

```
1. Read GSCIS_NUM_STORED_CONF
   - Returns count as 2 bytes: [low, high]

2. Write request to GSCIS_REQ_STORED_CONF_LIST

3. Receive list via GSCIS_RET_STORED_CONF_LIST notification
   - Multi-packet response

4. Get specific configuration:
   - Write config index (2 bytes) to GSCIS_REQ_SCAN_CONF_DATA
   - Receive config via GSCIS_RET_SCAN_CONF_DATA notification
   - Parse with native: KSTNanoSDK_dlpSpecScanReadConfiguration(data)

5. Set active configuration:
   - Write config index (2 bytes) to GSCIS_ACTIVE_SCAN_CONF

6. Get active configuration:
   - Read GSCIS_ACTIVE_SCAN_CONF
   - Returns 2-byte index
```

## Data Format Notes

### Multi-Packet Protocol
Many responses use chunked transfer:
```
Packet 0: [0x00, sizeLow, sizeHigh]  // Size announcement
Packet 1: [0x01, ...data]            // Data chunk 1
Packet 2: [0x02, ...data]            // Data chunk 2
...
```

Client accumulates data until received bytes == announced size.

### Scan Index Format
4 bytes: `[byte0, byte1, byte2, byte3]`

### Configuration Index Format
2 bytes: `[low, high]`

### Date Format
Received as bytes representing: `[YY, MM, DD, HH, MM, SS]` or similar
Displayed as: `YYMMDDHHMMSS`

## BroadcastReceiver Pattern

The app uses LocalBroadcastManager extensively for internal communication:

**From Activity → Service:**
- `KSTNanoSDK.START_SCAN` - Trigger scan
- `KSTNanoSDK.GET_INFO` - Request device info
- `KSTNanoSDK.GET_STATUS` - Request status
- `KSTNanoSDK.SET_TIME` - Set device time
- `KSTNanoSDK.GET_STORED_SCANS` - Request stored scan list
- `KSTNanoSDK.DELETE_SCAN` - Delete a scan
- `KSTNanoSDK.UPDATE_THRESHOLD` - Update temp/humid thresholds
- `KSTNanoSDK.REQUEST_ACTIVE_CONF` - Get active configuration

**From Service → Activity:**
- `KSTNanoSDK.ACTION_GATT_CONNECTED` - Connection established
- `KSTNanoSDK.ACTION_GATT_DISCONNECTED` - Disconnected
- `KSTNanoSDK.ACTION_GATT_SERVICES_DISCOVERED` - Services ready
- `KSTNanoSDK.ACTION_NOTIFY_DONE` - Notification setup complete
- `KSTNanoSDK.ACTION_SCAN_STARTED` - Scan initiated
- `KSTNanoSDK.SCAN_DATA` - Scan data ready
- `KSTNanoSDK.ACTION_INFO` - Device info ready
- `KSTNanoSDK.ACTION_STATUS` - Status data ready
- `KSTNanoSDK.REF_CONF_DATA` - Calibration data ready
- `KSTNanoSDK.STORED_SCAN_DATA` - Stored scan info
- `KSTNanoSDK.SCAN_CONF_DATA` - Configuration data
- `KSTNanoSDK.ACTION_REQ_CAL_COEFF` - Progress update
- `KSTNanoSDK.ACTION_REQ_CAL_MATRIX` - Progress update

## Key Implementation Details

### 1. Sequential Operations
Almost all BLE operations must be sequential - wait for callback before next operation.

### 2. Notification Setup Order
The 12-step notification setup sequence MUST complete before normal operations.

### 3. Calibration Caching
Reference calibration data is large and slow to transfer. Cache it locally after first retrieval.

### 4. Native Processing
Scan interpretation requires native library (`libdlpspectrum.so`). We'll need to either:
- Port the algorithm to Dart
- Use FFI to call native library
- Reverse engineer the algorithm

### 5. Error Handling
Watch for:
- `GGIS_DEV_STATUS` - Device status flags
- `GGIS_ERR_STATUS` - Error codes

### 6. Disconnection Handling
Service includes `refresh()` method that uses reflection to call hidden Android API:
```java
Method refresh = BluetoothGatt.class.getMethod("refresh");
refresh.invoke(mBluetoothGatt);
```

## Architecture Recommendations for Flutter App

### Service Layer
```dart
abstract class NirScanService {
  Stream<NirDevice> scanForDevices();
  Future<void> connect(String deviceId);
  Future<void> disconnect();

  Future<DeviceInfo> getDeviceInfo();
  Future<DeviceStatus> getDeviceStatus();

  Future<void> startScan({String? name});
  Stream<ScanProgress> get scanProgress;
  Future<ScanData> getScanData();

  Future<List<StoredScanInfo>> getStoredScans();
  Future<ScanData> retrieveStoredScan(ScanIndex index);
  Future<void> deleteScan(ScanIndex index);

  Future<List<ScanConfiguration>> getConfigurations();
  Future<void> setActiveConfiguration(int index);
}
```

### State Management
Use Riverpod or similar to manage:
- Connection state
- Scan progress
- Calibration cache
- Device status

### Background Processing
Scan data processing can take time - use Isolate for native processing calls.

## Next Steps for Implementation

1. Create complete GATT UUID constants file
2. Implement sequential notification setup
3. Implement calibration data caching
4. Handle multi-packet protocol
5. Integrate or port native processing
6. Add comprehensive error handling
7. Test with real device

## Files to Reference

**APK Location:** `~/Downloads/NIRScan Nano_1.0_APKPure.apk`

**Key decompiled files:**
- `/tmp/nirscan_apk/decompiled/sources/com/kstechnologies/NanoScan/NanoBLEService.java`
- `/tmp/nirscan_apk/decompiled/sources/com/kstechnologies/nirscannanolibrary/KSTNanoSDK.java`

**Native Library:**
- `libdlpspectrum.so` (multiple architectures in lib/ folder)
