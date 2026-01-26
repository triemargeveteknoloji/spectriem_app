# native-spectrum-processing

**Created:** 2026-01-26
**Status:** 🚧 In Progress

---

**Problem:** Raw scan data parsing

`ScanData` içinde `rawData` (Uint8List) var ama `SpectralData` (wavelengths + intensities) parse edilemiyor.

**Approach:** FFI ile Texas Instruments libdlpspectrum.so kullanımı

Direct C function binding ile native library entegrasyonu tercih edildi (pure Dart yerine).

**Related Files:**

- `lib/models/scan_data.dart:1` - ScanData model with rawData
- `lib/models/scan_data.dart:52` - SpectralData model (target output)
- `lib/services/ble/ble_nir_scan_service.dart:380-430` - Raw data acquisition
- `lib/services/ble/ble_nir_scan_service.dart:603-673` - Calibration data fetching
- `lib/services/ble/nir_scan_service.dart:1` - Service interface

**Key Decisions:**

- **FFI vs Pure Dart**: FFI seçildi - TI'ın patented algorithm'ı güvenilir
- **Standalone Service**: `SpectrumParserService` ayrı service olacak (modular)
- **Direct C Binding**: JNI wrapper bypass, direkt `dlpspec_scan_interpReference` çağırılacak

**Native Library Info:**

- **Location**: APK extracted from `~/Downloads/NIRScan Nano_1.0_APKPure.apk`
- **Architectures**: arm64-v8a, armeabi-v7a, x86_64 (emulator)
- **Function**: `dlpspec_scan_interpReference(pRefCal, calSize, pMatrix, matrixSize, pScanResults, pRefResults)`
- **Header**: Found in kstechnologies/NIRScanNano_iOS framework

**C Function Signature:**

```c
DLPSPEC_ERR_CODE dlpspec_scan_interpReference(
    const void *pRefCal,              // Calibration coefficients
    size_t calSize,                   // Size of cal data
    const void *pMatrix,              // Calibration matrix
    size_t matrixSize,                // Size of matrix data
    const scanResults *pScanResults,  // Input scan
    scanResults *pRefResults          // Output (calibrated)
);
```

**Constraints:**

- Android/iOS için farklı library loading stratejisi
- Header files TI NDA protected (public headers kullanılacak)
- Struct memory layout C-compatible olmalı

## Tasks

- [x] APK'dan libdlpspectrum.so extract
- [x] C function signature bul
- [x] Codebase explore (ScanData/SpectralData flow)
- [ ] Native libraries'i project structure'a kopyala
- [ ] FFI bindings oluştur (dart:ffi)
- [ ] SpectrumParserService implement et
- [ ] NirScanService interface'e parse method ekle
- [ ] BleNirScanService'e parseSpectralData implement et
- [ ] Unit tests yaz
- [ ] Real data ile test et

## Sessions

**S1** (2026-01-27): Initialized. Library extracted, function signature found, codebase analyzed.
