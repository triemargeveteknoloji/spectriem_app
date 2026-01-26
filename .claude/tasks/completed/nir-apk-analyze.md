# nir-apk-analyze

**Created:** 2026-01-26
**Status:** ✅ Completed

---

Sensorun kendi uygulama APK'sından nasıl eriştiğini çözmeliyiz. Çözdükten sonra uygun parçaları skill olarak bu projeye eklememiz gerekiyo.

## Summary

APK analizi tamamlandı. Detaylı BLE iletişim protokolü ve akışlar çıkarıldı.

**Key Findings:**

- 50+ GATT characteristic UUID mapping
- 9 kritik communication flow (connection, scan, calibration, etc.)
- Multi-packet protocol pattern
- Sequential operation requirement
- Native processing requirement (libdlpspectrum.so)

**Deliverables:**

1. **Research Document:** `.claude/research/nirscan-apk-analysis.md`
   - Complete UUID reference
   - Data format specifications
   - Architecture recommendations

2. **Skill Document:** `~/.claude/skills/nirscan-ble-flows/skill.md`
   - Step-by-step flow diagrams
   - Code patterns and anti-patterns
   - Implementation checklist
   - Testing strategies

## Tasks

- [x] APK'yı decompile et ve kaynak kodu analiz et
- [x] BLE iletişim protokolünü çıkar
- [x] GATT karakteristiklerine erişim yöntemini belirle
- [x] Uygun parçaları skill dosyasına dönüştür

## Next Steps

1. **Implement UUID Constants**
   - Create `lib/services/ble/nano_gatt.dart` with all UUIDs

2. **Implement Core Flows**
   - Connection & notification setup (12-step sequential)
   - Multi-packet receiver utility
   - Calibration caching

3. **Native Processing**
   - Decide: FFI vs. algorithm port vs. request TI docs
   - `libdlpspectrum.so` analysis if needed

4. **Integration**
   - Update `RealNirScanService` with flows
   - Add state management for scan progress
   - Error handling for status flags

## Sessions

**S1** (2026-01-26): APK analyzed. Extracted complete BLE protocol, created skill reference and research docs. Ready for implementation.
