# implement-real-service - Strategic Plan

## Executive Summary
RealNirScanService implementasyonu - Texas Instruments DLPNIRNANOEVM sensörü ile flutter_blue_plus kullanarak gerçek BLE iletişimi sağlayan servis. Core BLE fonksiyonlarına odaklanılacak, temel akışlar önce implement edilecek.

## Problem Statement
MockNirScanService ile test yapılabiliyor ancak gerçek sensör ile iletişim için RealNirScanService henüz yok. Interface tanımlı, GATT UUID'leri ve protokol akışları dokümante edilmiş durumda.

## Chosen Approach
**Incremental Core Implementation**
- İlk aşama: BLE discovery + connection + service initialization
- İkinci aşama: Temel read operasyonları (DeviceInfo, DeviceStatus)
- Üçüncü aşama: Notification subscription + multi-packet handling
- Dördüncü aşama: Scan akışı (temel)

Alternatif "Full Implementation" yerine seçildi çünkü:
1. Daha erken test edilebilir milestone'lar
2. Her aşama bağımsız test edilebilir
3. Gerçek sensör ile erken doğrulama yapılabilir

## Acceptance Criteria
- [ ] AC1: BLE scan ile NIRScan cihazı bulunabilir
- [ ] AC2: Cihaza bağlanılıp disconnect edilebilir
- [ ] AC3: Connection state stream doğru çalışır
- [ ] AC4: DeviceInfo başarıyla okunabilir
- [ ] AC5: DeviceStatus başarıyla okunabilir
- [ ] AC6: Notification subscription çalışır
- [ ] AC7: Multi-packet veri alımı çalışır
- [ ] AC8: Performscan temel akışı çalışır

## Test Strategy (TDD)

### Unit Tests
- [ ] Test: `MultiPacketReceiver` doğru parse eder → validates header detection, data accumulation
- [ ] Test: `MultiPacketReceiver` eksik paket durumunu handle eder → validates incomplete state
- [ ] Test: `MultiPacketReceiver` timeout durumunu handle eder → validates timeout behavior
- [ ] Test: `RealNirScanService` bağlantı state'lerini emit eder → validates stream behavior
- [ ] Test: Characteristic read helper doğru değer döner → validates byte parsing

### Integration Tests (Sensör ile)
- [ ] Test: Gerçek sensör keşfedilebilir → validates discovery filter
- [ ] Test: Bağlantı başarıyla kurulur → validates GATT connection
- [ ] Test: DeviceInfo okunabilir → validates DIS characteristics
- [ ] Test: DeviceStatus okunabilir → validates BAS + GGIS characteristics

### Edge Cases
- [ ] Edge: Bağlantı kopması → expected: disconnected state emit, cleanup
- [ ] Edge: Timeout durumu → expected: BleTimeoutException
- [ ] Edge: Cihaz bulunamadı → expected: boş stream, timeout
- [ ] Edge: Zaten bağlı → expected: disconnect + reconnect veya exception

## Implementation Phases

### Phase 1: Test Foundation 🧪
- [ ] MultiPacketReceiver unit testleri yaz
- [ ] RealNirScanService mock/stub testleri yaz
- [ ] Test helper'ları oluştur (MockBluetoothDevice etc.)

### Phase 2: Core BLE Infrastructure 🔧
- [ ] MultiPacketReceiver helper sınıfı implement et
- [ ] RealNirScanService scaffold oluştur
- [ ] BLE discovery implement et (startDeviceScan, stopDeviceScan)
- [ ] Connection management implement et (connect, disconnect)
- [ ] Connection state stream implement et

### Phase 3: Read Operations 📖
- [ ] Characteristic read helper implement et
- [ ] getDeviceInfo implement et (DIS characteristics)
- [ ] getDeviceStatus implement et (BAS + GGIS characteristics)
- [ ] Notification subscription helper implement et

### Phase 4: Scan Foundation 🔬
- [ ] performScan temel akışı implement et
- [ ] Multi-packet response handling için notification listener'lar
- [ ] Remaining methods için stub/throw UnsupportedError

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| flutter_blue_plus API değişikliği | Low | Medium | Version lock, adapter pattern |
| Sensör davranış farklılıkları | Medium | Medium | Timeout handling, retry logic |
| Bluetooth permission hataları | High | Medium | Permission check utility |
| Multi-packet timing sorunları | Medium | High | Configurable timeout, retry |

## Constraints
- flutter_blue_plus ^1.31.0 kullanılacak
- Android 6.0+ / iOS 10+ minimum
- BLE 4.0 uyumluluğu gerekli
- MTU default 20 byte (multi-packet gerekli)

## Success Metrics
- [ ] Tüm unit testler geçer
- [ ] Gerçek sensör ile connect/disconnect çalışır
- [ ] DeviceInfo/DeviceStatus okuma %100 başarılı
- [ ] Kod coverage >80%

## Estimated Effort
- Size: M (Medium)
- Complexity: Medium-High (BLE async complexity)
