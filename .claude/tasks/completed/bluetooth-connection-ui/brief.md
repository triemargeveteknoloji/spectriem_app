# bluetooth-connection-ui

**Created:** 2026-01-26
**Status:** 🚧 In Progress
**Priority:** P2

## Quick Note
Bluetooth connection UI for NIR sensor. Full screen device list with expandable debug log panel.

## Brainstorm Outcome - 2026-01-26

### Problem (Refined)
Kullanıcının DLPNIRNANOEVM sensörünü BLE üzerinden taraması, bağlanması ve bağlantı durumunu izlemesi gerekiyor. Scan işlemi ayrı bir ekranda olacak — bu ekran sadece sensörü "hazır" hale getirmeye odaklanıyor.

### Chosen Approach
**Stream-based Logger + Embed Widget**
- `LogService` singleton — `Stream<LogEntry>` ile log yayını
- `LogViewerWidget` — herhangi bir ekrana embed edilebilir
- Flutter-native pattern (StreamBuilder)
- Proje çapında kullanılabilir (bluetooth + scan + diğer)

### Key Decisions
| Karar | Gerekçe |
|-------|---------|
| Stream-based logger | Flutter idiomatic, test edilebilir, loose coupling |
| Expandable log panel | Full screen device list, log isteğe bağlı görünür |
| Debug-level logging | Geliştirici odaklı, teknik detaylar (GATT UUID, bytes, timing) |
| Ana ekran | Uygulama açılınca direkt bu ekrana gelir |

### Constraints
- Mevcut `NirScanService` interface'ini kullan
- State management henüz yok (Riverpod değil, vanilla streams)
- Logging modülü bağımsız olmalı (reusable across screens)

## Related Files
- `lib/services/ble/nir_scan_service.dart` — Abstract interface
- `lib/services/ble/real_nir_scan_service.dart` — BLE implementation
- `lib/services/ble/mock_nir_scan_service.dart` — Test mock

## Tags
- ui
- bluetooth
- logging
