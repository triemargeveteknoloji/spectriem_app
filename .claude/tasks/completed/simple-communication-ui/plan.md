# simple-communication-ui - Strategic Plan

## Executive Summary
Sensörle bidirectional iletişim için UI ekranı. Preset butonlar ile komut gönderme, unified log view ile mesaj takibi, response display ile sonuç görüntüleme.

## Problem Statement
Kullanıcının sensörle etkileşim kurması için bir arayüz gerekli: scan başlatma/durdurma, cihaz bilgisi sorgulama, status okuma, scan konfigürasyonu değiştirme.

## Chosen Approach
**SensorCommunicationScreen** — Mevcut connection page pattern'ini takip eden StatefulWidget:
- Command section: Preset butonlar (Scan, Stop, Info, Status, SyncTime, Config)
- Config dropdown: Scan konfigürasyonu seçimi
- Response display: Son başarılı yanıtın detaylı gösterimi
- Log panel: Mevcut LogViewerWidget ile unified log (↑ sent, ↓ received)

## Acceptance Criteria
- [ ] AC1: Ekran açıldığında command butonları görünür
- [ ] AC2: Her komut butonu ilgili NirScanService metodunu çağırır
- [ ] AC3: Komut gönderildiğinde log'a "↑ CMD: ..." yazılır
- [ ] AC4: Yanıt alındığında log'a "↓ RSP: ..." yazılır
- [ ] AC5: Başarılı yanıt response display'de gösterilir
- [ ] AC6: Hata durumunda error mesajı log'a ve UI'a yansır
- [ ] AC7: Log panel toggle çalışır (AppBar butonu ile)
- [ ] AC8: Scan config dropdown'dan seçim yapılabilir

## Test Strategy (TDD)

### Unit Tests
- [ ] Test: Command butonları doğru service metodlarını çağırır
- [ ] Test: Log entries doğru format ve prefix ile oluşturulur
- [ ] Test: Error handling düzgün çalışır (NirScanException cases)
- [ ] Test: Response display doğru model tipini render eder

### Widget Tests
- [ ] Test: SensorCommunicationScreen renders with all buttons
- [ ] Test: Button tap triggers loading state
- [ ] Test: Log panel toggle works
- [ ] Test: Config dropdown displays options

### Integration Tests
- [ ] Test: Full flow - button tap → service call → log update → response display

### Edge Cases
- [ ] Edge: Disconnected state → butonlar disabled
- [ ] Edge: Timeout → error log + retry option
- [ ] Edge: Multiple rapid taps → debounce/queue

## Implementation Phases

### Phase 1: Test Foundation 🧪
- [ ] Create test file: `test/widget/sensor_communication_screen_test.dart`
- [ ] Write failing test: screen renders with command buttons
- [ ] Write failing test: button tap calls service method
- [ ] Write failing test: log panel toggle works
- [ ] Set up mock service for tests

### Phase 2: Basic Screen Structure 🔨
- [ ] Create `SensorCommunicationScreen` StatefulWidget
- [ ] Add AppBar with log toggle button
- [ ] Add command buttons grid
- [ ] Add log panel with LogViewerWidget
- [ ] Verify Phase 1 tests pass

### Phase 3: Command Execution 🔨
- [ ] Implement button tap handlers
- [ ] Add loading state per button
- [ ] Log command sent (↑ CMD)
- [ ] Call NirScanService method
- [ ] Log response received (↓ RSP)
- [ ] Handle errors

### Phase 4: Response Display 🔨
- [ ] Add response display section
- [ ] Render DeviceInfo card
- [ ] Render DeviceStatus card
- [ ] Render ScanData card (basic)
- [ ] Render ScanConfiguration list

### Phase 5: Config Dropdown 🔨
- [ ] Fetch scan configurations on init
- [ ] Add dropdown widget
- [ ] Implement selection handler
- [ ] Call setActiveScanConfiguration

### Phase 6: Polish ✨
- [ ] Disabled state when disconnected
- [ ] Loading indicators
- [ ] Error display improvements
- [ ] Edge case handling (debounce, timeout)

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Service method failures | Medium | Medium | Proper error handling, retry option |
| Long-running operations block UI | Low | High | Async/await, loading states |
| Log overflow with rapid commands | Low | Low | Existing LogService buffer limit (1000) |

## Constraints
- Must use existing `NirScanService` interface
- Must reuse `LogViewerWidget` for consistency
- Follow connection page patterns (setState + Streams)

## Success Metrics
- [ ] All tests pass
- [ ] All 8 acceptance criteria met
- [ ] No regression in existing functionality
- [ ] Code follows existing patterns

## Estimated Effort
- Size: M (Medium)
- Complexity: Medium
