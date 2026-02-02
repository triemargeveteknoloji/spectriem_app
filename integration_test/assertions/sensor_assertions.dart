import 'dart:typed_data';

import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/models/scan_data.dart';

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
void assertValidCalibrationData(Uint8List coefficients, Uint8List matrix) {
  assertMinLength(coefficients, 100, 'calibration coefficients');
  assertMinLength(matrix, 100, 'calibration matrix');
}
