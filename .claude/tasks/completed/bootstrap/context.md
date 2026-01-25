# Bootstrap Context

## Codebase Analysis

### Proje Tipi
Flutter mobil uygulama - Android ve iOS destekli

### Temel Mimari
- **Services Layer:** BLE iletişimi için abstract interface + concrete implementations pattern
- **Models:** Immutable data classes with equality support
- **Testing:** Mock services ile hardware-independent testing

### Kritik Dosyalar
| Dosya | Açıklama |
|-------|----------|
| `lib/services/ble/nir_scan_service.dart` | Ana interface tanımı |
| `lib/services/ble/nano_gatt.dart` | Tüm BLE UUID'leri |
| `.claude/skills/dlpnirnanoevm-sensor.md` | Sensör protokol dokümantasyonu |

### Bağımlılıklar
- `flutter_blue_plus: ^1.31.0` - BLE communication
- `permission_handler: ^11.0.0` - Runtime permissions

## Session Notes

### 2026-01-25
- Task başlatıldı
- TI dokümantasyonu ve GitHub SDK'ları incelendi
- Skill dosyası oluşturuldu (kapsamlı GATT ve protokol bilgisi)
- Proje bootstrap edildi
- Tüm testler geçti
- Serena init tamamlandı
