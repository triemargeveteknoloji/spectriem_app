import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/services/ble/multi_packet_receiver.dart';

void main() {
  late MultiPacketReceiver receiver;

  setUp(() {
    receiver = MultiPacketReceiver();
  });

  group('MultiPacketReceiver', () {
    group('header packet detection', () {
      test('recognizes header packet when first byte is 0x00', () {
        // Header: [0x00, size_lsb, size_msb]
        final headerPacket = [0x00, 0x0A, 0x00]; // 10 bytes expected

        receiver.onPacketReceived(headerPacket);

        expect(receiver.headerReceived, isTrue);
      });

      test('does not treat non-zero first byte as header', () {
        final dataPacket = [0x01, 0x0A, 0x0B, 0x0C];

        receiver.onPacketReceived(dataPacket);

        expect(receiver.headerReceived, isFalse);
      });

      test('ignores empty packets', () {
        receiver.onPacketReceived([]);

        expect(receiver.headerReceived, isFalse);
        expect(receiver.isComplete, isFalse);
      });
    });

    group('size extraction', () {
      test('extracts size from header as little-endian uint16', () {
        // Size = 0x000A = 10 bytes
        final headerPacket = [0x00, 0x0A, 0x00];

        receiver.onPacketReceived(headerPacket);

        expect(receiver.expectedSize, equals(10));
      });

      test('extracts larger size correctly', () {
        // Size = 0x0102 = 258 bytes (little-endian: [0x02, 0x01])
        final headerPacket = [0x00, 0x02, 0x01];

        receiver.onPacketReceived(headerPacket);

        expect(receiver.expectedSize, equals(258));
      });

      test('handles maximum size (65535 bytes)', () {
        // Size = 0xFFFF = 65535 bytes
        final headerPacket = [0x00, 0xFF, 0xFF];

        receiver.onPacketReceived(headerPacket);

        expect(receiver.expectedSize, equals(65535));
      });
    });

    group('data packet accumulation', () {
      test('accumulates data from packets after header', () {
        // Header: 5 bytes expected
        receiver.onPacketReceived([0x00, 0x05, 0x00]);
        // Data packet 1: bytes 1-4 are data
        receiver.onPacketReceived([0x01, 0xAA, 0xBB, 0xCC, 0xDD]);

        expect(receiver.data.length, equals(4));
        expect(receiver.data, equals([0xAA, 0xBB, 0xCC, 0xDD]));
      });

      test('accumulates data from multiple packets', () {
        // Header: 8 bytes expected
        receiver.onPacketReceived([0x00, 0x08, 0x00]);
        // Data packet 1
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]);
        // Data packet 2
        receiver.onPacketReceived([0x02, 0x05, 0x06, 0x07, 0x08]);

        expect(receiver.data.length, equals(8));
        expect(receiver.data, equals([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]));
      });

      test('ignores data packets before header is received', () {
        // Data packet without header first
        receiver.onPacketReceived([0x01, 0xAA, 0xBB, 0xCC]);

        expect(receiver.data, isEmpty);
      });

      test('does not accumulate beyond expected size', () {
        // Header: 3 bytes expected
        receiver.onPacketReceived([0x00, 0x03, 0x00]);
        // Data packet with more data than needed
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04, 0x05]);

        expect(receiver.data.length, equals(3));
        expect(receiver.data, equals([0x01, 0x02, 0x03]));
      });
    });

    group('completion detection', () {
      test('is not complete before header received', () {
        expect(receiver.isComplete, isFalse);
      });

      test('is not complete after header with zero data', () {
        receiver.onPacketReceived([0x00, 0x05, 0x00]);

        expect(receiver.isComplete, isFalse);
      });

      test('is complete when all expected data received', () {
        // Header: 4 bytes expected
        receiver.onPacketReceived([0x00, 0x04, 0x00]);
        // Data packet with exactly 4 bytes of data
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]);

        expect(receiver.isComplete, isTrue);
      });

      test('is complete when data accumulated over multiple packets', () {
        // Header: 6 bytes expected
        receiver.onPacketReceived([0x00, 0x06, 0x00]);
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03]);
        receiver.onPacketReceived([0x02, 0x04, 0x05, 0x06]);

        expect(receiver.isComplete, isTrue);
      });

      test('handles zero-size expected data', () {
        // Header: 0 bytes expected (edge case)
        receiver.onPacketReceived([0x00, 0x00, 0x00]);

        expect(receiver.isComplete, isTrue);
        expect(receiver.data, isEmpty);
      });
    });

    group('incomplete state handling', () {
      test('reports incomplete when partially received', () {
        // Header: 10 bytes expected
        receiver.onPacketReceived([0x00, 0x0A, 0x00]);
        // Only 4 bytes received
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]);

        expect(receiver.isComplete, isFalse);
        expect(receiver.data.length, equals(4));
      });

      test('receivedSize tracks accumulated bytes', () {
        receiver.onPacketReceived([0x00, 0x10, 0x00]); // 16 bytes expected
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]); // 4 bytes

        expect(receiver.receivedSize, equals(4));
      });
    });

    group('progress calculation', () {
      test('progress is 0 before header', () {
        expect(receiver.progress, equals(0.0));
      });

      test('progress is 0 after header with no data', () {
        receiver.onPacketReceived([0x00, 0x10, 0x00]); // 16 bytes expected

        expect(receiver.progress, equals(0.0));
      });

      test('progress reflects received percentage', () {
        receiver.onPacketReceived([0x00, 0x10, 0x00]); // 16 bytes expected
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]); // 4 bytes

        expect(receiver.progress, equals(0.25)); // 4/16 = 0.25
      });

      test('progress is 1.0 when complete', () {
        receiver.onPacketReceived([0x00, 0x04, 0x00]); // 4 bytes expected
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]); // 4 bytes

        expect(receiver.progress, equals(1.0));
      });

      test('progress handles zero expected size', () {
        receiver.onPacketReceived([0x00, 0x00, 0x00]); // 0 bytes expected

        expect(receiver.progress, equals(1.0)); // Complete immediately
      });
    });

    group('reset', () {
      test('reset clears all state', () {
        receiver.onPacketReceived([0x00, 0x04, 0x00]);
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]);

        receiver.reset();

        expect(receiver.headerReceived, isFalse);
        expect(receiver.expectedSize, equals(0));
        expect(receiver.data, isEmpty);
        expect(receiver.isComplete, isFalse);
        expect(receiver.progress, equals(0.0));
      });

      test('can receive new transmission after reset', () {
        // First transmission
        receiver.onPacketReceived([0x00, 0x02, 0x00]);
        receiver.onPacketReceived([0x01, 0xAA, 0xBB]);
        expect(receiver.isComplete, isTrue);

        receiver.reset();

        // Second transmission
        receiver.onPacketReceived([0x00, 0x03, 0x00]);
        receiver.onPacketReceived([0x01, 0x11, 0x22, 0x33]);

        expect(receiver.isComplete, isTrue);
        expect(receiver.data, equals([0x11, 0x22, 0x33]));
      });
    });

    group('new header resets state', () {
      test('receiving new header resets previous state', () {
        // First transmission starts
        receiver.onPacketReceived([0x00, 0x10, 0x00]); // 16 bytes
        receiver.onPacketReceived([0x01, 0x01, 0x02, 0x03, 0x04]); // partial

        // New header arrives (new transmission)
        receiver.onPacketReceived([0x00, 0x02, 0x00]); // 2 bytes

        expect(receiver.expectedSize, equals(2));
        expect(receiver.data, isEmpty);
      });
    });
  });
}
