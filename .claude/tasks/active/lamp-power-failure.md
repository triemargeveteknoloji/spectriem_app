# lamp-power-failure

**Created:** 2026-02-04
**Status:** 🆕 Created

---

## Problem

Sensör scan trigger'ı kabul ediyor ve notification gönderiyor, ancak 0xFF (success) yerine 0x01 (Lamp power failure) döndürüyor.

**Kaynak:** `scan-completion-timeout` task'ından ayrıldı

**Gözlemler:**
- USB üzerinden Windows uygulamasıyla tarama başarılı
- Bluetooth üzerinden aynı sensörde "Lamp power failure" hatası
- Error status: 0x80 (TMP006 sensor warning - muhtemelen kalıcı)
- Device status: 0x31
- Config index 6 geçerli listede ([4, 6]) ama yazma başarısız

**Integration Test Evidence:**
```log
[SCAN] Pre-scan error status: 0x0080
[SCAN] Current active config: 0x0006 (index: 6)
[SCAN] Active config 6 is valid, using as-is
[SCAN] Notification at T+1723ms | Size: 5B | First: 0x01
[SCAN] FAILED | Error: 0x01 (Lamp power failure)
```

---

## Collected Notes

**TI SDK'dan bilgiler:**
- 0x01 = SCAN_LAMP_FAILURE
- Config parametreleri out-of-range olabilir
- Default factory config ile başlamak önerilir
- Config yazma: device busy, invalid index, wrong char olabilir

**Potansiyel Nedenler:**
1. Config parametreleri (exposure time, lamp settings) uyumsuz
2. Config yazma başarısız - sensör yanlış config kullanıyor
3. Batarya/güç sorunu (BT'de daha fazla güç tüketimi?)
4. Firmware quirk - BT bağlantısında farklı davranış

---

## Approach

(None) - Brainstorm gerekli

---

## Decisions

(None)

---

## Constraints

- USB'de çalışıyor, BT'de çalışmıyor
- Error status 0x80 kalıcı görünüyor (TMP006)
- Config yazma başarısız

---

## Related Files

- `lib/services/ble/ble_nir_scan_service.dart` - performScan, _ensureActiveScanConfig
- `.claude/skills/nirscan-android/` - TI SDK referans
- `.claude/skills/dlpnirnanoevm-sensor/` - Protokol referans

---

## Tasks

- [ ] Investigate: USB vs BT config difference
- [ ] Try default factory config (index 0 or first available)
- [ ] Analyze config write failure
- [ ] Test with different config parameters

---

## Sessions

(None yet)
