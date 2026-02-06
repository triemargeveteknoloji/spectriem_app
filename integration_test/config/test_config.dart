import 'dart:io' show Platform;

/// Test execution mode for BLE integration tests.
enum TestMode {
  /// Runs all steps automatically without user intervention.
  fullAuto,

  /// Pauses between steps for user confirmation.
  semiAuto,
}

/// Configuration for NIR sensor BLE integration tests.
///
/// Reads configuration from environment variables:
/// - `TEST_MODE`: "fullAuto" or "semiAuto" (default: fullAuto)
/// - `DEVICE_NAME`: Optional device name filter for BLE scanning
class TestConfig {
  final TestMode testMode;
  final String? preferredDeviceName;

  // Timeout constants
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration deviceInfoTimeout = Duration(seconds: 5);
  static const Duration performScanTimeout = Duration(seconds: 60);
  static const Duration calibrationTimeout = Duration(seconds: 30);
  static const Duration multiPacketTimeout = Duration(seconds: 10);
  static const Duration statusTimeout = Duration(seconds: 5);
  static const Duration configTimeout = Duration(seconds: 30);
  static const Duration disconnectTimeout = Duration(seconds: 5);

  const TestConfig({
    required this.testMode,
    this.preferredDeviceName,
  });

  /// Creates a [TestConfig] from environment variables.
  ///
  /// Environment variables:
  /// - `TEST_MODE`: "semiAuto" for semi-automatic mode, anything else for fullAuto
  /// - `DEVICE_NAME`: Optional preferred device name for filtering during scan
  factory TestConfig.fromEnvironment() {
    final env = Platform.environment;

    final modeStr = env['TEST_MODE']?.toLowerCase();
    final testMode = modeStr == 'semiauto' ? TestMode.semiAuto : TestMode.fullAuto;

    final deviceName = env['DEVICE_NAME'];

    return TestConfig(
      testMode: testMode,
      preferredDeviceName: deviceName?.isNotEmpty == true ? deviceName : null,
    );
  }

  /// Returns true if running in semi-automatic mode.
  bool get isSemiAuto => testMode == TestMode.semiAuto;
}
