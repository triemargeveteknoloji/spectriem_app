# NIRScan Nano GATT UUIDs

> ⚠️ **LEGACY - POTENTIALLY OUTDATED UUIDs**
>
> These UUIDs are from an older GitHub repo and may not match current firmware.
> **For verified UUIDs, see:** `lib/services/ble/nano_gatt.dart`

Complete GATT UUID reference from KSTNanoSDK.java.

## UUID Pattern

All custom TI characteristics follow: `434841XX-444C-5020-4E49-52204E616E6F`
Where XX is the characteristic identifier.

## Services

| Service | UUID | Description |
|---------|------|-------------|
| GSDIS | `43484152-444C-5020-4E49-52204E616E6F` | Scan Data Information Service |
| GCIS | `43484151-444C-5020-4E49-52204E616E6F` | Calibration Information Service |
| GSCIS | `43484153-444C-5020-4E49-52204E616E6F` | Scan Configuration Information Service |
| GGIS | `43484154-444C-5020-4E49-52204E616E6F` | General Information Service |
| DIS | `0000180a-0000-1000-8000-00805f9b34fb` | Device Information Service (standard) |
| BAS | `0000180f-0000-1000-8000-00805f9b34fb` | Battery Service (standard) |

## GSDIS - Scan Data Characteristics

| Name | UUID Suffix | Full UUID | Properties | Description |
|------|-------------|-----------|------------|-------------|
| START_SCAN | 0x57 | `43484157-...` | Write, Notify | Start scan (write=command, notify=status) |
| CLEAR_SCAN | 0x40 | `43484140-...` | Write | Clear stored scan |
| SCAN_NAME | 0x41 | `43484141-...` | Notify | Return scan name |
| SCAN_TYPE | 0x42 | `43484142-...` | Notify | Return scan type |
| SCAN_DATE | 0x43 | `43484143-...` | Notify | Return scan timestamp |
| SCAN_BLOB_VER | 0x44 | `43484144-...` | Notify | Return blob version |
| SCAN_DATA | 0x45 | `43484145-...` | Notify | Return scan data (multi-packet) |
| REQ_SER_SCAN_DATA | 0x4B | `4348414B-...` | Write | Request serialized scan data |
| RET_SER_SCAN_DATA | 0x4C | `4348414C-...` | Notify | Return serialized scan data |
| NUM_STORED_SCANS | 0x30 | `43484130-...` | Read | Number of stored scans |
| REQ_STORED_SCAN_LIST | 0x31 | `43484131-...` | Write | Request stored scan indices |
| RET_STORED_SCAN_LIST | 0x32 | `43484132-...` | Notify | Return stored scan indices |

## GCIS - Calibration Characteristics

| Name | UUID Suffix | Full UUID | Properties | Description |
|------|-------------|-----------|------------|-------------|
| REQ_REF_CAL_COEFF | 0x50 | `43484150-...` | Write | Request calibration coefficients |
| RET_REF_CAL_COEFF | 0x51 | `43484151-...` | Notify | Return coefficients (multi-packet) |
| REQ_REF_CAL_MATRIX | 0x52 | `43484152-...` | Write | Request calibration matrix |
| RET_REF_CAL_MATRIX | 0x53 | `43484153-...` | Notify | Return matrix (multi-packet) |
| SPEC_CAL_COEFF | 0x01 | `43484101-...` | Read | Spectrum calibration coefficients |

## GSCIS - Scan Configuration Characteristics

| Name | UUID Suffix | Full UUID | Properties | Description |
|------|-------------|-----------|------------|-------------|
| NUM_STORED_CONF | 0x10 | `43484110-...` | Read | Number of stored configs |
| REQ_STORED_CONF_LIST | 0x11 | `43484111-...` | Write | Request config list |
| RET_STORED_CONF_LIST | 0x12 | `43484112-...` | Notify | Return config list (multi-packet) |
| REQ_SCAN_CONF | 0x4E | `4348414E-...` | Write | Request specific config data |
| RET_SCAN_CONF | 0x4F | `4348414F-...` | Notify | Return config data |
| ACTIVE_SCAN_CONF | 0x47 | `43484147-...` | Read, Write | Get/set active config index |

**Important:** Config indices are NOT sequential (0,1,2...). They are stored in the config list packets and must be retrieved via REQ_STORED_CONF_LIST.

## GGIS - General Information Characteristics

| Name | UUID Suffix | Full UUID | Properties | Description |
|------|-------------|-----------|------------|-------------|
| TEMP_THRESH | 0x20 | `43484120-...` | Read, Write | Temperature threshold |
| HUMID_THRESH | 0x21 | `43484121-...` | Read, Write | Humidity threshold |
| TEMP_MEAS | 0x59 | `43484159-...` | Read | Current temperature |
| HUMID_MEAS | 0x60 | `43484160-...` | Read | Current humidity |
| DEVICE_STATUS | 0x61 | `43484161-...` | Read | Device status byte |
| ERROR_STATUS | 0x5A | `4348415A-...` | Read | Error status flags |
| HOURSOFUSE | 0x5B | `4348415B-...` | Read | Hours of use |
| BATTERY | 0x5C | `4348415C-...` | Read | Battery level |
| LAMPUSAGE | 0x5D | `4348415D-...` | Read | Lamp usage hours |
| TOTALLAMPTIMER | 0x5E | `4348415E-...` | Read | Total lamp timer |
| SET_TIME | 0x55 | `43484155-...` | Write | Set device time |
| REQ_DEVICE_INFO | 0x56 | `43484156-...` | Write | Request device info |
| RET_DEVICE_INFO | 0x58 | `43484158-...` | Notify | Return device info |

## DIS - Device Information (Standard BLE)

| Name | UUID | Description |
|------|------|-------------|
| MANUF_NAME | `00002a29-...` | Manufacturer name |
| MODEL_NUM | `00002a24-...` | Model number |
| SERIAL_NUM | `00002a25-...` | Serial number |
| HW_REV | `00002a27-...` | Hardware revision |
| TIVA_REV | `00002a26-...` | Tiva firmware revision |
| SPECTRUM_REV | `00002a28-...` | Spectrum library revision |

## Split Characteristics Pattern

**IMPORTANT:** Some characteristics have separate UUIDs for write vs notify operations:

| Operation | Write UUID | Notify UUID |
|-----------|------------|-------------|
| Start Scan | `43484157` (write command) | `43484157` (same, but notify for status) |
| Stored Conf | `43484111` (request) | `43484112` (response) |
| Ref Cal Coeff | `43484150` (request) | `43484151` (response) |
| Ref Cal Matrix | `43484152` (request) | `43484153` (response) |

When implementing, always check characteristic properties to determine if a single characteristic supports both write and notify, or if separate characteristics are used.
