# Bootstrap Plan

## Strategy
Flutter uygulamasını DLPNIRNANOEVM sensörü ile BLE üzerinden haberleşebilecek şekilde bootstrap etmek.

## Completed Steps

### 1. Sensör Araştırması ✅
- TI DLPNIRNANOEVM dokümantasyonu incelendi
- Android/iOS SDK'ları analiz edildi
- BLE GATT servisleri ve karakteristikleri belirlendi

### 2. Skill Oluşturma ✅
- `.claude/skills/dlpnirnanoevm-sensor.md` oluşturuldu
- GATT UUID'leri, komutlar, veri formatları dokümante edildi
- Bağlantı akışı ve multi-packet transfer detaylandırıldı

### 3. BLE Kütüphaneleri ✅
- `flutter_blue_plus: ^1.31.0` eklendi
- `permission_handler: ^11.0.0` eklendi
- Android manifest Bluetooth izinleri eklendi
- iOS Info.plist Bluetooth açıklamaları eklendi

### 4. Test Altyapısı ✅
- `mockito: ^5.4.0` eklendi
- `build_runner: ^2.4.0` eklendi
- `MockNirScanService` mock implementasyonu oluşturuldu
- Test dosyası oluşturuldu ve testler geçti

### 5. Proje Yapısı ✅
- `lib/services/ble/` dizini oluşturuldu
- `lib/models/` dizini oluşturuldu
- Temel model ve servis dosyaları oluşturuldu
- CLAUDE.md oluşturuldu

### 6. Serena Init ✅
- Proje aktifleştirildi
- Memory dosyaları oluşturuldu:
  - `project_overview.md`
  - `suggested_commands.md`
  - `code_style_conventions.md`
  - `task_completion_checklist.md`

## Oluşturulan Dosyalar

### Yeni Dosyalar
- `.claude/skills/dlpnirnanoevm-sensor.md` - Sensör skill'i
- `.claude/tasks/active/bootstrap/` - Task dökümanları
- `CLAUDE.md` - Proje konfigürasyonu
- `lib/services/ble/nano_gatt.dart` - GATT UUID sabitleri
- `lib/services/ble/nir_scan_service.dart` - Abstract interface
- `lib/services/ble/mock_nir_scan_service.dart` - Mock implementasyon
- `lib/models/device_info.dart`
- `lib/models/device_status.dart`
- `lib/models/scan_data.dart`
- `lib/models/scan_configuration.dart`
- `test/services/ble/mock_nir_scan_service_test.dart`

### Değiştirilen Dosyalar
- `pubspec.yaml` - BLE ve test bağımlılıkları
- `android/app/src/main/AndroidManifest.xml` - Bluetooth izinleri
- `ios/Runner/Info.plist` - Bluetooth açıklamaları

## Sonraki Adımlar (Gelecek Task'lar)

1. **RealNirScanService** implementasyonu
2. State management (Riverpod önerilir)
3. UI ekranları (cihaz keşfi, bağlantı, tarama)
4. Spektral veri görselleştirme
5. Veri kalıcılığı (local storage)
