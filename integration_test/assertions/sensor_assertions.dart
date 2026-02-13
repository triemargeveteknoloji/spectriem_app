import 'dart:typed_data';

import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/models/scan_data.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

import '../observability/integration_logger.dart';

/// Asserts that [value] is within the range [min, max] inclusive.
void assertInRange(num value, num min, num max, String fieldName) {
  if (value < min || value > max) {
    throw AssertionError(
      '$fieldName: expected value in range [$min, $max], got $value',
    );
  }
}

/// Asserts that [value] is a non-empty string.
void assertNonEmpty(String value, String fieldName) {
  if (value.isEmpty) {
    throw AssertionError('$fieldName: expected non-empty string, got empty');
  }
}

/// Asserts that [value] has at least [minLength] elements/characters.
void assertMinLength(dynamic value, int minLength, String fieldName) {
  final int length;
  if (value is String) {
    length = value.length;
  } else if (value is List) {
    length = value.length;
  } else if (value is Uint8List) {
    length = value.length;
  } else {
    throw AssertionError(
      '$fieldName: cannot determine length of ${value.runtimeType}',
    );
  }

  if (length < minLength) {
    throw AssertionError(
      '$fieldName: expected minimum length $minLength, got $length',
    );
  }
}

/// Asserts that [value] is a valid hex string.
void assertHexString(String value, String fieldName) {
  if (value.isEmpty) {
    throw AssertionError('$fieldName: expected non-empty hex string, got empty');
  }
  final hexPattern = RegExp(r'^[0-9A-Fa-f]+$');
  if (!hexPattern.hasMatch(value)) {
    throw AssertionError(
      '$fieldName: expected valid hex string, got "$value"',
    );
  }
}

/// Asserts that [value] matches expected firmware version format (e.g., "2.4.4").
void assertFirmwareVersionFormat(String value, String fieldName) {
  assertNonEmpty(value, fieldName);
  final versionPattern = RegExp(r'^\d+\.\d+(\.\d+)?$');
  if (!versionPattern.hasMatch(value)) {
    throw AssertionError(
      '$fieldName: expected firmware version format (e.g., "2.4.4"), got "$value"',
    );
  }
}

/// Asserts that [value] matches scan date format (YYMMDDHHMMSS).
void assertScanDateFormat(String value, String fieldName) {
  if (value.length != 12) {
    throw AssertionError(
      '$fieldName: expected 12 character date (YYMMDDHHMMSS), got ${value.length} characters',
    );
  }
  final datePattern = RegExp(r'^\d{12}$');
  if (!datePattern.hasMatch(value)) {
    throw AssertionError(
      '$fieldName: expected numeric date string (YYMMDDHHMMSS), got "$value"',
    );
  }
}

/// Validates DeviceInfo from a real NIRScan Nano sensor.
void assertValidDeviceInfo(DeviceInfo info) {
  assertNonEmpty(info.manufacturerName, 'manufacturerName');

  assertNonEmpty(info.modelNumber, 'modelNumber');
  if (!info.modelNumber.toUpperCase().contains('NIR') &&
      !info.modelNumber.toUpperCase().contains('NANO')) {
    throw AssertionError(
      'modelNumber: expected to contain "NIR" or "Nano", got "${info.modelNumber}"',
    );
  }

  assertNonEmpty(info.serialNumber, 'serialNumber');
  final alphanumericPattern = RegExp(r'^[A-Za-z0-9]+$');
  if (!alphanumericPattern.hasMatch(info.serialNumber)) {
    throw AssertionError(
      'serialNumber: expected alphanumeric string, got "${info.serialNumber}"',
    );
  }

  assertNonEmpty(info.hardwareRevision, 'hardwareRevision');

  assertFirmwareVersionFormat(info.tivaFirmwareRevision, 'tivaFirmwareRevision');

  assertNonEmpty(info.spectrumLibraryRevision, 'spectrumLibraryRevision');
}

/// Validates DeviceStatus from a real NIRScan Nano sensor.
void assertValidDeviceStatus(DeviceStatus status) {
  assertInRange(status.batteryLevel, 0, 100, 'batteryLevel');

  // Sensor operating temperature range: -20C to 85C
  assertInRange(status.temperature, -20, 85, 'temperature');

  assertInRange(status.humidity, 0, 100, 'humidity');

  assertNonEmpty(status.deviceStatus, 'deviceStatus');
  assertHexString(status.deviceStatus, 'deviceStatus');

  // errorStatus can be "00" for no errors, but must be valid hex
  assertNonEmpty(status.errorStatus, 'errorStatus');
  assertHexString(status.errorStatus, 'errorStatus');
}

/// Validates ScanData from a real NIRScan Nano sensor.
void assertValidScanData(ScanData data) {
  assertNonEmpty(data.name, 'name');

  assertNonEmpty(data.type, 'type');
  assertHexString(data.type, 'type');

  assertScanDateFormat(data.date, 'date');

  // Typical scan data is 2000+ bytes, minimum sanity check is 100 bytes
  assertMinLength(data.rawData, 100, 'rawData');

  // scanIndex is optional, but if present must be exactly 4 bytes
  if (data.scanIndex != null) {
    if (data.scanIndex!.length != 4) {
      throw AssertionError(
        'scanIndex: expected exactly 4 bytes, got ${data.scanIndex!.length}',
      );
    }
  }
}

/// Validates calibration data from a real NIRScan Nano sensor.
///
/// Validates all three calibration components:
/// - Spectrum coefficients: polynomial for wavelength-to-pixel mapping (>= 48 bytes = 6 x float64)
/// - Reference coefficients: calibration coefficients (>= 100 bytes)
/// - Reference matrix: calibration matrix (>= 100 bytes)
///
/// [logger] is required for diagnostic output -- these logs are the primary
/// remote debugging tool when running on a physical device.
void assertValidCalibrationData(CalibrationData calData, IntegrationLogger logger) {
  // Spectrum calibration coefficients: 6 x float64 = 48 bytes minimum
  logger.cal(
      '[ASSERT] Validating spectrum calibration coefficients: '
      '${calData.spectrumCoefficients.length} bytes');

  if (calData.spectrumCoefficients.length < 48) {
    final hexDump = calData.spectrumCoefficients
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.cal(
        '[ASSERT] FAIL: Spectrum cal coefficients too small: '
        '${calData.spectrumCoefficients.length} bytes, expected >= 48 (6 x float64). '
        'Raw hex: $hexDump');
    throw AssertionError(
      'Spectrum cal coefficients too small: '
      '${calData.spectrumCoefficients.length} bytes, expected >= 48 (6 x float64)',
    );
  }
  logger.cal(
      '[ASSERT] Spectrum calibration coefficients VALID: '
      '${calData.spectrumCoefficients.length} bytes >= 48');

  // Reference calibration coefficients
  logger.cal(
      '[ASSERT] Validating reference coefficients: '
      '${calData.coefficients.length} bytes');
  assertMinLength(calData.coefficients, 100, 'calibration coefficients');
  logger.cal(
      '[ASSERT] Reference coefficients VALID: '
      '${calData.coefficients.length} bytes >= 100');

  // Reference calibration matrix
  logger.cal(
      '[ASSERT] Validating reference matrix: '
      '${calData.matrix.length} bytes');
  assertMinLength(calData.matrix, 100, 'calibration matrix');
  logger.cal(
      '[ASSERT] Reference matrix VALID: '
      '${calData.matrix.length} bytes >= 100');

  final totalBytes = calData.spectrumCoefficients.length +
      calData.coefficients.length +
      calData.matrix.length;
  logger.cal(
      '[ASSERT] All calibration data VALID: ${totalBytes}B total '
      '(specCoeff=${calData.spectrumCoefficients.length}B, '
      'refCoeff=${calData.coefficients.length}B, '
      'refMatrix=${calData.matrix.length}B)');
}
