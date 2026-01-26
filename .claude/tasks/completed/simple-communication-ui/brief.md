# simple-communication-ui

**Created:** 2026-01-26
**Status:** ✅ Completed
**Priority:** P2

## Quick Note
Sensör ile haberleşme sayfası - hem okuma hem yazma (komut gönderme) desteği.

## Brainstorm Outcome - 2026-01-26

### Problem (Refined)
Sensörle etkileşim için UI gerekli: scan başlatma/durdurma, cihaz bilgisi sorgulama, status okuma, config değiştirme.

### Chosen Approach
**SensorCommunicationScreen** — Preset buttons + dropdown + unified log view
- Mevcut `LogViewerWidget` reuse
- `NirScanService` methods doğrudan çağrılacak
- Log'da ↑/↓ prefix ile gönderilen/gelen mesajlar
- Response display'de son yanıt detaylı gösterilecek

### Key Decisions
| Karar | Gerekçe |
|-------|---------|
| Preset buttons (text input yok) | Basic functionality için yeterli, daha basit UI |
| Unified log (A seçeneği) | Tek liste daha temiz, renk/ikon ile ayrım |
| Mevcut LogViewerWidget | Tekrar kullanım, tutarlı UX |

### Constraints
- Mevcut NirScanService interface'ine bağlı kalınacak
- Connection page pattern'i takip edilecek

## Related Files
- `lib/screens/bluetooth_connection_screen.dart` — Referans pattern
- `lib/widgets/log_viewer_widget.dart` — Reuse edilecek
- `lib/services/ble/nir_scan_service.dart` — Interface
- `lib/models/` — DeviceInfo, DeviceStatus, ScanData, ScanConfiguration

## Tags
- ui
- communication
- ble
