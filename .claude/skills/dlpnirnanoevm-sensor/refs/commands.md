# Komut Referansı

> Kaynak: DLPU030G User's Guide, Appendix G (Table G-1), Appendix H, I, J

## Genel Bilgiler

### Arayüz Önceliği
Birden fazla arayüz aktifse öncelik sırası:
1. **UART** (en yüksek)
2. **Bluetooth**
3. **USB** (en düşük)

### Komut Yapısı
Tüm komutlar iki byte'lık komut ID'si ile tanımlanır:
- **Command Byte (Byte 0):** Komut kodu
- **Group Byte (Byte 1):** Grup kodu

### Veri Formatı
- Tüm çok-byte değerler **little-endian**
- String'ler null-terminated değil, uzunluk belirtilir

---

## Sistem Komutları (Group 0x00)

| Komut ID | Command | Group | Açıklama | Input | Output |
|----------|---------|-------|----------|-------|--------|
| `NNO_CMD_FLASH_GET_CHKSUM` | 0x15 | 0x00 | DLPC150 firmware checksum | - | 4 byte |
| `NNO_CMD_FILE_WRITE_DATA` | 0x25 | 0x00 | Dosya verisi yaz | var | - |
| `NNO_CMD_FILE_SET_WRITESIZE` | 0x2A | 0x00 | Yazılacak dosya boyutu | 6 byte | - |
| `NNO_CMD_READ_FILE_LIST_SIZE` | 0x2B | 0x00 | Dosya listesi boyutu | 1 byte | 4 byte |
| `NNO_CMD_READ_FILE_LIST` | 0x2C | 0x00 | Dosya listesi oku | 1 byte | var |
| `NNO_CMD_FILE_GET_READSIZE` | 0x2D | 0x00 | Okunacak dosya boyutu | 1 byte | 4 byte |
| `NNO_CMD_FILE_GET_DATA` | 0x2E | 0x00 | Dosya verisi oku | - | var |
| `NNO_CMD_GOTO_TIVA_BL` | 0x2F | 0x00 | Tiva bootloader moduna geç | - | - |

### File Type Parametreleri
| Değer | Açıklama |
|-------|----------|
| `NNO_FILE_SCAN_DATA` | Tarama verisi |
| `NNO_FILE_SCAN_CONFIG` | Tarama konfigürasyonu |
| `NNO_FILE_REF_CAL_COEFF` | Referans kalibrasyon katsayıları |
| `NNO_FILE_REF_CAL_MATRIX` | Referans kalibrasyon matrisi |
| `NNO_FILE_SCAN_CONFIG_LIST` | Konfigürasyon listesi |
| `NNO_FILE_SCAN_LIST` | Tarama listesi |

---

## Test Komutları (Group 0x01)

| Komut ID | Command | Group | Açıklama | Input | Output | Sonuç |
|----------|---------|-------|----------|-------|--------|-------|
| `NNO_CMD_EEPROM_TEST` | 0x01 | 0x01 | EEPROM testi | - | 1 byte | 0=Pass |
| `NNO_CMD_ADC_TEST` | 0x02 | 0x01 | Detector board testi | - | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_BQ_TEST` | 0x03 | 0x01 | Battery charger testi | - | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_SDRAM_TEST` | 0x04 | 0x01 | SDRAM testi | - | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_DLPC_ENABLE` | 0x05 | 0x01 | DLP Controller güç kontrolü | 2 byte | - | - |
| `NNO_CMD_TMP_TEST` | 0x06 | 0x01 | Temperature sensor testi | - | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_HDC_TEST` | 0x07 | 0x01 | Humidity sensor testi | - | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_BT_TEST` | 0x08 | 0x01 | Bluetooth testi | 1 byte | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_SDC_TEST` | 0x09 | 0x01 | microSD Card testi | 1 byte | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_LED_TEST` | 0x0B | 0x01 | LED testi | 1 byte | 1 byte | 0=Pass, -1=Fail |
| `NNO_CMD_BUTTON_TEST_RD` | 0x0C | 0x01 | Button test oku | 1 byte | 1 byte | Button ID |
| `NNO_CMD_BUTTON_TEST_WR` | 0x0D | 0x01 | Button test yaz | 1 byte | 1 byte | - |
| `NNO_CMD_EEPROM_CAL_TEST` | 0x0E | 0x01 | EEPROM cal version yaz (FACTORY) | - | 1 byte | 0=Pass, 1=Fail |

### DLPC_ENABLE Parametreleri
| Byte | Değer | Açıklama |
|------|-------|----------|
| 0 | 0x00 | DLP Subsystem kapat |
| 0 | 0x01 | DLP Subsystem aç |
| 1 | 0x00 | Lamba kapat |
| 1 | 0x01 | Lamba aç |

---

## Tarama ve Konfigürasyon Komutları (Group 0x02)

| Komut ID | Command | Group | Açıklama | Input | Output |
|----------|---------|-------|----------|-------|--------|
| `NNO_CMD_TIVA_VER` | 0x16 | 0x02 | Tiva versiyon bilgisi | - | 28 byte |
| `NNO_CMD_STORE_PTN_SDRAM` | 0x17 | 0x02 | Pattern'leri SDRAM'e yaz | 12 byte | - |
| `NNO_CMD_PERFORM_SCAN` | 0x18 | 0x02 | Tarama başlat | 1 byte | - |
| `NNO_CMD_SCAN_GET_STATUS` | 0x19 | 0x02 | Tarama durumu | - | 1 byte |
| `NNO_CMD_TIVA_RESET` | 0x1A | 0x02 | Tiva reset | - | - |
| `NNO_CMD_SET_PGA` | 0x1B | 0x02 | ADC PGA gain ayarla | 1 byte | - |
| `NNO_CMD_SET_DLPC_REG` | 0x1C | 0x02 | DLPC150 register yaz (FACTORY) | 8 byte | - |
| `NNO_CMD_GET_DLPC_REG` | 0x1D | 0x02 | DLPC150 register oku | 4 byte | 4 byte |
| `NNO_CMD_SCAN_CFG_APPLY` | 0x1E | 0x02 | Konfigürasyon uygula | var | 4 byte |
| `NNO_CMD_SCAN_CFG_SAVE` | 0x1F | 0x02 | Konfigürasyon kaydet | var | - |
| `NNO_CMD_SCAN_CFG_READ` | 0x20 | 0x02 | Konfigürasyon oku | 2 byte | 124 byte |
| `NNO_CMD_SCAN_CFG_ERASEALL` | 0x21 | 0x02 | Tüm konfigürasyonları sil | - | - |
| `NNO_CMD_SCAN_CFG_NUM` | 0x22 | 0x02 | Konfigürasyon sayısı | - | 1 byte |
| `NNO_CMD_SCAN_GET_ACT_CFG` | 0x23 | 0x02 | Aktif konfigürasyon index | - | 1 byte |
| `NNO_CMD_SCAN_SET_ACT_CFG` | 0x24 | 0x02 | Aktif konfigürasyon ayarla | 1 byte | - |
| `NNO_CMD_SET_DLPC_ONOFF_CTRL` | 0x25 | 0x02 | DLPC on/off kontrolü | 1 byte | - |
| `NNO_CMD_SET_SCAN_SUBIMAGE` | 0x26 | 0x02 | Scan subimage ayarla | 4 byte | - |
| `NNO_CMD_EEPROM_WIPE` | 0x27 | 0x02 | EEPROM sil (FACTORY) | 3 byte | - |
| `NNO_CMD_GET_PGA` | 0x28 | 0x02 | PGA ayarı oku | - | 1 byte |
| `NNO_CMD_CALIB_STRUCT_SAVE` | 0x29 | 0x02 | Kalibrasyon kaydet (FACTORY) | 144 byte | - |
| `NNO_CMD_CALIB_STRUCT_READ` | 0x2A | 0x02 | Kalibrasyon oku | - | 144 byte |
| `NNO_CMD_START_SNRSCAN` | 0x2B | 0x02 | SNR tarama başlat | - | - |
| `NNO_CMD_SAVE_SNRDATA` | 0x2C | 0x02 | SNR verisi kaydet | - | 20 byte |
| `NNO_CMD_CALIB_GEN_PTNS` | 0x2D | 0x02 | Kalibrasyon pattern oluştur | 1 byte | 4 byte |
| `NNO_CMD_SCAN_NUM_REPEATS` | 0x2E | 0x02 | Tarama tekrar sayısı | 2 byte | - |
| `NNO_CMD_START_HADSNRSCAN` | 0x2F | 0x02 | Hadamard SNR tarama | - | - |
| `NNO_CMD_REFCAL_PERFORM` | 0x30 | 0x02 | Referans kalibrasyon (FACTORY) | - | - |
| `NNO_CMD_SERIAL_NUMBER_WRITE` | 0x32 | 0x02 | Seri numarası yaz (FACTORY) | 8 byte | - |
| `NNO_CMD_SERIAL_NUMBER_READ` | 0x33 | 0x02 | Seri numarası oku | - | 8 byte |
| `NNO_CMD_WRITE_SCAN_NAME_TAG` | 0x34 | 0x02 | Tarama adı prefix'i | var | - |
| `NNO_CMD_DEL_SCAN_FILE_SD` | 0x35 | 0x02 | SD'den tarama sil | 4 byte | - |
| `NNO_CMD_EEPROM_MASS_ERASE` | 0x36 | 0x02 | EEPROM toplu sil (FACTORY) | - | - |
| `NNO_CMD_READ_SCAN_TIME` | 0x37 | 0x02 | Tarama süresi oku | - | 4 byte |
| `NNO_CMD_DEL_LAST_SCAN_FILE_SD` | 0x38 | 0x02 | Son taramayı sil | - | - |
| `NNO_CMD_START_SCAN_INTERPRET` | 0x39 | 0x02 | Tarama yorumlama başlat | - | - |
| `NNO_CMD_SCAN_INTERPRET_GET_STATUS` | 0x3A | 0x02 | Yorumlama durumu | - | 1 byte |
| `NNO_CMD_MODEL_NAME_WRITE` | 0x3B | 0x02 | Model adı yaz | 16 byte | - |
| `NNO_CMD_MODEL_NAME_READ` | 0x3C | 0x02 | Model adı oku | - | 16 byte |

### PGA Değerleri
| Değer | Gain |
|-------|------|
| 0 | 1X |
| 1 | 2X |
| 2 | 4X |
| 3 | 8X |
| 4 | 16X |
| 5 | 32X |
| 6 | 64X |

### Scan Type (CALIB_GEN_PTNS)
| Değer | Tip |
|-------|-----|
| 0 | COLUMN_TYPE |
| 1 | HADAMARD_TYPE |
| 2 | SLEW_TYPE |

### PERFORM_SCAN Parametresi
| Değer | Açıklama |
|-------|----------|
| 0x00 | SD karta kaydetme |
| 0x01 | SD karta kaydet |

### SCAN_GET_STATUS Dönüş Değeri
| Değer | Açıklama |
|-------|----------|
| 0 | Tarama devam ediyor |
| 1 | Tarama tamamlandı |

### TIVA_VER Çıktı Yapısı (28 byte)
| Offset | Boyut | Alan |
|--------|-------|------|
| 0 | 4 | Tiva SW Version |
| 4 | 4 | DLPC SW Version |
| 8 | 4 | DLPC Flash Version |
| 12 | 4 | DLP Spectrum Library Version |
| 16 | 4 | EEPROM Calibration Version |
| 20 | 4 | EEPROM Reference Version |
| 24 | 4 | EEPROM Scan Configuration Version |

---

## Sensör Komutları (Group 0x03)

| Komut ID | Command | Group | Açıklama | Input | Output |
|----------|---------|-------|----------|-------|--------|
| `NNO_CMD_READ_TEMP` | 0x00 | 0x03 | Sıcaklık oku | - | 8 byte |
| `NNO_CMD_READ_HUM` | 0x02 | 0x03 | Nem oku | - | 8 byte |
| `NNO_CMD_SET_DATE_TIME` | 0x09 | 0x03 | Tarih/saat ayarla | 7 byte | - |
| `NNO_CMD_READ_BATT_VOLT` | 0x0A | 0x03 | Batarya voltajı oku | - | 4 byte |
| `NNO_CMD_READ_TIVA_TEMP` | 0x0B | 0x03 | Tiva iç sıcaklık | - | 4 byte |
| `NNO_CMD_GET_DATE_TIME` | 0x0C | 0x03 | Tarih/saat oku | - | 7 byte |
| `NNO_CMD_HIBERNATE_MODE` | 0x0D | 0x03 | Hibernate moduna geç | - | - |
| `NNO_CMD_SET_HIBERNATE` | 0x0E | 0x03 | Hibernate flag ayarla | 1 byte | - |
| `NNO_CMD_GET_HIBERNATE` | 0x0F | 0x03 | Hibernate flag oku | - | 1 byte |

### READ_TEMP Çıktı Yapısı (8 byte)
| Offset | Boyut | Alan | Birim |
|--------|-------|------|-------|
| 0 | 4 | Ambient Temperature | °C × 100 (int32) |
| 4 | 4 | Detector Temperature | °C × 100 (int32) |

### READ_HUM Çıktı Yapısı (8 byte)
| Offset | Boyut | Alan | Birim |
|--------|-------|------|-------|
| 0 | 4 | HDC Temperature | °C × 100 (int32) |
| 4 | 4 | HDC Humidity | % × 100 (int32) |

### SET/GET_DATE_TIME Yapısı (7 byte)
| Byte | Alan | Aralık |
|------|------|--------|
| 0 | Year | 0-99 |
| 1 | Month | 0-11 |
| 2 | Date | 1-31 |
| 3 | Day of Week | 0-6 |
| 4 | Hour | 0-23 |
| 5 | Minute | 0-59 |
| 6 | Second | 0-59 |

---

## Durum Komutları (Group 0x04)

| Komut ID | Command | Group | Açıklama | Input | Output |
|----------|---------|-------|----------|-------|--------|
| `NNO_CMD_GET_NUM_SCAN_FILES_SD` | 0x00 | 0x04 | SD'deki tarama sayısı | - | 4 byte |
| `NNO_CMD_READ_PHOTODETECTOR` | 0x02 | 0x04 | Fotodetektör oku | - | 12 byte |
| `NNO_CMD_READ_DEVICE_STATUS` | 0x03 | 0x04 | Cihaz durumu | - | 4 byte |
| `NNO_CMD_READ_ERROR_STATUS` | 0x04 | 0x04 | Hata durumu | - | 20 byte |
| `NNO_CMD_RESET_ERROR_STATUS` | 0x05 | 0x04 | Hata durumu sıfırla | - | - |
| `NNO_CMD_GET_SPECIFIC_ERR_STATUS` | 0x06 | 0x04 | Spesifik hata durumu | 4 byte | - |
| `NNO_CMD_GET_SPECIFIC_ERR_CODE` | 0x07 | 0x04 | Spesifik hata kodu | 2 byte | - |
| `NNO_CMD_CLEAR_SPECIFIC_ERR` | 0x08 | 0x04 | Spesifik hata temizle | 4 byte | - |
| `NNO_CMD_UPDATE_REFCALDATA_WOREFL` | 0x0A | 0x04 | Referans güncelle | - | - |
| `NNO_CMD_ERASE_DLPC_FLASH` | 0x0B | 0x04 | DLPC150 flash sil | - | - |

### READ_DEVICE_STATUS Bit Maskeleri
| Bit | Maske | Açıklama |
|-----|-------|----------|
| 0 | 0x01 | Tiva Active |
| 1 | 0x02 | Scan In Progress |
| 2 | 0x04 | SD Card Present |
| 3 | 0x08 | SD Card I/O In Progress |
| 4 | 0x10 | Bluetooth Active |
| 5 | 0x20 | Bluetooth Connected |
| 6 | 0x40 | Scan Interpretation In Progress |

### READ_ERROR_STATUS Yapısı (20 byte)
| Offset | Boyut | Alan |
|--------|-------|------|
| 0 | 4 | Error Status Flags |
| 4 | 1 | Scan Error Description |
| 5 | 1 | ADC Error Description |
| 6 | 1 | SD Card Error Description |
| 7 | 1 | EEPROM Error Description |
| 8 | 2 | Bluetooth Error Description |
| 10 | 1 | Spectrum Library Error Description |
| 11 | 1 | Hardware Error Description |
| 12 | 1 | TMP006 Error Description |
| 13 | 1 | HDC Error Description |
| 14 | 1 | Battery Error Description |
| 15 | 1 | Memory Error Description |
| 16 | 1 | UART Error Description |

### Error Status Flags (Bit Maskeleri)
| Bit | Maske | Açıklama |
|-----|-------|----------|
| 0 | 0x001 | Scan Error |
| 1 | 0x002 | ADC Error |
| 2 | 0x004 | SD Card Error |
| 3 | 0x008 | EEPROM Error |
| 4 | 0x010 | Bluetooth Error |
| 5 | 0x020 | Spectrum Library Error |
| 6 | 0x040 | Hardware Error |
| 7 | 0x080 | TMP006 Error |
| 8 | 0x100 | HDC1000 Error |
| 9 | 0x200 | Battery Discharged |
| 10 | 0x400 | Memory Error |
| 11 | 0x800 | UART Error |

### READ_PHOTODETECTOR Çıktı Yapısı (12 byte)
| Offset | Boyut | Alan |
|--------|-------|------|
| 0 | 4 | DLPA2005 Red Photodetector |
| 4 | 4 | DLPA2005 Green Photodetector |
| 8 | 4 | DLPA2005 Blue Photodetector |

---

## Bluetooth GATT Service Mapping

Bazı komutlar doğrudan GATT servisleri üzerinden de erişilebilir:

| Komut | GATT Service | Characteristic |
|-------|--------------|----------------|
| `NNO_CMD_TIVA_VER` | DIS | Multiple chars |
| `NNO_CMD_READ_TEMP` | GGIS | 0x43484101 |
| `NNO_CMD_READ_HUM` | GGIS | 0x43484102 |
| `NNO_CMD_READ_BATT_VOLT` | BAS | 0x2A19 |
| `NNO_CMD_SET_DATE_TIME` | GDTS | 0x4348410C |
| `NNO_CMD_SCAN_CFG_NUM` | GSCIS | 0x43484113 |
| `NNO_CMD_SCAN_GET_ACT_CFG` | GSCIS | 0x43484118 |
| `NNO_CMD_SCAN_SET_ACT_CFG` | GSCIS | 0x43484118 |
| `NNO_CMD_PERFORM_SCAN` | GSDIS | 0x4348411D |
| `NNO_CMD_GET_NUM_SCAN_FILES_SD` | GSDIS | 0x43484119 |
| `NNO_CMD_TIVA_RESET` | GCS | 0x4348410B |
| `NNO_CMD_SET_PGA` | GCS | 0x4348410B |
| `NNO_CMD_GET_PGA` | GCS | 0x4348410B |
| `NNO_CMD_HIBERNATE_MODE` | GCS | 0x4348410B |

---

## Örnek Dart Implementasyonu

```dart
class NanoCommand {
  final int commandByte;
  final int groupByte;
  final List<int> data;

  NanoCommand(this.commandByte, this.groupByte, [this.data = const []]);

  // GCS üzerinden komut gönderme
  List<int> toGcsPacket({bool isRead = false}) {
    return [
      commandByte,
      groupByte,
      isRead ? 0x05 : 0x03, // Flag: 5=Read, 3=Write
      data.length,
      ...data,
    ];
  }
}

// Örnek kullanım
final performScan = NanoCommand(0x18, 0x02, [0x01]); // Save to SD
final readTemp = NanoCommand(0x00, 0x03);
final setPga = NanoCommand(0x1B, 0x02, [0x06]); // PGA 64X
```
