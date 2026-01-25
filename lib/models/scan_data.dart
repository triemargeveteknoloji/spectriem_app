import 'dart:typed_data';

/// Spectral scan data from NIRScan Nano
class ScanData {
  /// Scan name/identifier
  final String name;

  /// Scan type (hex string)
  final String type;

  /// Scan date as string (YYMMDDHHMMSS format)
  final String date;

  /// Packet format version
  final String packetFormatVersion;

  /// Raw serialized scan data
  final Uint8List rawData;

  /// Scan index for SD storage (4 bytes)
  final List<int>? scanIndex;

  const ScanData({
    required this.name,
    required this.type,
    required this.date,
    required this.packetFormatVersion,
    required this.rawData,
    this.scanIndex,
  });

  /// Parse scan date to DateTime
  DateTime? get dateTime {
    if (date.length < 12) return null;
    try {
      final year = 2000 + int.parse(date.substring(0, 2));
      final month = int.parse(date.substring(2, 4));
      final day = int.parse(date.substring(4, 6));
      final hour = int.parse(date.substring(6, 8));
      final minute = int.parse(date.substring(8, 10));
      final second = int.parse(date.substring(10, 12));
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ScanData('
      'name: $name, '
      'type: $type, '
      'date: $date, '
      'dataSize: ${rawData.length} bytes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          date == other.date &&
          packetFormatVersion == other.packetFormatVersion;

  @override
  int get hashCode => Object.hash(name, type, date, packetFormatVersion);
}

/// Parsed spectral data with wavelength and intensity values
class SpectralData {
  /// Wavelength values in nanometers
  final List<double> wavelengths;

  /// Intensity/absorbance values
  final List<double> intensities;

  /// Reference intensities (for absorbance calculation)
  final List<double>? referenceIntensities;

  const SpectralData({
    required this.wavelengths,
    required this.intensities,
    this.referenceIntensities,
  });

  /// Number of data points
  int get length => wavelengths.length;

  /// Minimum wavelength
  double get minWavelength =>
      wavelengths.isEmpty ? 0 : wavelengths.reduce((a, b) => a < b ? a : b);

  /// Maximum wavelength
  double get maxWavelength =>
      wavelengths.isEmpty ? 0 : wavelengths.reduce((a, b) => a > b ? a : b);

  /// Minimum intensity
  double get minIntensity =>
      intensities.isEmpty ? 0 : intensities.reduce((a, b) => a < b ? a : b);

  /// Maximum intensity
  double get maxIntensity =>
      intensities.isEmpty ? 0 : intensities.reduce((a, b) => a > b ? a : b);
}
