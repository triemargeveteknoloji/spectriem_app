# implement-real-service - Retrospective

**Completed:** 2026-01-26
**Total Duration:** 2026-01-25 → 2026-01-26
**Sessions:** 3

## Summary
Implemented complete RealNirScanService for NIRScan Nano BLE communication. Built from scratch with TDD approach: BleAdapter abstraction, MultiPacketReceiver for 20-byte MTU handling, and full service implementation covering device discovery, connection management, characteristic reading, notification subscriptions, and scan execution with multi-packet data retrieval.

## Metrics
| Metric | Value |
|--------|-------|
| Tasks Completed | 21/21 |
| Tests Written | 63 |
| Files Created | 6 |
| Sessions | 3 |

## What Went Well
- TDD approach caught edge cases early (negative temps, little-endian parsing)
- BleAdapter abstraction made testing straightforward with mockito
- MultiPacketReceiver as separate class enabled focused unit testing
- Incremental implementation allowed early validation of each phase
- Existing MockNirScanService served as excellent reference for patterns

## What Could Be Better
- Stream controller lifecycle management in tests needed iteration
- Test timing with async notification mocking required careful ordering
- Some GATT UUIDs needed verification against documentation

## Lessons Learned
- Separate helper classes for complex async patterns (MultiPacketReceiver) improve testability
- Await order matters when testing async streams - expectLater before closing controllers
- BLE notification subscription order can affect device behavior

## Follow-up Items
- [ ] Add timeout handling to MultiPacketReceiver
- [ ] Implement remaining stubbed methods (configurations, stored scans)
- [ ] Integration tests with real sensor
- [ ] Add connection retry logic

## Key Decisions Made
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| BleAdapter abstraction | Decouple from flutter_blue_plus for testing | Clean mock injection |
| Separate MultiPacketReceiver | Isolate packet handling complexity | 25 focused unit tests |
| Stub unimplemented methods | Get core flow working first | Clear UnsupportedError paths |

## Code References
- `lib/services/ble/real_nir_scan_service.dart` - Core BLE service (525 lines)
- `lib/services/ble/multi_packet_receiver.dart` - Multi-packet handler (72 lines)
- `lib/services/ble/ble_adapter.dart` - BLE abstraction (46 lines)
- `test/services/ble/real_nir_scan_service_test.dart` - Service tests (1158 lines)
- `test/services/ble/multi_packet_receiver_test.dart` - Receiver tests (242 lines)
