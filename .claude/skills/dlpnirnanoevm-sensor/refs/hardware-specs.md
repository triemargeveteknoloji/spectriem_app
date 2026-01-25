# Donanım Özellikleri

> Kaynak: DLPU030G User's Guide, Section 1, 4, Table 1-1, 1-2

## Genel Özellikler

| Parametre | Min | Tipik | Max | Birim |
|-----------|-----|-------|-----|-------|
| Dalga Boyu Aralığı | 900 | - | 1700 | nm |
| Optik Çözünürlük | - | 10 | 12 | nm |
| Lamba Gücü | - | 1.4 | - | W |
| Çalışma Sıcaklığı | 0 | 25 | 50 | °C |

## Fiziksel Boyutlar

- **Uzunluk:** 62 mm
- **Genişlik:** 58 mm
- **Yükseklik:** 36 mm

---

## Optik Motor

### DMD (Digital Micromirror Device)
| Parametre | Değer |
|-----------|-------|
| Model | DLP2010NIR |
| Boyut | 0.2 inch WVGA |
| Piksel Dizilimi | 854 × 480 orthogonal |
| Ayna Açısı | ±17° |
| Optimize Dalga Boyu | 700-2500 nm |

### Detektör
| Parametre | Değer |
|-----------|-------|
| Tip | InGaAs Photodiode |
| Model | Hamamatsu G12180-010A |
| Boyut | 1 mm |
| Soğutma | Yok (non-cooled) |

### Optik Sistem
- **Giriş Yarığı (Slit):** 1.8 mm × 0.025 mm (efektif: 1.69 mm × 0.025 mm)
- **Long-wave Pass Filter:** 885 nm
- **Grating:** Reflective diffraction grating
- **DMD Görüntüleme:** ~1.17 nm/piksel

### Aydınlatma Modülü
- **Lamba Tipi:** Lens-end broadband tungsten filament
- **Lamba Sayısı:** 2 (paralel)
- **Akım:** 280 mA @ 5V (her lamba 140 mA)
- **Beam Açısı:** 40°
- **Odak Mesafesi:** ~3 mm (lamptan)
- **Spot Boyutu:** ~2.5 mm çap (sapphire pencerede)

### Sapphire Pencere
- **Konum:** Ön (numune teması)
- **Not:** Su geçirmez değil (watertight seal yok)
- **Kullanım:** Numune pencereye temas etmeli

---

## Elektronik Kartlar

### 1. Microcontroller Board

#### Tiva TM4C1297NCZAD
| Parametre | Değer |
|-----------|-------|
| Çekirdek | ARM Cortex-M4 |
| Hız | 120 MHz |
| Flash | 1 MB |
| SRAM | 256 KB |
| SDRAM (harici) | 32 MB |

#### Bluetooth Modülü
| Parametre | Değer |
|-----------|-------|
| Model | CC2564MODN |
| Sürüm | Bluetooth 4.1 Low Energy |
| Anten | On-board |

#### Batarya Yönetimi
| Parametre | Değer |
|-----------|-------|
| Şarj IC | bq24250 |
| Şarj Akımı | 1 A (max) |
| Batarya Tipi | Li-Ion / Li-Polymer (3.7V) |
| Şarj Voltajı | 4.2 V |

#### Sensörler
| Sensör | Model | Ölçüm |
|--------|-------|-------|
| Humidity/Temp | HDC1000 | Nem + Sıcaklık |
| Temperature | TMP006 (detector board) | Detektör + Ambient |

### 2. DLP Controller Board

#### DLPC150
| Parametre | Değer |
|-----------|-------|
| Tip | DLP Digital Controller |
| Arayüz | 24-bit RGB (Tiva LCD) |
| PMIC | DLPA2005 |

#### Lamba Sürücü
| Bileşen | Model | Fonksiyon |
|---------|-------|-----------|
| Power Amp | OPA567 | 280 mA constant current |
| Current Monitor | INA213 | Akım izleme |

### 3. Detector Board

| Bileşen | Model | Fonksiyon |
|---------|-------|-----------|
| ADC | ADS1255 | 24-bit, 30 kSPS |
| Op-Amp | OPA2376 | Transimpedance amplifier |
| Buffer | OPA350 | 2.5V reference buffer |
| Reference | REF5025 | 2.5V precision reference |
| Temp Sensor | TMP006 | IR thermopile |
| Detector | G12180-010A | 1mm InGaAs photodiode |

### 4. DMD Board
- DLP2010NIR DMD

---

## Güç Gereksinimleri

### USB Güç
| Parametre | Değer |
|-----------|-------|
| Voltaj | 4.75 - 5.25 V |
| Akım (çalışma) | 560 mA max |
| Akım (şarj) | 1 A max |
| Konnektör | Micro-USB B |

### Batarya (Opsiyonel)
| Parametre | Değer |
|-----------|-------|
| Tip | Li-Polymer (UL certified) |
| Voltaj | 3.7 V |
| Kapasite | 1700 mAh (önerilen) |
| Model | Tenergy 103450 |

#### Batarya Güvenlik Gereksinimleri
- Max şarj akımı: ≥1 A
- Max şarj voltajı: ≥4.23 V
- Overvoltage protection: ≥4.305 V
- Undervoltage lockout: ≤2.5 V

### Termistör (Batarya İzleme)
| Parametre | Değer |
|-----------|-------|
| Tip | 10kΩ NTC |
| Model | Murata NXRT15XH103FA1B040 |

---

## Konnektörler

### J1 - Micro-USB
- Güç ve PC bağlantısı
- HID class iletişim

### J3 - Expansion Connector (10-pin, 1mm JST)
| Pin | Sinyal | Voltaj |
|-----|--------|--------|
| 1 | Power | 3.3V |
| 2 | Ground | GND |
| 3 | PA2 (UART4 RX / SSI0 CLK) | 3.3V |
| 4 | PA3 (UART4 TX / SSI0 FSS) | 3.3V |
| 5 | PA4 (SSI0 Data0) | 3.3V |
| 6 | PA5 (SSI0 Data1) | 3.3V |
| 7 | PK2 (UART4 RTS) | 3.3V |
| 8 | PK3 (UART4 CTS) | 3.3V |
| 9 | Ground | GND |
| 10 | Tiva Wake | 3.3V |

### J4 - JTAG (10-pin ARM Cortex)
Debug ve programlama için.

### J6 - Battery (2-pin, 2mm JST PHR-2)
| Pin | Sinyal |
|-----|--------|
| 1 | Battery + (4.2V) |
| 2 | Ground |

### J7 - Battery Thermistor (2-pin, 1mm JST)
| Pin | Sinyal |
|-----|--------|
| 1 | Power (4.9V) |
| 2 | Ground |

---

## Butonlar

### Wake Button
- **Konum:** Yan panel
- **Fonksiyon:** Hibernation'dan uyandırma

### Scan/Bluetooth Button
- **Konum:** Yan panel
- **Fonksiyonlar:**
  - Kısa basış (< 3s): Tarama başlat
  - Uzun basış (> 3s): Bluetooth etkinleştir

### Reset Button
- **Konum:** Arka panel
- **Fonksiyon:** Donanım reset

---

## LED İndikatörleri

| LED | Renk | Durum | Anlam |
|-----|------|-------|-------|
| Güç | Yeşil | 1 Hz yanıp sönme | Normal çalışma |
| Güç | Yeşil | 2 Hz yanıp sönme | Hata durumu |
| Bluetooth | Mavi | Sürekli | Advertising |
| Bluetooth | Mavi | 1 Hz yanıp sönme | Bağlı |
| Bluetooth | Mavi | 2 Hz yanıp sönme | BLE hatası |
| Scan | Sarı | Sürekli | Tarama devam ediyor |
| Scan | Sarı | 2 Hz yanıp sönme | Tarama hatası |
| Şarj | Kırmızı | Sürekli | Şarj oluyor |
| Şarj | Kırmızı | 256 μs yanıp sönme | Batarya hatası |

---

## Performans Özellikleri

### Tarama Parametreleri
| Parametre | Min | Max |
|-----------|-----|-----|
| Wavelength Points | 1 | 624 |
| Scans to Average | 1 | 65535 |
| Sections | 1 | 5 |
| Exposure Time | 0.635 ms | 60.960 ms |
| Width | 8 nm | 20 nm |

### Tarama Süreleri (Tipik)
| Konfigürasyon | Süre |
|---------------|------|
| 20nm, 80 pts, avg 18 | ~6 s |
| 15nm, 108 pts, avg 12 | ~5 s |
| 10nm, 160 pts, avg 8 | ~5 s |
| 8nm, 225 pts, avg 6 | ~5 s |

### SNR (Signal-to-Noise Ratio)
Hadamard tarama, Column taramaya göre daha yüksek SNR sağlar çünkü her pattern'de DMD piksellerinin %50'si açıktır.

---

## EEPROM İçeriği

Tiva EEPROM (6 KB):

| Adres | Boyut | İçerik |
|-------|-------|--------|
| 0x0000 | 8 | Serial Number (YMMSSS format) |
| 0x0008 | 4 | Scan Data Session Index |
| 0x000C | 4 | Scan Config Index Counter |
| 0x0010 | 4 | Calibration Coefficients Version |
| 0x0014 | 50 | Calibration Coefficients Data |
| 0x0046 | 4 | Reference Calibration Version |
| 0x004A | 3632 | Reference Calibration Data |
| 0x0E7A | 16 | Default Scan Name |
| 0x0E7E | 4 | Active Scan Config Index |
| 0x0E82 | 4 | Scan Config Data Version |
| 0x0E96 | 2154 | Scan Configurations (20 × 107.7 bytes) |
| 0x1700 | 4 | Battery Calibration Data |
| 0x1704 | 16 | Model Name |

---

## Çevresel Limitler

| Parametre | Min | Max | Birim |
|-----------|-----|-----|-------|
| Çalışma Sıcaklığı | 0 | 50 | °C |
| Depolama Sıcaklığı | -20 | 60 | °C |
| Nem (non-condensing) | 10 | 90 | %RH |

**Uyarılar:**
- Optik motoru açmayın - garanti bozulur
- Toz ve nem optik performansı etkiler
- Yeniden hizalama ve kalibrasyon fabrikada yapılmalıdır

---

## Part Numbers

### Ana Bileşenler
| Bileşen | Part Number |
|---------|-------------|
| DMD | DLP2010NIR (DLPS023) |
| Controller | DLPC150 (DLPS045) |
| PMIC | DLPA2005 |
| MCU | TM4C1297NCZAD (SPMS398) |
| BLE Module | CC2564MODN (SWRS179) |
| ADC | ADS1255 (SBAS288) |

### Konnektörler
| Konnektör | Part Number | DigiKey |
|-----------|-------------|---------|
| Battery (2-pin) | JST PHR-2 | 455-1165-ND |
| Thermistor (2-pin) | JST SHR-02V-S-B | 455-1377-ND |
| Expansion (10-pin) | JST SHR-10V-S-B | 455-1385-ND |
| Crimp Terminal | JST SPH-002T-P0.5L | 455-2148-1-ND |

### Önerilen Batarya
| Parametre | Değer |
|-----------|-------|
| Model | Tenergy 103450 |
| Kapasite | 1700 mAh |
| Sertifikasyon | UL |
