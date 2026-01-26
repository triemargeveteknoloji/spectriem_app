# Bluetooth Connection UI - Strategic Plan

## Executive Summary
BLE sensör bağlantı ekranı: cihaz tarama, bağlanma ve durum izleme. Proje çapında kullanılabilir stream-based logging modülü ile birlikte. Ana ekran olarak çalışacak, expandable debug log panel içerecek.

## Problem Statement
Kullanıcının DLPNIRNANOEVM sensörünü keşfetmesi, bağlanması ve bağlantı durumunu izlemesi gerekiyor. Ayrıca geliştirme sürecinde BLE iletişimini debug edebilmek için kapsamlı logging çıktısı lazım.

## Chosen Approach
**Stream-based Logger + Embed Widget**

Seçim gerekçeleri:
- Flutter idiomatic (StreamBuilder pattern)
- Test edilebilir (stream mock'lanabilir)
- Loose coupling — widget ve service bağımsız
- Proje çapında reusable

## Acceptance Criteria
- [ ] AC1: Uygulama açılınca bluetooth connection ekranı görünür
- [ ] AC2: Yakındaki BLE cihazları taranabilir ve listelenir
- [ ] AC3: Cihaza bağlanılabilir ve bağlantı durumu görünür
- [ ] AC4: Bağlantı sonrası device info ve status görüntülenir
- [ ] AC5: Log panel expand/collapse edilebilir
- [ ] AC6: Log'lar timestamp, level ve mesaj içerir
- [ ] AC7: Log seviyesine göre filtreleme yapılabilir (debug, info, warning, error)
- [ ] AC8: MockNirScanService ile çalışır (gerçek sensör olmadan test)

## Test Strategy (TDD)

### Unit Tests — LogService
- [ ] Test: LogService.log() adds entry to stream → validates stream emission
- [ ] Test: LogEntry has correct timestamp → validates auto-timestamp
- [ ] Test: Log levels filter correctly → validates filtering logic
- [ ] Test: LogService.clear() empties buffer → validates clear functionality
- [ ] Test: LogService exposes log history → validates buffer access

### Unit Tests — LogViewerWidget
- [ ] Test: Widget renders log entries → validates StreamBuilder integration
- [ ] Test: Widget scrolls to bottom on new entry → validates auto-scroll
- [ ] Test: Level filter chips work → validates filter UI

### Widget Tests — BluetoothConnectionScreen
- [ ] Test: Screen shows scan button when disconnected → validates initial state
- [ ] Test: Scanning shows loading indicator → validates scanning state
- [ ] Test: Device list shows discovered devices → validates device rendering
- [ ] Test: Tap device initiates connection → validates connection flow
- [ ] Test: Connected state shows device info → validates connected UI
- [ ] Test: Log panel toggles on button tap → validates expand/collapse

### Integration Tests
- [ ] Test: Full flow with MockNirScanService → validates end-to-end
- [ ] Test: Connection error shows error state → validates error handling

### Edge Cases
- [ ] Edge: No devices found → expected: "No devices found" message
- [ ] Edge: Connection timeout → expected: error state with retry option
- [ ] Edge: Device disconnects unexpectedly → expected: UI updates to disconnected
- [ ] Edge: Rapid scan/stop cycles → expected: no crashes, clean state

## Implementation Phases

### Phase 1: Logging Module (Test Foundation)
1. Write failing tests for LogEntry model
2. Write failing tests for LogService
3. Implement LogEntry and LogService
4. Write failing tests for LogViewerWidget
5. Implement LogViewerWidget

### Phase 2: Bluetooth Connection Screen (Core UI)
1. Write failing widget tests for BluetoothConnectionScreen
2. Implement screen scaffold with states (idle, scanning, connecting, connected, error)
3. Implement device list widget
4. Implement connection status widget
5. Integrate LogViewerWidget as expandable panel

### Phase 3: Integration & Polish
1. Wire up with MockNirScanService for development
2. Add RealNirScanService integration
3. Handle edge cases (timeouts, disconnects)
4. Polish animations and transitions
5. Integration tests

## Component Design

### LogEntry Model
```dart
enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;  // e.g., "BLE", "GATT", "UI"
  final Map<String, dynamic>? metadata;  // optional structured data
}
```

### LogService Interface
```dart
abstract class LogService {
  Stream<LogEntry> get logStream;
  List<LogEntry> get history;

  void debug(String message, {String? tag, Map<String, dynamic>? metadata});
  void info(String message, {String? tag, Map<String, dynamic>? metadata});
  void warning(String message, {String? tag, Map<String, dynamic>? metadata});
  void error(String message, {String? tag, Map<String, dynamic>? metadata});

  void clear();
  void dispose();
}
```

### Screen States
```dart
enum BluetoothScreenState {
  idle,        // Initial, not scanning
  scanning,    // Actively scanning
  connecting,  // Connection in progress
  connected,   // Connected to device
  error,       // Error occurred
}
```

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| BLE permission issues | Medium | High | Early permission handling, clear error messages |
| Log memory bloat | Low | Medium | Implement max buffer size with oldest-first eviction |
| UI jank during scan | Low | Medium | Use isolate for heavy processing if needed |

## Constraints
- Mevcut NirScanService interface'i kullanılacak
- State management yok (vanilla streams/setState)
- Logging modülü bağımsız ve reusable olmalı

## Success Metrics
- [ ] All tests pass
- [ ] MockNirScanService ile tam akış çalışır
- [ ] Log panel responsive ve smooth
- [ ] Code coverage > 80%

## Estimated Effort
- Size: M
- Complexity: Medium
