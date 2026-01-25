# implement-real-service

**Created:** 2026-01-25
**Status:** 🚧 In Progress
**Priority:** P2

## Quick Note
RealNirScanService BLE implementasyonu - gerçek DLPNIRNANOEVM sensörü ile iletişim

## Brainstorm Outcome - 2026-01-25

### Problem (Refined)
MockNirScanService mevcut ve test için kullanılabiliyor, ancak gerçek sensör ile iletişim kuracak RealNirScanService henüz yok. Interface tanımlı (20+ method), GATT UUID'leri (nano_gatt.dart) ve protokol akışları dokümante edilmiş.

### Chosen Approach
**Incremental Core Implementation** - Full implementation yerine seçildi:
1. Erken test edilebilir milestone'lar sağlar
2. Her aşama bağımsız doğrulanabilir
3. Gerçek sensör ile erken feedback alınabilir

### Key Decisions
| Karar | Gerekçe |
|-------|---------|
| Core BLE önce | Temel akışlar öncelikli, scan sonra |
| Exception-based errors | Mevcut NirScanException hiyerarşisi ile tutarlı |
| Ayrı MultiPacketReceiver | Test edilebilir, reusable helper |

### Constraints
- flutter_blue_plus ^1.31.0 version lock
- Android 6.0+ / iOS 10+ minimum platform
- BLE 4.0 (MTU 20 byte) multi-packet gerektirir

## Related Files
- `lib/services/ble/nir_scan_service.dart` - Interface
- `lib/services/ble/mock_nir_scan_service.dart` - Referans
- `lib/services/ble/nano_gatt.dart` - GATT UUIDs
- `.claude/skills/dlpnirnanoevm-sensor/` - Protokol docs

## Tags
- ble
- nir-sensor
- implementation
- flutter_blue_plus
