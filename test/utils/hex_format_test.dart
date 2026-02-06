import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/utils/hex_format.dart';

void main() {
  group('HexFormat', () {
    group('toHexString', () {
      test('converts empty bytes to empty string', () {
        final bytes = Uint8List(0);

        expect(HexFormat.toHexString(bytes), equals(''));
      });

      test('converts single byte to two-char hex', () {
        final bytes = Uint8List.fromList([0x1A]);

        expect(HexFormat.toHexString(bytes), equals('1A'));
      });

      test('converts multiple bytes with space separator', () {
        final bytes = Uint8List.fromList([0x1A, 0x2B, 0x3C]);

        expect(HexFormat.toHexString(bytes), equals('1A 2B 3C'));
      });

      test('pads single digit hex values with zero', () {
        final bytes = Uint8List.fromList([0x00, 0x0F, 0x09]);

        expect(HexFormat.toHexString(bytes), equals('00 0F 09'));
      });

      test('handles 0xFF correctly', () {
        final bytes = Uint8List.fromList([0xFF, 0x00, 0xFF]);

        expect(HexFormat.toHexString(bytes), equals('FF 00 FF'));
      });

      test('supports custom separator', () {
        final bytes = Uint8List.fromList([0x1A, 0x2B, 0x3C]);

        expect(HexFormat.toHexString(bytes, separator: ':'), equals('1A:2B:3C'));
      });

      test('supports no separator', () {
        final bytes = Uint8List.fromList([0x1A, 0x2B, 0x3C]);

        expect(HexFormat.toHexString(bytes, separator: ''), equals('1A2B3C'));
      });
    });

    group('toHexDump', () {
      test('returns empty string for empty bytes', () {
        final bytes = Uint8List(0);

        expect(HexFormat.toHexDump(bytes), equals(''));
      });

      test('formats single row with offset and ASCII', () {
        // "Hello" in ASCII
        final bytes = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);

        final result = HexFormat.toHexDump(bytes);

        expect(result, contains('0000:'));
        expect(result, contains('48 65 6C 6C 6F'));
        expect(result, contains('Hello'));
      });

      test('replaces non-printable ASCII with dot', () {
        final bytes = Uint8List.fromList([0x00, 0x1F, 0x7F, 0x41]);

        final result = HexFormat.toHexDump(bytes);

        expect(result, contains('...A'));
      });

      test('formats 16 bytes per row', () {
        final bytes = Uint8List.fromList(List.generate(16, (i) => i));

        final result = HexFormat.toHexDump(bytes);
        final lines = result.split('\n');

        expect(lines.length, equals(1));
        expect(lines[0], contains('0000:'));
      });

      test('wraps to new line after 16 bytes', () {
        final bytes = Uint8List.fromList(List.generate(17, (i) => i));

        final result = HexFormat.toHexDump(bytes);
        final lines = result.split('\n');

        expect(lines.length, equals(2));
        expect(lines[0], contains('0000:'));
        expect(lines[1], contains('0010:'));
      });

      test('formats multiple complete rows', () {
        final bytes = Uint8List.fromList(List.generate(32, (i) => i));

        final result = HexFormat.toHexDump(bytes);
        final lines = result.split('\n');

        expect(lines.length, equals(2));
        expect(lines[0], contains('0000:'));
        expect(lines[1], contains('0010:'));
      });

      test('pads incomplete row with spaces', () {
        final bytes = Uint8List.fromList([0x41, 0x42, 0x43]); // ABC

        final result = HexFormat.toHexDump(bytes);

        // Hex part should have 16 byte positions (3 filled, 13 empty)
        // Each byte is "XX " (3 chars), incomplete row should be padded
        expect(result, contains('41 42 43'));
        expect(result, contains('ABC'));
      });

      test('supports limiting number of bytes', () {
        final bytes = Uint8List.fromList(List.generate(100, (i) => i));

        final result = HexFormat.toHexDump(bytes, maxBytes: 32);
        final lines = result.split('\n');

        expect(lines.length, equals(2)); // 32 bytes = 2 rows
      });

      test('offset increments correctly for multiple rows', () {
        final bytes = Uint8List.fromList(List.generate(48, (i) => 0x41));

        final result = HexFormat.toHexDump(bytes);
        final lines = result.split('\n');

        expect(lines[0], startsWith('0000:'));
        expect(lines[1], startsWith('0010:'));
        expect(lines[2], startsWith('0020:'));
      });
    });

    group('truncate', () {
      test('returns all bytes when under limit', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final result = HexFormat.truncate(bytes, 10);

        expect(result, equals(bytes));
      });

      test('returns exactly limit bytes when over', () {
        final bytes = Uint8List.fromList(List.generate(100, (i) => i));

        final result = HexFormat.truncate(bytes, 64);

        expect(result.length, equals(64));
        expect(result[0], equals(0));
        expect(result[63], equals(63));
      });

      test('returns all bytes when exactly at limit', () {
        final bytes = Uint8List.fromList(List.generate(64, (i) => i));

        final result = HexFormat.truncate(bytes, 64);

        expect(result.length, equals(64));
      });
    });
  });
}
