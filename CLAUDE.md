# Spectriem App

NIR (Near-Infrared) spektroskopi uygulaması. Texas Instruments DLPNIRNANOEVM sensörü ile Bluetooth Low Energy üzerinden haberleşir.

## Proje Yapısı

```
lib/
├── main.dart
├── app.dart
├── services/
│   └── ble/
│       ├── nir_scan_service.dart      # Abstract interface
│       ├── real_nir_scan_service.dart # Gerçek BLE implementasyonu
│       ├── mock_nir_scan_service.dart # Test için mock
│       └── nano_gatt.dart             # GATT UUID sabitleri
├── models/
│   ├── device_info.dart
│   ├── device_status.dart
│   ├── scan_data.dart
│   └── scan_configuration.dart
├── providers/                         # State management
├── screens/                           # UI screens
└── widgets/                           # Reusable widgets

test/
├── unit/
├── widget/
├── integration/
└── mocks/
    └── mock_ble_service.dart
```

## Teknoloji Stack

- **Framework:** Flutter 3.x (Dart 3.x)
- **BLE:** flutter_blue_plus
- **State Management:** (TBD - riverpod önerilir)
- **Test:** flutter_test, mockito

## Sensör

Texas Instruments DLPNIRNANOEVM (DLP NIRscan Nano EVM)

- Bluetooth Low Energy 4.0
- 900-1700nm NIR spektroskopi
- GATT protokolü

Detaylı dokümantasyon: `.claude/skills/dlpnirnanoevm-sensor`

## Komutlar

```bash
# Bağımlılıkları yükle
flutter pub get

# Testleri çalıştır
flutter test

# Uygulamayı çalıştır
flutter run

# Build
flutter build apk --release
flutter build ios --release
```

## Geliştirme Notları

### Logging

Uygulama UI'da gerçek zamanlı log görüntüleme özelliği var. Service'ler ve BLE işlemleri için:

```dart
// ❌ YANLIŞ: print() kullanma
print('Debug message');

// ✅ DOĞRU: Logger provider kullan
// TODO: Logger implementation'ı dokümante edilecek
```

**Not:** Logging sistemi `lib/providers/` altında. BLE debug için kritik.

### BLE Testi

Gerçek sensör olmadan geliştirme için `MockNirScanService` kullanılır.

```dart
// Development/Test
final service = MockNirScanService();

// Production
final service = RealNirScanService();
```

### Platform İzinleri

- Android: Bluetooth, Location izinleri
- iOS: NSBluetoothAlwaysUsageDescription

## Kod Standartları

- Dart analysis: strict mode
- Test coverage hedefi: %80+
- TDD yaklaşımı tercih edilir
- Commit mesajları: Conventional Commits

## İlgili Skill'ler

- `/nirscan-ble-flows` - BLE iletişim akışları (APK'dan çıkarılmış)
- `/dlpnirnanoevm-sensor` - Sensör protokolü ve BLE iletişimi
