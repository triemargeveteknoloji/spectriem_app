import 'dart:typed_data';

/// Scan configuration from NIRScan Nano
class ScanConfiguration {
  /// Configuration index on device
  final int index;

  /// Configuration name
  final String name;

  /// Raw configuration data
  final Uint8List rawData;

  /// Number of scan patterns
  final int numPatterns;

  /// Number of repeats per pattern
  final int numRepeats;

  /// Start wavelength in nm
  final double startWavelength;

  /// End wavelength in nm
  final double endWavelength;

  /// Wavelength resolution in nm
  final double resolution;

  const ScanConfiguration({
    required this.index,
    required this.name,
    required this.rawData,
    this.numPatterns = 0,
    this.numRepeats = 1,
    this.startWavelength = 900.0,
    this.endWavelength = 1700.0,
    this.resolution = 10.0,
  });

  /// Wavelength range description
  String get wavelengthRange =>
      '${startWavelength.toInt()}-${endWavelength.toInt()} nm';

  /// Estimated scan points
  int get estimatedPoints =>
      ((endWavelength - startWavelength) / resolution).round();

  @override
  String toString() => 'ScanConfiguration('
      'index: $index, '
      'name: $name, '
      'range: $wavelengthRange, '
      'resolution: ${resolution}nm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanConfiguration &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          name == other.name;

  @override
  int get hashCode => Object.hash(index, name);
}
