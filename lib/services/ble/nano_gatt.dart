import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// GATT UUIDs for NIRScan Nano communication.
///
/// Based on Texas Instruments DLP NIRscan Nano EVM SDK.
/// Reference: https://github.com/kstechnologies/NIRScanNano_Android
class NanoGatt {
  NanoGatt._();

  /// Client Characteristic Configuration Descriptor UUID
  static final Guid cccdUuid = Guid('00002902-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Device Information Service (DIS)
  // Standard Bluetooth SIG Service
  // ============================================

  /// Manufacturer Name characteristic
  static final Guid disManufName = Guid('00002a29-0000-1000-8000-00805f9b34fb');

  /// Model Number characteristic
  static final Guid disModelNumber =
      Guid('00002a24-0000-1000-8000-00805f9b34fb');

  /// Serial Number characteristic
  static final Guid disSerialNumber =
      Guid('00002a25-0000-1000-8000-00805f9b34fb');

  /// Hardware Revision characteristic
  static final Guid disHwRev = Guid('00002a27-0000-1000-8000-00805f9b34fb');

  /// Tiva Firmware Revision characteristic
  static final Guid disTivaFwRev = Guid('00002a26-0000-1000-8000-00805f9b34fb');

  /// Spectrum C Library Revision characteristic
  static final Guid disSpeccRev = Guid('00002a28-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Battery Service (BAS)
  // Standard Bluetooth SIG Service
  // ============================================

  /// Battery Level characteristic (0-100)
  static final Guid basBattLvl = Guid('00002a19-0000-1000-8000-00805f9b34fb');

  // ============================================
  // General Information Service (GGIS)
  // Custom TI Service
  // ============================================

  /// Temperature Measurement characteristic
  static final Guid ggisTempMeasurement =
      Guid('00002a1c-0000-1000-8000-00805f9b34fb');

  /// Humidity Measurement characteristic
  static final Guid ggisHumidMeasurement =
      Guid('00002a6f-0000-1000-8000-00805f9b34fb');

  /// Device Status characteristic
  static final Guid ggisDevStatus =
      Guid('00002a1d-0000-1000-8000-00805f9b34fb');

  /// Error Status characteristic
  static final Guid ggisErrStatus =
      Guid('00002a1e-0000-1000-8000-00805f9b34fb');

  /// Temperature Threshold characteristic
  static final Guid ggisTempThresh =
      Guid('00002a1f-0000-1000-8000-00805f9b34fb');

  /// Humidity Threshold characteristic
  static final Guid ggisHumidThresh =
      Guid('00002a20-0000-1000-8000-00805f9b34fb');

  /// Hours of Use characteristic
  static final Guid ggisHoursOfUse =
      Guid('00002a21-0000-1000-8000-00805f9b34fb');

  /// Number of Battery Recharge cycles characteristic
  static final Guid ggisNumBattRecharge =
      Guid('00002a22-0000-1000-8000-00805f9b34fb');

  /// Lamp Hours characteristic
  static final Guid ggisLampHours =
      Guid('00002a23-0000-1000-8000-00805f9b34fb');

  /// Error Log characteristic
  static final Guid ggisErrLog = Guid('00002a2a-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Date/Time Service (GDTS)
  // ============================================

  /// Time characteristic
  static final Guid gdtsTime = Guid('00002a2b-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Calibration Information Service (GCIS)
  // ============================================

  /// Request Spectrum Calibration Coefficients
  static final Guid gcisReqSpecCalCoeff =
      Guid('00002a30-0000-1000-8000-00805f9b34fb');

  /// Return Spectrum Calibration Coefficients
  static final Guid gcisRetSpecCalCoeff =
      Guid('00002a31-0000-1000-8000-00805f9b34fb');

  /// Request Reference Calibration Coefficients
  static final Guid gcisReqRefCalCoeff =
      Guid('00002a32-0000-1000-8000-00805f9b34fb');

  /// Return Reference Calibration Coefficients
  static final Guid gcisRetRefCalCoeff =
      Guid('00002a33-0000-1000-8000-00805f9b34fb');

  /// Request Reference Calibration Matrix
  static final Guid gcisReqRefCalMatrix =
      Guid('00002a34-0000-1000-8000-00805f9b34fb');

  /// Return Reference Calibration Matrix
  static final Guid gcisRetRefCalMatrix =
      Guid('00002a35-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Scan Configuration Service (GSCIS)
  // ============================================

  /// Number of Stored Configurations
  static final Guid gscisNumStoredConf =
      Guid('00002a40-0000-1000-8000-00805f9b34fb');

  /// Request Stored Configuration List
  static final Guid gscisReqStoredConfList =
      Guid('00002a41-0000-1000-8000-00805f9b34fb');

  /// Return Stored Configuration List
  static final Guid gscisRetStoredConfList =
      Guid('00002a42-0000-1000-8000-00805f9b34fb');

  /// Request Scan Configuration Data
  static final Guid gscisReqScanConfData =
      Guid('00002a43-0000-1000-8000-00805f9b34fb');

  /// Return Scan Configuration Data
  static final Guid gscisRetScanConfData =
      Guid('00002a44-0000-1000-8000-00805f9b34fb');

  /// Active Scan Configuration
  static final Guid gscisActiveScanConf =
      Guid('00002a45-0000-1000-8000-00805f9b34fb');

  // ============================================
  // Scan Data Information Service (GSDIS)
  // ============================================

  /// Number of SD Stored Scans
  static final Guid gsdisNumSdStoredScans =
      Guid('00002a50-0000-1000-8000-00805f9b34fb');

  /// SD Stored Scan Indices List (request)
  static final Guid gsdisSdStoredScanIndList =
      Guid('00002a51-0000-1000-8000-00805f9b34fb');

  /// SD Stored Scan Indices List Data (response)
  static final Guid gsdisSdStoredScanIndListData =
      Guid('00002a52-0000-1000-8000-00805f9b34fb');

  /// Set Scan Name Stub
  static final Guid gsdisSetScanNameStub =
      Guid('00002a53-0000-1000-8000-00805f9b34fb');

  /// Start Scan
  static final Guid gsdisStartScan =
      Guid('00002a54-0000-1000-8000-00805f9b34fb');

  /// Clear Scan
  static final Guid gsdisClearScan =
      Guid('00002a55-0000-1000-8000-00805f9b34fb');

  /// Request Scan Name
  static final Guid gsdisReqScanName =
      Guid('00002a56-0000-1000-8000-00805f9b34fb');

  /// Return Scan Name
  static final Guid gsdisRetScanName =
      Guid('00002a57-0000-1000-8000-00805f9b34fb');

  /// Request Scan Type
  static final Guid gsdisReqScanType =
      Guid('00002a58-0000-1000-8000-00805f9b34fb');

  /// Return Scan Type
  static final Guid gsdisRetScanType =
      Guid('00002a59-0000-1000-8000-00805f9b34fb');

  /// Request Scan Date
  static final Guid gsdisReqScanDate =
      Guid('00002a5a-0000-1000-8000-00805f9b34fb');

  /// Return Scan Date
  static final Guid gsdisRetScanDate =
      Guid('00002a5b-0000-1000-8000-00805f9b34fb');

  /// Request Packet Format Version
  static final Guid gsdisReqPktFmtVer =
      Guid('00002a5c-0000-1000-8000-00805f9b34fb');

  /// Return Packet Format Version
  static final Guid gsdisRetPktFmtVer =
      Guid('00002a5d-0000-1000-8000-00805f9b34fb');

  /// Request Serialized Scan Data Structure
  static final Guid gsdisReqSerScanDataStruct =
      Guid('00002a5e-0000-1000-8000-00805f9b34fb');

  /// Return Serialized Scan Data Structure
  static final Guid gsdisRetSerScanDataStruct =
      Guid('00002a5f-0000-1000-8000-00805f9b34fb');
}

/// Device name patterns for NIRScan Nano discovery
class NanoDevicePatterns {
  NanoDevicePatterns._();

  static const String namePrefix = 'NIRScan';
  static final RegExp namePattern = RegExp(r'NIRScan.*Nano.*');

  static bool isNanoDevice(String? name) {
    if (name == null) return false;
    return name.startsWith(namePrefix) || namePattern.hasMatch(name);
  }
}
