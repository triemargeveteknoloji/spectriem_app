/// Device status from NIRScan Nano
class DeviceStatus {
  /// Battery level (0-100)
  final int batteryLevel;

  /// Temperature in Celsius
  final double temperature;

  /// Humidity percentage
  final double humidity;

  /// Device status flags (hex string)
  final String deviceStatus;

  /// Error status flags (hex string)
  final String errorStatus;

  const DeviceStatus({
    required this.batteryLevel,
    required this.temperature,
    required this.humidity,
    required this.deviceStatus,
    required this.errorStatus,
  });

  /// Returns true if battery is low (< 20%)
  bool get isBatteryLow => batteryLevel < 20;

  /// Returns true if battery is critical (< 10%)
  bool get isBatteryCritical => batteryLevel < 10;

  /// Returns true if there are any error flags
  bool get hasErrors => errorStatus != '00' && errorStatus.isNotEmpty;

  /// Parse error status into human-readable messages
  List<String> get errorMessages {
    if (!hasErrors) return [];

    final errors = <String>[];
    final errorCode = int.tryParse(errorStatus, radix: 16) ?? 0;

    if (errorCode & 0x01 != 0) errors.add('Lamp error');
    if (errorCode & 0x02 != 0) errors.add('Battery low');
    if (errorCode & 0x04 != 0) errors.add('Temperature out of range');
    if (errorCode & 0x08 != 0) errors.add('Calibration needed');

    return errors;
  }

  @override
  String toString() => 'DeviceStatus('
      'battery: $batteryLevel%, '
      'temp: ${temperature.toStringAsFixed(1)}C, '
      'humid: ${humidity.toStringAsFixed(1)}%, '
      'status: $deviceStatus, '
      'errors: $errorStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceStatus &&
          runtimeType == other.runtimeType &&
          batteryLevel == other.batteryLevel &&
          temperature == other.temperature &&
          humidity == other.humidity &&
          deviceStatus == other.deviceStatus &&
          errorStatus == other.errorStatus;

  @override
  int get hashCode => Object.hash(
        batteryLevel,
        temperature,
        humidity,
        deviceStatus,
        errorStatus,
      );
}
