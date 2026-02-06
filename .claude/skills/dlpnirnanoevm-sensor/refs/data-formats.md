# Veri Formatları

> Kaynak: DLPU030G User's Guide, Section 5.1.7, 5.1.8, Appendix J

## Genel İlkeler

- **Byte Order:** Little-endian (LSB first)
- **String Format:** Null-terminated değil, uzunluk bilgisi ayrı
- **Multi-packet:** 20 byte MTU sınırı nedeniyle büyük veriler parçalanır
- **Serialization:** DLP Spectrum Library struct formatları

---

## 1. Temel Veri Tipleri

### Sıcaklık (Temperature)

```dart
/// Sıcaklık verisi: 16-bit signed integer, yüzdede
/// Değer / 100 = °C
double parseTemperature(List<int> data) {
  final raw = ByteData.sublistView(Uint8List.fromList(data))
      .getInt16(0, Endian.little);
  return raw / 100.0;
}

List<int> encodeTemperature(double celsius) {
  final raw = (celsius * 100).round();
  final bytes = ByteData(2)..setInt16(0, raw, Endian.little);
  return bytes.buffer.asUint8List().toList();
}
```

**Örnek:**
- `[0x0A, 0x0A]` = 2570 / 100 = 25.70°C
- `[0xF6, 0xFF]` = -10 / 100 = -0.10°C

### Nem (Humidity)

```dart
/// Nem verisi: 16-bit unsigned integer, yüzdede
/// Değer / 100 = %
double parseHumidity(List<int> data) {
  final raw = ByteData.sublistView(Uint8List.fromList(data))
      .getUint16(0, Endian.little);
  return raw / 100.0;
}
```

**Örnek:**
- `[0x88, 0x13]` = 5000 / 100 = 50.00%

### Batarya Seviyesi

```dart
/// Batarya: 8-bit unsigned, 0-100 yüzde
/// BAS servisi üzerinden
int parseBatteryLevel(List<int> data) {
  return data[0]; // 0-100
}
```

**Raporlanan değerler:** 0%, 5%, 20%, 40%, 60%, 80%, 100%

### Batarya Voltajı

```dart
/// Batarya voltajı: 32-bit integer, yüzdede volt
/// NNO_CMD_READ_BATT_VOLT ile
double parseBatteryVoltage(List<int> data) {
  final raw = ByteData.sublistView(Uint8List.fromList(data))
      .getInt32(0, Endian.little);
  return raw / 100.0; // Volt
}
```

---

## 2. Tarih/Saat Formatı

### GDTS Yapısı (7 byte)

```dart
class NanoDateTime {
  final int year;    // 0-99 (2000'den itibaren)
  final int month;   // 1-12
  final int day;     // 1-31
  final int weekday; // 0-6 (0=Pazar)
  final int hour;    // 0-23
  final int minute;  // 0-59
  final int second;  // 0-59

  NanoDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.second,
  });

  factory NanoDateTime.fromBytes(List<int> data) {
    return NanoDateTime(
      year: data[0],
      month: data[1],
      day: data[2],
      weekday: data[3],
      hour: data[4],
      minute: data[5],
      second: data[6],
    );
  }

  factory NanoDateTime.fromDateTime(DateTime dt) {
    return NanoDateTime(
      year: dt.year - 2000,
      month: dt.month,
      day: dt.day,
      weekday: dt.weekday % 7, // DateTime: 1-7, Nano: 0-6
      hour: dt.hour,
      minute: dt.minute,
      second: dt.second,
    );
  }

  List<int> toBytes() => [year, month, day, weekday, hour, minute, second];

  DateTime toDateTime() {
    return DateTime(2000 + year, month, day, hour, minute, second);
  }
}
```

**Not:** `NNO_CMD_SET_DATE_TIME` için month 0-11, GDTS için 1-12 olabilir. Dokümantasyonda tutarsızlık var, test edilmeli.

---

## 3. Scan Index Formatı

Tarama indexleri 4-byte unsigned integer olarak saklanır.

```dart
class ScanIndex {
  final int value;

  ScanIndex(this.value);

  factory ScanIndex.fromBytes(List<int> bytes) {
    return ScanIndex(
      ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint32(0, Endian.little),
    );
  }

  List<int> toBytes() {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List().toList();
  }

  @override
  String toString() => 'ScanIndex($value)';
}
```

---

## 4. Multi-Packet Yapısı

20 byte MTU sınırı nedeniyle büyük veriler parçalara ayrılır.

### Paket Yapısı

**İlk Paket (Header):**
| Byte | Alan | Açıklama |
|------|------|----------|
| 0 | Index | 0x00 (header indicator) |
| 1 | Size LSB | Toplam boyut (düşük byte) |
| 2 | Size MSB | Toplam boyut (yüksek byte) |

**Veri Paketleri:**
| Byte | Alan | Açıklama |
|------|------|----------|
| 0 | Index | Paket numarası (1, 2, 3...) |
| 1-19 | Data | Veri byte'ları |

### Dart Implementasyonu

```dart
class MultiPacketBuffer {
  int _expectedSize = 0;
  final List<int> _buffer = [];
  bool _headerReceived = false;

  void processPacket(List<int> packet) {
    if (packet.isEmpty) return;

    final packetIndex = packet[0];

    if (packetIndex == 0x00) {
      // Header paketi
      _expectedSize = (packet[2] << 8) | (packet[1] & 0xFF);
      _buffer.clear();
      _headerReceived = true;
    } else if (_headerReceived) {
      // Veri paketi
      for (int i = 1; i < packet.length && _buffer.length < _expectedSize; i++) {
        _buffer.add(packet[i]);
      }
    }
  }

  bool get isComplete => _headerReceived && _buffer.length >= _expectedSize;

  List<int> get data => List.unmodifiable(_buffer);

  double get progress {
    if (!_headerReceived || _expectedSize == 0) return 0.0;
    return _buffer.length / _expectedSize;
  }

  void reset() {
    _expectedSize = 0;
    _buffer.clear();
    _headerReceived = false;
  }
}
```

### Stream-Based Handler

```dart
class MultiPacketStreamHandler {
  final StreamController<List<int>> _controller = StreamController();
  final MultiPacketBuffer _buffer = MultiPacketBuffer();

  Stream<List<int>> get onComplete => _controller.stream;

  void onNotification(List<int> data) {
    _buffer.processPacket(data);

    if (_buffer.isComplete) {
      _controller.add(_buffer.data);
      _buffer.reset();
    }
  }

  void dispose() {
    _controller.close();
  }
}
```

---

## 5. Device Status Formatı

### NNO_CMD_READ_DEVICE_STATUS (4 byte)

```dart
class DeviceStatus {
  final bool tivaActive;
  final bool scanInProgress;
  final bool sdCardPresent;
  final bool sdCardIO;
  final bool bluetoothActive;
  final bool bluetoothConnected;
  final bool scanInterpretInProgress;

  DeviceStatus._({
    required this.tivaActive,
    required this.scanInProgress,
    required this.sdCardPresent,
    required this.sdCardIO,
    required this.bluetoothActive,
    required this.bluetoothConnected,
    required this.scanInterpretInProgress,
  });

  factory DeviceStatus.fromBytes(List<int> data) {
    final flags = ByteData.sublistView(Uint8List.fromList(data))
        .getUint32(0, Endian.little);

    return DeviceStatus._(
      tivaActive: (flags & 0x01) != 0,
      scanInProgress: (flags & 0x02) != 0,
      sdCardPresent: (flags & 0x04) != 0,
      sdCardIO: (flags & 0x08) != 0,
      bluetoothActive: (flags & 0x10) != 0,
      bluetoothConnected: (flags & 0x20) != 0,
      scanInterpretInProgress: (flags & 0x40) != 0,
    );
  }
}
```

---

## 6. Error Status Formatı

### NNO_CMD_READ_ERROR_STATUS (20 byte)

```dart
class ErrorStatus {
  final int flags;
  final int scanError;
  final int adcError;
  final int sdCardError;
  final int eepromError;
  final int bluetoothError;
  final int spectrumLibError;
  final int hardwareError;
  final int tmp006Error;
  final int hdcError;
  final int batteryError;
  final int memoryError;
  final int uartError;

  ErrorStatus._({
    required this.flags,
    required this.scanError,
    required this.adcError,
    required this.sdCardError,
    required this.eepromError,
    required this.bluetoothError,
    required this.spectrumLibError,
    required this.hardwareError,
    required this.tmp006Error,
    required this.hdcError,
    required this.batteryError,
    required this.memoryError,
    required this.uartError,
  });

  factory ErrorStatus.fromBytes(List<int> data) {
    final bd = ByteData.sublistView(Uint8List.fromList(data));

    return ErrorStatus._(
      flags: bd.getUint32(0, Endian.little),
      scanError: data[4],
      adcError: data[5],
      sdCardError: data[6],
      eepromError: data[7],
      bluetoothError: bd.getUint16(8, Endian.little),
      spectrumLibError: data[10],
      hardwareError: data[11],
      tmp006Error: data[12],
      hdcError: data[13],
      batteryError: data[14],
      memoryError: data[15],
      uartError: data[16],
    );
  }

  bool get hasScanError => (flags & 0x001) != 0;
  bool get hasAdcError => (flags & 0x002) != 0;
  bool get hasSdCardError => (flags & 0x004) != 0;
  bool get hasEepromError => (flags & 0x008) != 0;
  bool get hasBluetoothError => (flags & 0x010) != 0;
  bool get hasSpectrumLibError => (flags & 0x020) != 0;
  bool get hasHardwareError => (flags & 0x040) != 0;
  bool get hasTmp006Error => (flags & 0x080) != 0;
  bool get hasHdcError => (flags & 0x100) != 0;
  bool get hasBatteryError => (flags & 0x200) != 0;
  bool get hasMemoryError => (flags & 0x400) != 0;
  bool get hasUartError => (flags & 0x800) != 0;

  bool get hasAnyError => flags != 0;
}
```

---

## 7. Tiva Version Formatı

### NNO_CMD_TIVA_VER Çıktısı (28 byte)

```dart
class TivaVersion {
  final int tivaSwVersion;
  final int dlpcSwVersion;
  final int dlpcFlashVersion;
  final int spectrumLibVersion;
  final int eepromCalVersion;
  final int eepromRefVersion;
  final int eepromScanConfigVersion;

  TivaVersion._({
    required this.tivaSwVersion,
    required this.dlpcSwVersion,
    required this.dlpcFlashVersion,
    required this.spectrumLibVersion,
    required this.eepromCalVersion,
    required this.eepromRefVersion,
    required this.eepromScanConfigVersion,
  });

  factory TivaVersion.fromBytes(List<int> data) {
    final bd = ByteData.sublistView(Uint8List.fromList(data));

    return TivaVersion._(
      tivaSwVersion: bd.getUint32(0, Endian.little),
      dlpcSwVersion: bd.getUint32(4, Endian.little),
      dlpcFlashVersion: bd.getUint32(8, Endian.little),
      spectrumLibVersion: bd.getUint32(12, Endian.little),
      eepromCalVersion: bd.getUint32(16, Endian.little),
      eepromRefVersion: bd.getUint32(20, Endian.little),
      eepromScanConfigVersion: bd.getUint32(24, Endian.little),
    );
  }

  String get tivaSwVersionString => _versionToString(tivaSwVersion);
  String get dlpcSwVersionString => _versionToString(dlpcSwVersion);

  static String _versionToString(int version) {
    final major = (version >> 16) & 0xFF;
    final minor = (version >> 8) & 0xFF;
    final patch = version & 0xFF;
    return '$major.$minor.$patch';
  }
}
```

---

## 8. Photodetector Formatı

### NNO_CMD_READ_PHOTODETECTOR (12 byte)

```dart
class PhotodetectorReading {
  final int red;
  final int green;
  final int blue;

  PhotodetectorReading._({
    required this.red,
    required this.green,
    required this.blue,
  });

  factory PhotodetectorReading.fromBytes(List<int> data) {
    final bd = ByteData.sublistView(Uint8List.fromList(data));

    return PhotodetectorReading._(
      red: bd.getUint32(0, Endian.little),
      green: bd.getUint32(4, Endian.little),
      blue: bd.getUint32(8, Endian.little),
    );
  }
}
```

---

## 9. Scan Configuration Formatı

Scan configuration, TI'nin **tpl** (Troy's Packing Library) kullanarak serialize edilir.

> **Kaynaklar:**
> - [tpl GitHub](https://github.com/troydhanson/tpl)
> - [tpl User Guide](https://troydhanson.github.io/tpl/userguide.html)
> - [TI E2E Forum](https://e2e.ti.com/support/dlp-products-group/dlp/f/dlp-products-forum/846128)

### TPL (Troy's Packing Library)

tpl, C struct'larını binary formata serialize eden hafif bir kütüphanedir. Format string'leri kullanır:

| Karakter | Tip | Boyut | Açıklama |
|----------|-----|-------|----------|
| `c` | char | 1 byte | Karakter/byte |
| `v` | uint16_t | 2 bytes | 16-bit unsigned (LE) |
| `i` | int32_t | 4 bytes | 32-bit signed (LE) |
| `u` | uint32_t | 4 bytes | 32-bit unsigned (LE) |
| `s` | string | variable | Null-terminated string |
| `c#` | char[] | variable | Fixed-length char array (length prefix follows) |
| `S(...)` | struct | variable | Struct wrapper |
| `A(...)` | array | variable | Variable-length array |

### TPL Image Yapısı

```
┌─────────────────────────────────────────────────────────┐
│ TPL Header                                               │
├──────────────┬──────────────┬───────────────────────────┤
│ Magic (4B)   │ Size (4B)    │ Format String (null-term) │
│ "tpl\0"      │ LE uint32    │ e.g. "S(cvc#c#vc)\0"      │
├──────────────┴──────────────┴───────────────────────────┤
│ Length Prefixes (for c# arrays)                          │
│ 4 bytes each, LE uint32                                  │
├─────────────────────────────────────────────────────────┤
│ Struct Data                                              │
│ Fields in format string order                            │
└─────────────────────────────────────────────────────────┘
```

### Scan Config TPL Format: `S(cvc#c#vc)`

GSCIS_RET_SCAN_CONF_DATA karakteristiğinden dönen veri:

```
Offset  Size  Field              Açıklama
──────────────────────────────────────────────────────────
TPL HEADER
0-3     4     magic              "tpl\0"
4-7     4     size               Toplam TPL block boyutu (LE)
8-19    12    format             "S(cvc#c#vc)\0"

LENGTH PREFIXES
20-23   4     serial_len         Serial number uzunluğu (8)
24-27   4     name_len           Config name uzunluğu (40)

STRUCT DATA
28      1     scan_type          0=Column, 1=Hadamard
29-30   2     config_index       Config index (LE uint16)
31-38   8     serial_number      Cihaz seri numarası
39-78   40    config_name        Config adı (null-padded)
79+     var   section_data       Section parametreleri
```

### Örnek Raw Data

```
74 70 6c 00  -- "tpl\0" magic
52 00 00 00  -- size = 82 bytes
53 28 63 76 63 23 63 23 76 63 29 00  -- "S(cvc#c#vc)\0"
08 00 00 00  -- serial_len = 8
28 00 00 00  -- name_len = 40
02           -- scan_type = 2 (?)
06 00        -- config_index = 6
43 33 37 30 31 34 35 00  -- "C370145\0"
43 6f 6c 75 6d 6e 20 31 00 00...  -- "Column 1" + padding
```

### Önemli Not: Concatenated Configs

`getScanConfigurations()` response'u **TÜM config'leri** tek pakette döndürebilir.
Her config kendi TPL header'ıyla başlar:

```
[TPL Block 1: Column 1 config]
[TPL Block 2: Hadamard 1 config]
...
```

Parsing yaparken tüm TPL bloklarını iterate etmek gerekir.

### Temel Yapı (Dart)

```dart
class ScanConfiguration {
  final int index;
  final String name;
  final int scanType;        // 0=Column, 1=Hadamard
  final int numSections;
  final List<ScanSection> sections;
  final Uint8List rawData;   // Original TPL data

  factory ScanConfiguration.fromTplData(int index, List<int> data) {
    // TPL parsing implementation
    // See: lib/services/ble/ble_nir_scan_service.dart:_parseConfigData()
  }
}

class ScanSection {
  final int startWavelength; // nm (900-1700)
  final int endWavelength;   // nm (900-1700)
  final int numPatterns;     // 2-624
  final int width;           // Digital resolution (2-60)
  final int numRepeat;       // Scans to average (1-50)
  final int exposure;        // Exposure time
}

enum ScanMethod {
  column,    // 0
  hadamard,  // 1
  slew,      // 2 (rare)
}
```

---

## 10. Scan Data Formatı

Tarama verisi DLP Spectrum Library tarafından yorumlanır.

### Serialized Scan Data Yapısı

```dart
class ScanData {
  final String name;
  final DateTime timestamp;
  final ScanConfiguration config;
  final List<double> wavelengths;
  final List<double> intensities;
  final SensorReadings sensorData;

  // dlpspec_scan_interpret() ile parse edilir
  static ScanData fromSerialized(List<int> data) {
    throw UnimplementedError('Requires DLP Spectrum Library');
  }
}

class SensorReadings {
  final double ambientTemperature;
  final double detectorTemperature;
  final double humidity;
  final int photodetector;
  // ...
}
```

### Reflectance ve Absorbance Hesaplama

```dart
// Reflectance = Sample Intensity / Reference Intensity
List<double> calculateReflectance(
  List<double> sampleIntensity,
  List<double> referenceIntensity,
) {
  assert(sampleIntensity.length == referenceIntensity.length);
  return List.generate(
    sampleIntensity.length,
    (i) => sampleIntensity[i] / referenceIntensity[i],
  );
}

// Absorbance = -log10(Reflectance)
List<double> calculateAbsorbance(List<double> reflectance) {
  return reflectance.map((r) => -log(r) / ln10).toList();
}
```

---

## 11. Calibration Data Formatları

### Spectrum Calibration Coefficients

6 adet double (48 byte) - Wavelength-to-pixel polynomial katsayıları.

```dart
class SpectrumCalibration {
  final List<double> coefficients; // 6 değer

  factory SpectrumCalibration.fromBytes(List<int> data) {
    final bd = ByteData.sublistView(Uint8List.fromList(data));
    final coefficients = <double>[];

    for (int i = 0; i < 6; i++) {
      coefficients.add(bd.getFloat64(i * 8, Endian.little));
    }

    return SpectrumCalibration(coefficients);
  }

  /// Pixel pozisyonunu wavelength'e çevir
  double pixelToWavelength(int pixel) {
    double wavelength = 0;
    for (int i = 0; i < coefficients.length; i++) {
      wavelength += coefficients[i] * pow(pixel, i);
    }
    return wavelength;
  }
}
```

### Reference Calibration

Serialized struct - Factory referans tarama verisi. DLP Spectrum Library ile işlenir.

---

## 12. GCS Command Packet Formatı

GATT Command Service üzerinden generic komut gönderme.

```dart
class GcsCommandPacket {
  final int commandByte;
  final int groupByte;
  final bool isRead;
  final List<int> parameters;

  GcsCommandPacket({
    required this.commandByte,
    required this.groupByte,
    this.isRead = false,
    this.parameters = const [],
  });

  List<int> toBytes() {
    return [
      commandByte,
      groupByte,
      isRead ? 0x05 : 0x03, // Flag: 5=Read, 3=Write
      parameters.length,
      ...parameters,
    ];
  }
}
```

---

## Byte Order Özet

| Veri Tipi | Byte Order | Örnek |
|-----------|------------|-------|
| uint16 | Little-endian | 0x1234 → [0x34, 0x12] |
| int16 | Little-endian | -10 → [0xF6, 0xFF] |
| uint32 | Little-endian | 0x12345678 → [0x78, 0x56, 0x34, 0x12] |
| int32 | Little-endian | ... |
| float64 | Little-endian (IEEE 754) | ... |
| string | Length-prefixed, no null-term | ... |
