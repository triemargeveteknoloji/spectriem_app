# GATT Services ve Karakteristikler - UUID Referansı

> Kaynak: DLPU030G User's Guide, Appendix J (Table J-1 - J-9)

## Genel Bilgiler

- **Bluetooth Sürümü:** 4.0 Low Energy
- **MTU:** 20 byte (iOS tipik maksimum)
- **Multi-packet:** Büyük veriler için TableJ-9 formatı kullanılır
- **Byte Order:** Little-endian

### Özellik Kısaltmaları
| Kısaltma | Açıklama |
|----------|----------|
| R | Read |
| W | Write |
| N | Notify |
| I | Indicate |
| MP | Multiple Packets (bkz. Multi-Packet Yapısı) |

---

## 1. Device Information Service (DIS)
**Service UUID:** `0x180A` (Bluetooth SIG Standard)

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N |
|---------------------|----------|--------|-------|---|---|---|
| `0x2A29` | Manufacturer Name String | string | 1 | ✓ | | |
| `0x2A24` | Model Number String | string | 1 | ✓ | | |
| `0x2A25` | Serial Number String | string | 1 | ✓ | | |
| `0x2A27` | Hardware Revision String | string | 1 | ✓ | | |
| `0x2A26` | Tiva Firmware Revision | string | 1 | ✓ | | |
| `0x2A28` | Spectrum Library Revision | uint16 | 2 | ✓ | | |

---

## 2. Battery Service (BAS)
**Service UUID:** `0x180F` (Bluetooth SIG Standard)

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N |
|---------------------|----------|--------|-------|---|---|---|
| `0x2A19` | Battery Level | uint8 | 1 | ✓ | | |

**Not:** Değer 0-100 aralığında yüzde olarak raporlanır.

---

## 3. GATT General Information Service (GGIS)
**Service UUID:** `0x53455201-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N | Notlar |
|---------------------|----------|--------|-------|---|---|---|--------|
| `0x43484101-444C-5020-4E49-52204E616E6F` | Temperature Measurement | int16 | 2 | ✓ | | ✓ | Yüzde bölü 100 = °C |
| `0x43484102-444C-5020-4E49-52204E616E6F` | Humidity Measurement | uint16 | 2 | ✓ | | ✓ | Yüzde bölü 100 = % |
| `0x43484103-444C-5020-4E49-52204E616E6F` | Device Status | uint16 | 2 | ✓ | | ✓ | Rezerve |
| `0x43484104-444C-5020-4E49-52204E616E6F` | Error Status | uint16 | 2 | ✓ | | ✓ | Rezerve |
| `0x43484105-444C-5020-4E49-52204E616E6F` | Temperature Threshold | int16 | 2 | | ✓ | | Yüzde × 100 |
| `0x43484106-444C-5020-4E49-52204E616E6F` | Humidity Threshold | uint16 | 2 | | ✓ | | Yüzde × 100 |
| `0x43484107-444C-5020-4E49-52204E616E6F` | Hours of Use | uint16 | 2 | ✓ | | | Rezerve |
| `0x43484108-444C-5020-4E49-52204E616E6F` | Battery Recharge Cycles | uint16 | 2 | ✓ | | | Rezerve |
| `0x43484109-444C-5020-4E49-52204E616E6F` | Total Lamp Hours | uint16 | 2 | ✓ | | | Rezerve |
| `0x4348410A-444C-5020-4E49-52204E616E6F` | Error Log | string | 1 | ✓ | | | Rezerve |

---

## 4. GATT Date and Time Service (GDTS)
**Service UUID:** `0x53455203-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N |
|---------------------|----------|--------|-------|---|---|---|
| `0x4348410C-444C-5020-4E49-52204E616E6F` | Current Date/Time | struct | 7 | | ✓ | |

### Date/Time Yapısı (7 byte)
| Byte | Alan | Aralık |
|------|------|--------|
| 0 | Year | 0-99 (2000'den itibaren) |
| 1 | Month | 1-12 |
| 2 | Day | 1-31 |
| 3 | Day of Week | 0-6 |
| 4 | Hour | 0-23 |
| 5 | Minute | 0-59 |
| 6 | Second | 0-59 |

---

## 5. GATT Calibration Information Service (GCIS)
**Service UUID:** `0x53455204-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N | Notlar |
|---------------------|----------|--------|-------|---|---|---|--------|
| `0x4348410D-444C-5020-4E49-52204E616E6F` | Request Spectrum Cal Coefficients | uint8 | 1 | | ✓ | | Okuma niyeti bildir |
| `0x4348410E-444C-5020-4E49-52204E616E6F` | Return Spectrum Cal Coefficients | MP | var | | | ✓ | 6 × double (48 byte) |
| `0x4348410F-444C-5020-4E49-52204E616E6F` | Request Reference Cal Coefficients | uint8 | 1 | | ✓ | | Okuma niyeti bildir |
| `0x43484110-444C-5020-4E49-52204E616E6F` | Return Reference Cal Coefficients | MP | var | | | ✓ | Serialized data |
| `0x43484111-444C-5020-4E49-52204E616E6F` | Request Reference Cal Matrix | uint8 | 1 | | ✓ | | Okuma niyeti bildir |
| `0x43484112-444C-5020-4E49-52204E616E6F` | Return Reference Cal Matrix | MP | var | | | ✓ | Serialized data |

---

## 6. GATT Scan Configuration Service (GSCIS)
**Service UUID:** `0x53455205-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N | Notlar |
|---------------------|----------|--------|-------|---|---|---|--------|
| `0x43484113-444C-5020-4E49-52204E616E6F` | Number of Stored Configurations | uint16 | 2 | ✓ | | | |
| `0x43484114-444C-5020-4E49-52204E616E6F` | Request Stored Config List | uint8 | 1 | | ✓ | | Veri gönderilmez |
| `0x43484115-444C-5020-4E49-52204E616E6F` | Return Stored Config List | MP | var | | | ✓ | 2-byte index listesi |
| `0x43484116-444C-5020-4E49-52204E616E6F` | Request Scan Config Data | uint16 | 2 | | ✓ | | Okunacak index |
| `0x43484117-444C-5020-4E49-52204E616E6F` | Return Scan Config Data | MP | var | | | ✓ | Serialized data |
| `0x43484118-444C-5020-4E49-52204E616E6F` | Active Scan Configuration | uint16 | 2 | ✓ | ✓ | | Get/Set index |

---

## 7. GATT Scan Data Information Service (GSDIS)
**Service UUID:** `0x53455206-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N | Notlar |
|---------------------|----------|--------|-------|---|---|---|--------|
| `0x43484119-444C-5020-4E49-52204E616E6F` | Number of SD Card Stored Scans | uint32 | 4 | ✓ | | | |
| `0x4348411A-444C-5020-4E49-52204E616E6F` | Request SD Stored Scan Indices | uint32 | 4 | | ✓ | | Veri gönderilmez |
| `0x4348411B-444C-5020-4E49-52204E616E6F` | Return SD Stored Scan Indices | MP | var | | | ✓ | 5 × 4-byte index/paket |
| `0x4348411C-444C-5020-4E49-52204E616E6F` | Set Scan Name Stub | string | 2 | | ✓ | | Max 15 byte |
| `0x4348411D-444C-5020-4E49-52204E616E6F` | Start Scan | uint8 | 1 | | ✓ | ✓ | Bkz. Start Scan Notları |
| `0x4348411E-444C-5020-4E49-52204E616E6F` | Clear Scan | uint32 | 4 | | ✓ | ✓ | Silinecek scan index |
| `0x4348411F-444C-5020-4E49-52204E616E6F` | Request Scan Name | uint32 | 4 | | ✓ | | Okunacak scan index |
| `0x43484120-444C-5020-4E49-52204E616E6F` | Return Scan Name | string | 20 | | | ✓ | Max 20 karakter |
| `0x43484121-444C-5020-4E49-52204E616E6F` | Request Scan Type | uint32 | 4 | | ✓ | | Okunacak scan index |
| `0x43484122-444C-5020-4E49-52204E616E6F` | Return Scan Type | uint8 | 1 | | | ✓ | |
| `0x43484123-444C-5020-4E49-52204E616E6F` | Request Scan Date/Time | uint32 | 4 | | ✓ | | Okunacak scan index |
| `0x43484124-444C-5020-4E49-52204E616E6F` | Return Scan Date/Time | struct | 7 | | | ✓ | GDTS formatı |
| `0x43484125-444C-5020-4E49-52204E616E6F` | Request Packet Format Version | uint32 | 4 | | ✓ | | Okunacak scan index |
| `0x43484126-444C-5020-4E49-52204E616E6F` | Return Packet Format Version | uint32 | 4 | | | ✓ | |
| `0x43484127-444C-5020-4E49-52204E616E6F` | Request Serialized Scan Data | uint32 | 4 | | ✓ | | Okunacak scan index |
| `0x43484128-444C-5020-4E49-52204E616E6F` | Return Serialized Scan Data | MP | var | | | ✓ | dlpspec_scan_interpret() |

### Start Scan Parametreleri
**Write değeri:**
- `0x00` = SD karta kaydetme
- `0x01` = SD karta kaydet

**Notify dönüş değeri:**
- `0xFF` = Tarama tamamlandı
- 4-byte = Tamamlanan taramanın scan index'i

### Clear Scan Notify Dönüşü
- `0x00` = Başarılı
- Non-zero = Hata

---

## 8. GATT Command Service (GCS)
**Service UUID:** `0x53455202-444C-5020-4E49-52204E616E6F`

| Characteristic UUID | Açıklama | Format | Boyut | R | W | N | Notlar |
|---------------------|----------|--------|-------|---|---|---|--------|
| `0x4348410B-444C-5020-4E49-52204E616E6F` | Command Data Packet | struct | <20 | | ✓ | | Bkz. Komut Paketi |
| `0x4348410B-444C-5020-4E49-52204E616E6F` | Command Response | MP | var | | | ✓ | Yanıt |

### Komut Paketi Yapısı
| Byte | Alan | Açıklama |
|------|------|----------|
| 0 | Command Byte 0 | Komut kodu |
| 1 | Command Byte 1 | Grup kodu |
| 2 | Flag Byte | 3=Write, 5=Read |
| 3 | Length | Parametre uzunluğu |
| 4-19 | Parameters | Komut parametreleri |

---

## Multi-Packet Yapısı (Table J-9)

Büyük veriler için kullanılan paket formatı:

### İlk Paket (Index = 0)
| Byte | Alan | Açıklama |
|------|------|----------|
| 0 | Index | 0x00 |
| 1-2 | Size | Toplam veri boyutu (little-endian) |

### Sonraki Paketler (Index > 0)
| Byte | Alan | Açıklama |
|------|------|----------|
| 0 | Index | Paket numarası (1, 2, 3...) |
| 1 | ACK/NACK | Sadece ilk veri paketinde (varsa) |
| 2-19 | Data | Veri byte'ları |

### Dart Implementasyonu
```dart
class MultiPacketBuffer {
  int expectedSize = 0;
  final List<int> data = [];

  void processPacket(List<int> packet) {
    if (packet[0] == 0x00) {
      // İlk paket: boyut bilgisi
      expectedSize = (packet[2] << 8) | (packet[1] & 0xFF);
      data.clear();
    } else {
      // Veri paketi
      for (int i = 1; i < packet.length && data.length < expectedSize; i++) {
        data.add(packet[i]);
      }
    }
  }

  bool get isComplete => data.length >= expectedSize;
}
```

---

## CCCD (Client Characteristic Configuration Descriptor)

Notification'ları etkinleştirmek için kullanılan standart UUID:

```dart
const String CCCD_UUID = "00002902-0000-1000-8000-00805f9b34fb";

// Notification etkinleştirme
await characteristic.setNotifyValue(true);
// Bu otomatik olarak CCCD'ye 0x0100 yazar
```

---

## Service UUID Base Pattern

Custom service ve characteristic UUID'leri şu pattern'i takip eder:

```
Base: XXXXXXXX-444C-5020-4E49-52204E616E6F
      ^^^^^^^^
      Değişken kısım

"444C-5020-4E49-52204E616E6F" = "DL P NI R Nano" (ASCII)
```

### Service UUID'leri
| Service | UUID Prefix | Tam UUID |
|---------|-------------|----------|
| GGIS | 0x53455201 | 53455201-444C-5020-4E49-52204E616E6F |
| GCS | 0x53455202 | 53455202-444C-5020-4E49-52204E616E6F |
| GDTS | 0x53455203 | 53455203-444C-5020-4E49-52204E616E6F |
| GCIS | 0x53455204 | 53455204-444C-5020-4E49-52204E616E6F |
| GSCIS | 0x53455205 | 53455205-444C-5020-4E49-52204E616E6F |
| GSDIS | 0x53455206 | 53455206-444C-5020-4E49-52204E616E6F |

### Characteristic UUID Pattern
```
0x434841XX-444C-5020-4E49-52204E616E6F
          ^^
          Characteristic numarası (01, 02, 03...)

"43484" = "CHA" (ASCII) - Characteristic
```
