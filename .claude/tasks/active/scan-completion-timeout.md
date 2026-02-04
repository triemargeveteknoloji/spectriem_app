# scan-completion-timeout

**Created:** 2026-02-02
**Status:** 🚧 In Progress

---

## Problem

Scan trigger başarıyla gönderiliyor, sensör fiziksel olarak tarama yapıyor (sarı LED 3 saniye yanıyor), ancak uygulama scan completion notification (0xFF) almıyor ve timeout'a giriyor.

**Update (2026-02-04):** Notification artık geliyor! Ama iki yeni sorun ortaya çıktı:
1. ~~Stale data sorunu~~ ✅ FIXED
2. Lamp power failure (0x01) - donanım/config sorunu

---

## Approach

**Chosen:** Diagnostic Logging → Root Cause → Incremental Fix
**Why:** Notification'ın nerede kaybolduğunu belirleyip adım adım düzelttik.

---

## Decisions

- **D1:** `lastValueStream` yerine sadece `onValueReceived` kullan (stale data fix)
- **D2:** `writeComplete` flag ile pre-write notification'ları filtrele
- **D3:** İki scan'lı integration test ile stale data kontrolü
- **D4:** Lamp error ayrı task olarak ele alınacak (donanım/config sorunu)

---

## Constraints

- Sensör fiziksel olarak mevcut (gerçek device test edilebilir)
- TI sensörü GSDIS_START_SCAN'ı iki ayrı karakteristik olarak tanımlamış (Write + Notify)
- Lamp error config index veya donanım sorunuyla ilgili

---

## Related Files

| File | Purpose |
|------|---------|
| `lib/services/ble/ble_nir_scan_service.dart:515-600` | `performScan()` - stale data fix |
| `integration_test/steps/perform_scan_step.dart` | Dual-scan test |
| `integration_test/steps/calibration_step.dart` | Scan fail handling |
| `integration_test/integration_test.dart` | Timer conflict fix |

---

## Tasks

- [x] Diagnostic logging ekle
- [x] Root cause bul → TI sensörü aynı UUID'li 2 ayrı char tanımlamış
- [x] `_findNotifyCharacteristic` / `_findWriteCharacteristic` fix
- [x] Notification geliyor ✅
- [x] Config index fix (sequential değil, list'ten al)
- [x] **Stale data fix** (`lastValueStream` → `onValueReceived` + `writeComplete` flag)
- [x] Integration test'e ikinci scan ekle
- [x] Integration test pass ✅
- [ ] Lamp error root cause (ayrı task: config/donanım)

---

## Sessions

**S1-S11** (2026-02-02): Init → Diagnostic → Root cause bulundu
⚡ Key: TI sensörü GSDIS_START_SCAN'ı 2 ayrı karakteristik (Write + Notify) olarak tanımlamış
⚡ Key: flutter_blue_plus ilk bulunanı (Write) seçiyordu - CCCD'si yoktu
Fix: `_findNotifyCharacteristic()` / `_findWriteCharacteristic()` eklendi → Notification geldi!

**S12-S14** (2026-02-04): Config index sorunu
⚡ Key: Config index'leri sequential değil, list'ten alınmalı
Config listesi [4, 6] alınıyor ama yazma başarısız. Lamp error devam ediyor.

**S15** (2026-02-04): ⚡ **STALE DATA FIX TAMAMLANDI**

**Sorun:** İlk scan fail (0x01) olduğunda, ~1s sonra 0xFF geliyor. İkinci scan başladığında `lastValueStream` bu eski 0xFF'i okuyor ve "başarılı" sanıyor - aslında yeni tarama yapılmıyor!

**Fix:**
1. `lastValueStream` → `onValueReceived` (sadece fresh notifications)
2. `writeComplete` flag (write'dan önce gelen notification'ları ignore)

**Kanıt:**
```
SCAN 1: T+1723ms → 0x01 (Lamp failure)
SCAN 2: T+725ms  → 0x01 ← Fresh notification! (eski 0xFF'i okumadı)
```

**Değişiklikler:**
- `ble_nir_scan_service.dart` - stale data fix
- `perform_scan_step.dart` - dual-scan test
- `calibration_step.dart` - scan fail handling
- `integration_test.dart` - timer conflict fix

**Sonuç:** Integration test PASS ✅ Stale data fix doğrulandı.

**Remaining:** Lamp error (0x01) ayrı donanım/config sorunu - bu task'ın scope'u dışında.
