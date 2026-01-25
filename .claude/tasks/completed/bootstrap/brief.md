# bootstrap

**Created:** 2026-01-25
**Status:** ✅ Completed
**Priority:** P1

## Quick Note
NIR sensör (DLPNIRNANOEVM) ile Bluetooth üzerinden haberleşen Flutter uygulamasının bootstrap'ı. Sensör skill'i oluşturma, test ortamı hazırlama, BLE kütüphaneleri ekleme.

## Scope
1. DLPNIRNANOEVM sensör skill'i oluşturma (dokümantasyon, BLE protokolü, komutlar)
2. Mock/Simulator test ortamı kurulumu (sensör olmadan test)
3. Flutter BLE kütüphanesi ekleme (flutter_blue_plus)
4. CLAUDE.md proje konfigürasyonu
5. Serena MCP init
6. Dev dependencies ayarlama

## Initial Thoughts
- [x] Sensör hakkında detaylı araştırma yapıldı
- [x] BLE GATT karakteristikleri ve servisleri belirlendi
- [x] Android/iOS SDK'ları incelendi
- [ ] Skill dosyası oluşturulacak
- [ ] Mock BLE service oluşturulacak
- [ ] pubspec.yaml güncellenecek
- [ ] CLAUDE.md oluşturulacak

## Related Files
- `.claude/skills/dlpnirnanoevm-sensor.md` (oluşturulacak)
- `pubspec.yaml` (güncellenecek)
- `CLAUDE.md` (oluşturulacak)
- `lib/services/ble/` (oluşturulacak)
- `test/mocks/` (oluşturulacak)

## Key Findings

### DLPNIRNANOEVM Sensör
- Texas Instruments DLP NIRscan Nano EVM
- Portable NIR spektroskopi modülü
- DLP2010NIR DMD kullanıyor
- Tiva TM4C1297NCZAD mikrodenetleyici
- CC2564MODN Bluetooth Low Energy 4.0 modülü
- 900-1700nm dalga boyu aralığı (NIR)

### BLE İletişim
- Bluetooth Low Energy 4.0 (GATT/GAP)
- PIN gerektirmeyen bağlantı
- Birden fazla GATT servisi ve karakteristiği
- Multi-packet veri transferi (20 byte MTU limiti nedeniyle)

### GATT Servisleri
1. Device Information Service (DIS)
2. Battery Service (BAS)
3. General Information Service (GGIS)
4. Date/Time Service (GDTS)
5. Calibration Information Service (GCIS)
6. Scan Configuration Service (GSCIS)
7. Scan Data Information Service (GSDIS)

## Tags
- bootstrap
- ble
- nir-sensor
- flutter
- dlpnirnanoevm
