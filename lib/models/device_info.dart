/// Device information from NIRScan Nano
class DeviceInfo {
  final String manufacturerName;
  final String modelNumber;
  final String serialNumber;
  final String hardwareRevision;
  final String tivaFirmwareRevision;
  final String spectrumLibraryRevision;

  const DeviceInfo({
    required this.manufacturerName,
    required this.modelNumber,
    required this.serialNumber,
    required this.hardwareRevision,
    required this.tivaFirmwareRevision,
    required this.spectrumLibraryRevision,
  });

  @override
  String toString() => 'DeviceInfo('
      'manufacturer: $manufacturerName, '
      'model: $modelNumber, '
      'serial: $serialNumber, '
      'hw: $hardwareRevision, '
      'tiva: $tivaFirmwareRevision, '
      'specLib: $spectrumLibraryRevision)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          manufacturerName == other.manufacturerName &&
          modelNumber == other.modelNumber &&
          serialNumber == other.serialNumber &&
          hardwareRevision == other.hardwareRevision &&
          tivaFirmwareRevision == other.tivaFirmwareRevision &&
          spectrumLibraryRevision == other.spectrumLibraryRevision;

  @override
  int get hashCode => Object.hash(
        manufacturerName,
        modelNumber,
        serialNumber,
        hardwareRevision,
        tivaFirmwareRevision,
        spectrumLibraryRevision,
      );
}
