import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// GATT UUIDs for NIRScan Nano communication.
///
/// Based on Texas Instruments DLP NIRscan Nano EVM User's Guide (DLPU030G).
/// Reference: Appendix J (Table J-1 through J-9)
///
/// Custom UUID Base Pattern:
/// ```
/// XXXXXXXX-444C-5020-4E49-52204E616E6F
///          "DL P NI R Nano" (ASCII)
/// ```
class NanoGatt {
  NanoGatt._();

  // ============================================
  // Standard Bluetooth SIG UUIDs
  // ============================================

  /// Client Characteristic Configuration Descriptor UUID
  static final Guid cccdUuid = Guid('00002902-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Service UUIDs
  // ============================================

  /// Device Information Service (Bluetooth SIG Standard)
  static final Guid disService = Guid('0000180a-0000-1000-8000-00805f9b34fb');

  /// Battery Service (Bluetooth SIG Standard)
  static final Guid basService = Guid('0000180f-0000-1000-8000-00805f9b34fb');

  /// GATT General Information Service (Custom TI)
  static final Guid ggisService = Guid('53455201-444c-5020-4e49-52204e616e6f');

  /// GATT Command Service (Custom TI)
  static final Guid gcsService = Guid('53455202-444c-5020-4e49-52204e616e6f');

  /// GATT Date and Time Service (Custom TI)
  static final Guid gdtsService = Guid('53455203-444c-5020-4e49-52204e616e6f');

  /// GATT Calibration Information Service (Custom TI)
  static final Guid gcisService = Guid('53455204-444c-5020-4e49-52204e616e6f');

  /// GATT Scan Configuration Service (Custom TI)
  static final Guid gscisService = Guid('53455205-444c-5020-4e49-52204e616e6f');

  /// GATT Scan Data Information Service (Custom TI)
  static final Guid gsdisService = Guid('53455206-444c-5020-4e49-52204e616e6f');

  // ============================================
  // Device Information Service (DIS) - 0x180A
  // Standard Bluetooth SIG Characteristics
  // ============================================

  /// Manufacturer Name String (Read)
  static final Guid disManufName = Guid('00002a29-0000-1000-8000-00805f9b34fb');

  /// Model Number String (Read)
  static final Guid disModelNumber =
      Guid('00002a24-0000-1000-8000-00805f9b34fb');

  /// Serial Number String (Read)
  static final Guid disSerialNumber =
      Guid('00002a25-0000-1000-8000-00805f9b34fb');

  /// Hardware Revision String (Read)
  static final Guid disHwRev = Guid('00002a27-0000-1000-8000-00805f9b34fb');

  /// Tiva Firmware Revision String (Read)
  static final Guid disTivaFwRev = Guid('00002a26-0000-1000-8000-00805f9b34fb');

  /// Spectrum C Library Revision (Read) - uint16
  static final Guid disSpeccRev = Guid('00002a28-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Battery Service (BAS) - 0x180F
  // Standard Bluetooth SIG Characteristics
  // ============================================

  /// Battery Level (Read) - uint8, 0-100%
  static final Guid basBattLvl = Guid('00002a19-0000-1000-8000-00805f9b34fb');

  // ============================================
  // GATT General Information Service (GGIS)
  // Service UUID: 53455201-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Temperature Measurement (Read/Notify) - int16, value/100 = °C
  static final Guid ggisTempMeasurement =
      Guid('43484101-444c-5020-4e49-52204e616e6f');

  /// Humidity Measurement (Read/Notify) - uint16, value/100 = %
  static final Guid ggisHumidMeasurement =
      Guid('43484102-444c-5020-4e49-52204e616e6f');

  /// Device Status (Read/Notify) - uint16
  static final Guid ggisDevStatus =
      Guid('43484103-444c-5020-4e49-52204e616e6f');

  /// Error Status (Read/Notify) - uint16
  static final Guid ggisErrStatus =
      Guid('43484104-444c-5020-4e49-52204e616e6f');

  /// Temperature Threshold (Write) - int16, value*100
  static final Guid ggisTempThresh =
      Guid('43484105-444c-5020-4e49-52204e616e6f');

  /// Humidity Threshold (Write) - uint16, value*100
  static final Guid ggisHumidThresh =
      Guid('43484106-444c-5020-4e49-52204e616e6f');

  /// Hours of Use (Read) - uint16
  static final Guid ggisHoursOfUse =
      Guid('43484107-444c-5020-4e49-52204e616e6f');

  /// Number of Battery Recharge Cycles (Read) - uint16
  static final Guid ggisNumBattRecharge =
      Guid('43484108-444c-5020-4e49-52204e616e6f');

  /// Total Lamp Hours (Read) - uint16
  static final Guid ggisLampHours =
      Guid('43484109-444c-5020-4e49-52204e616e6f');

  /// Error Log (Read) - string
  static final Guid ggisErrLog = Guid('4348410a-444c-5020-4e49-52204e616e6f');

  // ============================================
  // GATT Command Service (GCS)
  // Service UUID: 53455202-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Command Data Packet (Write/Notify)
  /// Write: Send command, Notify: Receive response
  /// Packet format: [cmd0, cmd1, flag, length, ...params]
  /// Flag: 0x03=Write, 0x05=Read
  static final Guid gcsCommandPacket =
      Guid('4348410b-444c-5020-4e49-52204e616e6f');

  // ============================================
  // GATT Date and Time Service (GDTS)
  // Service UUID: 53455203-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Current Date/Time (Write) - 7 bytes
  /// Format: [year, month, day, dayOfWeek, hour, minute, second]
  /// Year: 0-99 (offset from 2000)
  static final Guid gdtsTime = Guid('4348410c-444c-5020-4e49-52204e616e6f');

  // ============================================
  // GATT Calibration Information Service (GCIS)
  // Service UUID: 53455204-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Request Spectrum Calibration Coefficients (Write) - uint8
  static final Guid gcisReqSpecCalCoeff =
      Guid('4348410d-444c-5020-4e49-52204e616e6f');

  /// Return Spectrum Calibration Coefficients (Notify) - Multi-packet
  /// Contains 6 doubles (48 bytes): p0-p4 polynomial + shift
  static final Guid gcisRetSpecCalCoeff =
      Guid('4348410e-444c-5020-4e49-52204e616e6f');

  /// Request Reference Calibration Coefficients (Write) - uint8
  static final Guid gcisReqRefCalCoeff =
      Guid('4348410f-444c-5020-4e49-52204e616e6f');

  /// Return Reference Calibration Coefficients (Notify) - Multi-packet
  static final Guid gcisRetRefCalCoeff =
      Guid('43484110-444c-5020-4e49-52204e616e6f');

  /// Request Reference Calibration Matrix (Write) - uint8
  static final Guid gcisReqRefCalMatrix =
      Guid('43484111-444c-5020-4e49-52204e616e6f');

  /// Return Reference Calibration Matrix (Notify) - Multi-packet
  static final Guid gcisRetRefCalMatrix =
      Guid('43484112-444c-5020-4e49-52204e616e6f');

  // ============================================
  // GATT Scan Configuration Service (GSCIS)
  // Service UUID: 53455205-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Number of Stored Configurations (Read) - uint16
  static final Guid gscisNumStoredConf =
      Guid('43484113-444c-5020-4e49-52204e616e6f');

  /// Request Stored Configuration List (Write) - triggers notify
  static final Guid gscisReqStoredConfList =
      Guid('43484114-444c-5020-4e49-52204e616e6f');

  /// Return Stored Configuration List (Notify) - Multi-packet
  /// Contains list of 2-byte configuration indices
  static final Guid gscisRetStoredConfList =
      Guid('43484115-444c-5020-4e49-52204e616e6f');

  /// Request Scan Configuration Data (Write) - uint16 index
  static final Guid gscisReqScanConfData =
      Guid('43484116-444c-5020-4e49-52204e616e6f');

  /// Return Scan Configuration Data (Notify) - Multi-packet
  static final Guid gscisRetScanConfData =
      Guid('43484117-444c-5020-4e49-52204e616e6f');

  /// Active Scan Configuration (Read/Write) - uint16 index
  static final Guid gscisActiveScanConf =
      Guid('43484118-444c-5020-4e49-52204e616e6f');

  // ============================================
  // GATT Scan Data Information Service (GSDIS)
  // Service UUID: 53455206-444C-5020-4E49-52204E616E6F
  // ============================================

  /// Number of SD Card Stored Scans (Read) - uint32
  static final Guid gsdisNumSdStoredScans =
      Guid('43484119-444c-5020-4e49-52204e616e6f');

  /// Request SD Stored Scan Indices List (Write) - triggers notify
  static final Guid gsdisSdStoredScanIndList =
      Guid('4348411a-444c-5020-4e49-52204e616e6f');

  /// Return SD Stored Scan Indices List (Notify) - Multi-packet
  /// Contains 5 x 4-byte scan indices per packet
  static final Guid gsdisSdStoredScanIndListData =
      Guid('4348411b-444c-5020-4e49-52204e616e6f');

  /// Set Scan Name Stub (Write) - string, max 15 bytes
  static final Guid gsdisSetScanNameStub =
      Guid('4348411c-444c-5020-4e49-52204e616e6f');

  /// Start Scan (Write/Notify)
  /// Write: 0x00=don't save to SD, 0x01=save to SD
  /// Notify: 0xFF=scan complete, then 4-byte scan index
  static final Guid gsdisStartScan =
      Guid('4348411d-444c-5020-4e49-52204e616e6f');

  /// Clear Scan (Write/Notify) - uint32 scan index to delete
  /// Notify: 0x00=success, non-zero=error
  static final Guid gsdisClearScan =
      Guid('4348411e-444c-5020-4e49-52204e616e6f');

  /// Request Scan Name (Write) - uint32 scan index
  static final Guid gsdisReqScanName =
      Guid('4348411f-444c-5020-4e49-52204e616e6f');

  /// Return Scan Name (Notify) - string, max 20 chars
  static final Guid gsdisRetScanName =
      Guid('43484120-444c-5020-4e49-52204e616e6f');

  /// Request Scan Type (Write) - uint32 scan index
  static final Guid gsdisReqScanType =
      Guid('43484121-444c-5020-4e49-52204e616e6f');

  /// Return Scan Type (Notify) - uint8
  static final Guid gsdisRetScanType =
      Guid('43484122-444c-5020-4e49-52204e616e6f');

  /// Request Scan Date/Time (Write) - uint32 scan index
  static final Guid gsdisReqScanDate =
      Guid('43484123-444c-5020-4e49-52204e616e6f');

  /// Return Scan Date/Time (Notify) - 7 bytes (same as GDTS format)
  static final Guid gsdisRetScanDate =
      Guid('43484124-444c-5020-4e49-52204e616e6f');

  /// Request Packet Format Version (Write) - uint32 scan index
  static final Guid gsdisReqPktFmtVer =
      Guid('43484125-444c-5020-4e49-52204e616e6f');

  /// Return Packet Format Version (Notify) - uint32
  static final Guid gsdisRetPktFmtVer =
      Guid('43484126-444c-5020-4e49-52204e616e6f');

  /// Request Serialized Scan Data Structure (Write) - uint32 scan index
  static final Guid gsdisReqSerScanDataStruct =
      Guid('43484127-444c-5020-4e49-52204e616e6f');

  /// Return Serialized Scan Data Structure (Notify) - Multi-packet
  /// Use dlpspec_scan_interpret() to parse
  static final Guid gsdisRetSerScanDataStruct =
      Guid('43484128-444c-5020-4e49-52204e616e6f');

  // ============================================
  // Notification Subscription Order
  // ============================================

  /// Characteristics that require notification subscription, in order.
  /// Subscribe to these after service discovery, with ~100ms delay between each.
  static final List<Guid> notificationCharacteristics = [
    gcisRetSpecCalCoeff,
    gcisRetRefCalCoeff,
    gcisRetRefCalMatrix,
    gsdisStartScan,
    gsdisRetScanName,
    gsdisRetScanType,
    gsdisRetScanDate,
    gsdisRetPktFmtVer,
    gsdisRetSerScanDataStruct,
    gscisRetStoredConfList,
    gsdisSdStoredScanIndListData,
    gsdisClearScan,
    gscisRetScanConfData,
  ];
}

/// Device name patterns for NIRScan Nano discovery.
class NanoDevicePatterns {
  NanoDevicePatterns._();

  /// Device name prefix to filter during BLE scan
  static const String namePrefix = 'NIRScan';

  /// Full device name pattern
  static final RegExp namePattern = RegExp(r'NIRScan.*Nano.*');

  /// Check if a device name matches NIRScan Nano pattern
  static bool isNanoDevice(String? name) {
    if (name == null) return false;
    return name.startsWith(namePrefix) || namePattern.hasMatch(name);
  }
}

/// Scan index representation (4 bytes).
class ScanIndex {
  final int b0;
  final int b1;
  final int b2;
  final int b3;

  const ScanIndex(this.b0, this.b1, this.b2, this.b3);

  /// Create from 4-byte list
  factory ScanIndex.fromBytes(List<int> bytes) {
    if (bytes.length < 4) {
      throw ArgumentError('ScanIndex requires 4 bytes');
    }
    return ScanIndex(bytes[0], bytes[1], bytes[2], bytes[3]);
  }

  /// Create from 32-bit integer (little-endian)
  factory ScanIndex.fromInt(int value) {
    return ScanIndex(
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    );
  }

  /// Convert to byte list for BLE write
  List<int> toBytes() => [b0, b1, b2, b3];

  /// Convert to 32-bit integer
  int toInt() => b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);

  @override
  String toString() => 'ScanIndex(${toInt()})';

  @override
  bool operator ==(Object other) =>
      other is ScanIndex &&
      b0 == other.b0 &&
      b1 == other.b1 &&
      b2 == other.b2 &&
      b3 == other.b3;

  @override
  int get hashCode => Object.hash(b0, b1, b2, b3);
}
