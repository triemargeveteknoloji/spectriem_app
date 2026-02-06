# implement-get-scan-configurations

**Created:** 2026-02-04
**Status:** 🚧 In Progress

---

## Problem
Scan configuration'ları sensörden BLE üzerinden çekip UI'da dropdown ile listelemek ve seçim yapabilmek. Sensöre aktif config set edebilmek.

## Approach
**Chosen:** Read-first approach - önce list, sonra select
**Why:** Temel okuma işlevselliği olmadan seçim yapmak mümkün değil

Mevcut altyapı üzerine inşa:
- GSCIS UUID'leri zaten tanımlı
- ScanConfiguration modeli hazır
- UI dropdown ve state management mevcut
- Sadece BLE service metodlarını implement etmek yeterli

## Decisions
- List + Select scope (no edit/delete)
- Service + basic display (dropdown ile)
- Mevcut `_fetchConfigIndices()` ve `_ensureActiveScanConfig()` helper'larını kullan

## Constraints
- Multi-packet protocol kullanılmalı (config data büyük olabilir)
- 100ms delay pattern'ı (subscription → write arası)
- Timeout koruması (10 saniye)
- TDD: Test first

## Related Files
- `lib/services/ble/nano_gatt.dart:180-208` - GSCIS UUID definitions
- `lib/services/ble/ble_nir_scan_service.dart:835-847` - Stub methods to implement
- `lib/services/ble/ble_nir_scan_service.dart:1077` - `_ensureActiveScanConfig()` existing helper
- `lib/services/ble/ble_nir_scan_service.dart:1189` - `_fetchConfigIndices()` existing helper
- `lib/services/ble/nir_scan_service.dart:74-81` - Interface definitions
- `lib/models/scan_configuration.dart` - ScanConfiguration model
- `lib/providers/sensor_communication_notifier.dart` - State management
- `lib/screens/sensor_communication_screen.dart:90-121` - UI dropdown (already exists)
- `lib/services/ble/mock_nir_scan_service.dart:237-269` - Mock implementation (already works)

---

## Tasks
- [x] Write unit tests for getScanConfigurations()
- [x] Implement getScanConfigurations() in BleNirScanService
- [x] Write unit tests for getActiveScanConfiguration()
- [x] Implement getActiveScanConfiguration() in BleNirScanService
- [x] Write unit tests for setActiveScanConfiguration()
- [x] Implement setActiveScanConfiguration() in BleNirScanService
- [x] Integration test with real device (partial - 1/2 configs)
- [ ] Verify UI dropdown works end-to-end
- [ ] **BLOCKER:** Index 4 config timeout - araştır neden sensör notification göndermiyor

## Sessions
**S1-S3** (2026-02-04): Init, TDD complete, BLE lock mechanism added.
  ⚡ Key: Completer-based mutex for concurrent BLE operations
**S4** (2026-02-04): Integration test with config step added.
**S5** (2026-02-04): ⚡ TPL format researched - `S(cvc#c#vc)` for config metadata, docs updated.
**S6** (2026-02-04): ⚡ Parsing refactored to `_fetchAllConfigsData()` + `_parseAllConfigsData()`:
  - Single request returns all configs (not per-index)
  - Format filter added: only parse `S(cvc#c#vc)` blocks, skip `S(ccvvvv)#` (scan sections)
  - Timeout increased 5s→10s
  - Index 4 still times out (firmware quirk?), index 6 works fine
  - **Blocker:** Sensör index 4 için hiç notification göndermiyor
  - 1 config görünüyor (Column 1, index 6), ikinci config (Hadamard, index 4) alınamıyor
  - Windows'ta çalışıyor demek ki farklı bir yöntem/endpoint var olabilir
