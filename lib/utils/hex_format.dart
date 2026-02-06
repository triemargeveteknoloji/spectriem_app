import 'dart:typed_data';

/// Utility class for formatting byte data as hexadecimal strings.
class HexFormat {
  HexFormat._();

  /// Converts bytes to a hex string with configurable separator.
  ///
  /// Example: `[0x1A, 0x2B]` → `"1A 2B"` (default separator)
  static String toHexString(Uint8List bytes, {String separator = ' '}) {
    if (bytes.isEmpty) return '';
    return bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(separator);
  }

  /// Formats bytes as a classic hex dump with offsets and ASCII.
  ///
  /// Format: `0000: 48 65 6C 6C 6F 00 ... | Hello.`
  ///
  /// - 16 bytes per row
  /// - Non-printable characters shown as `.`
  /// - [maxBytes] limits output (null = show all)
  static String toHexDump(Uint8List bytes, {int? maxBytes}) {
    if (bytes.isEmpty) return '';

    final data = maxBytes != null ? truncate(bytes, maxBytes) : bytes;
    final buffer = StringBuffer();
    const bytesPerRow = 16;

    for (var offset = 0; offset < data.length; offset += bytesPerRow) {
      final end = (offset + bytesPerRow).clamp(0, data.length);
      final rowBytes = data.sublist(offset, end);

      // Offset
      buffer.write(offset.toRadixString(16).toUpperCase().padLeft(4, '0'));
      buffer.write(': ');

      // Hex bytes
      for (var i = 0; i < bytesPerRow; i++) {
        if (i < rowBytes.length) {
          buffer.write(rowBytes[i].toRadixString(16).toUpperCase().padLeft(2, '0'));
        } else {
          buffer.write('  ');
        }
        if (i < bytesPerRow - 1) buffer.write(' ');
      }

      buffer.write(' | ');

      // ASCII representation
      for (final byte in rowBytes) {
        buffer.write(_toPrintableAscii(byte));
      }

      if (offset + bytesPerRow < data.length) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Returns first [limit] bytes from [bytes].
  static Uint8List truncate(Uint8List bytes, int limit) {
    if (bytes.length <= limit) return bytes;
    return Uint8List.sublistView(bytes, 0, limit);
  }

  static String _toPrintableAscii(int byte) {
    // Printable ASCII range: 0x20 (space) to 0x7E (~)
    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }
    return '.';
  }
}
