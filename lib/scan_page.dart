import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:ble_nirnano/ble_uuids.dart';
import 'package:ble_nirnano/records_page.dart';
import 'package:ble_nirnano/scan_service.dart';
import 'package:ble_nirnano/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_it/get_it.dart';

import 'package:bloc/bloc.dart';

class BluetoothState {
  final bool isScanning;
  final List<int>? scanResponse;

  BluetoothState({required this.isScanning, this.scanResponse});
}

class BluetoothCubit extends Cubit<BluetoothState> {
  BluetoothCubit() : super(BluetoothState(isScanning: false));

  Future<void> startScanAndNotify(
    BluetoothCharacteristic notifyCharacteristic,
    BluetoothCharacteristic writeCharacteristic,
    bool storeOnSDCard,
  ) async {
    emit(BluetoothState(isScanning: true));

    try {
      // Write to characteristic to start the scan
      Uint8List value = storeOnSDCard
          ? Uint8List.fromList([0x01])
          : Uint8List.fromList([0x00]);

      await writeCharacteristic.write(value);

      // Request MTU if needed
      if (Platform.isAndroid) {
        await notifyCharacteristic.device.requestMtu(512);
      }

      // Enable notifications
      await notifyCharacteristic.setNotifyValue(true);

      // Listen for notification responses
      notifyCharacteristic.value.listen((response) {
        if (response.isNotEmpty && response[0] == 0xFF) {
          emit(BluetoothState(isScanning: false, scanResponse: response));
          print('Scan complete, Scan index: ${response.sublist(1, 5)}');
        }
      });
    } catch (e) {
      print('Error starting scan: $e');
      emit(BluetoothState(isScanning: false));
    }
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final _ScanPageManager manager;
  late final BluetoothDevice device = GetIt.I<BluetoothDevice>();
  late final List<BluetoothService> services =
      GetIt.I<List<BluetoothService>>();
  final BluetoothCubit bluetoothCubit = BluetoothCubit();

  @override
  void initState() {
    super.initState();
    manager = _ScanPageManager();
    _initialize();
  }

  Future<void> _initialize() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Page - ${device.advName}'),
        actions: [
          IconButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const RecordsPage())),
              icon: const Icon(Icons.history_rounded)),
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage())),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: Column(
              children: [
                Text('Cihaz bağlı: ${device.advName}'),
                Row(
                  children: [
                    Text(
                      manager.temperature != null
                          ? '${manager.temperature} °C'
                          : 'Loading...',
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          double temp = await manager.readTemperature();
                          setState(() {
                            manager.temperature =
                                temp; // Update the temperature state
                          });
                        },
                        child: const Text("Temperature")),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      manager.humidity != null
                          ? '${manager.humidity} %'
                          : 'Loading...',
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          double humid = await manager.readHumidity();
                          setState(() {
                            manager.humidity =
                                humid; // Update the temperature state
                          });
                        },
                        child: const Text("Humidity")),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      manager.battery != null
                          ? '${manager.battery} %'
                          : 'Loading...',
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          double batt = await manager.readBattery();
                          setState(() {
                            manager.battery =
                                batt; // Update the temperature state
                          });
                        },
                        child: const Text("Battery")),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          List<double> calibCoeffs =
                              await manager.requestSpectrumCalibrationCoeffs();
                          setState(() {
                            manager.spectrumCalibrationCoeffs =
                                calibCoeffs; // Update the temperature state
                          });
                        },
                        child: const Text("Spectrum Calibration Coeffs")),
                    Text(
                      manager.spectrumCalibrationCoeffs != null
                          ? '${manager.spectrumCalibrationCoeffs} %'
                          : 'Loading...',
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          List<double> calibCoeffs =
                              await manager.requestReferenceCalibrationCoeffs();
                          setState(() {
                            manager.referenceCalibrationCoeffs =
                                calibCoeffs; // Update the temperature state
                          });
                        },
                        child: const Text("Reference Calibration Coeffs")),
                    Text(
                      manager.referenceCalibrationCoeffs != null
                          ? '${manager.referenceCalibrationCoeffs} %'
                          : 'Loading...',
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          List<double> calibCoeffs =
                              await manager.requestReferenceCalibrationMatrix();
                          setState(() {
                            manager.referenceCalibrationMatrix =
                                calibCoeffs; // Update the temperature state
                          });
                        },
                        child: const Text("Reference Calibration Matrix")),
                    Text(
                      manager.referenceCalibrationMatrix != null
                          ? '${manager.referenceCalibrationMatrix} %'
                          : 'Loading...',
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () async {
                          int? spectrum = await manager.scanSpectrum();
                          setState(() {
                            manager.scanIndex =
                                spectrum; // Update the temperature state
                          });
                        },
                        child: const Text("Scan")),
                    Text(
                      manager.rawSpectrum != null
                          ? '${manager.rawSpectrum} %'
                          : 'Loading...',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanPageManager {
  final ScanService scanService;
  final BluetoothDevice device;
  double? temperature;
  double? humidity;
  double? battery;
  List<double>? spectrumCalibrationCoeffs;
  List<double>? referenceCalibrationCoeffs;
  List<double>? referenceCalibrationMatrix;
  List<double>? rawSpectrum;
  int? scanIndex;

  _ScanPageManager()
      : scanService = GetIt.I.get(),
        device = GetIt.I<BluetoothDevice>();

  Future<double> readTemperature() async {
    double temp = await scanService.readCharacteristicByUUID(
        BleServiceUuids.GGIS, BleCharacteristicUuids.GGIS_TEMP_MEASUREMENT);
    print("Temperature :    $temp");

    return temp;
  }

  Future<double> readHumidity() async {
    double humid = await scanService.readCharacteristicByUUID(
        BleServiceUuids.GGIS, BleCharacteristicUuids.GGIS_HUMID_MEASUREMENT);
    print("Humidity :    $humid");

    return humid;
  }

  Future<double> readBattery() async {
    double batt = await scanService.readCharacteristicByUUID(
        BleServiceUuids.BAS, BleCharacteristicUuids.BAS_BATT_LVL);
    print("Battery :    $batt");

    return batt;
  }

  Future<List<double>> requestSpectrumCalibrationCoeffs() async {
    Uint8List value = Uint8List(1);
    value[0] = 0x01;
    var responseDataArray = scanService.gcisCharacterisics(
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_REQ_SPEC_CAL_COEFF,
      value,
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_RET_SPEC_CAL_COEFF,
    );

    return responseDataArray;
  }

  Future<List<double>> requestReferenceCalibrationCoeffs() async {
    Uint8List value = Uint8List(1);
    value[0] = 0x01;
    var responseDataArray = scanService.gcisCharacterisics(
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_REQ_REF_CAL_COEFF,
      value,
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_RET_REF_CAL_COEFF,
    );

    return responseDataArray;
  }

  Future<List<double>> requestReferenceCalibrationMatrix() async {
    Uint8List value = Uint8List(1);
    value[0] = 0x01;
    var responseDataArray = scanService.gcisCharacterisics(
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_REQ_REF_CAL_MATRIX,
      value,
      BleServiceUuids.GCIS,
      BleCharacteristicUuids.GCIS_RET_REF_CAL_MATRIX,
    );

    return responseDataArray;
  }

  Future<int?> scanSpectrum() async {
    // gets current datetime and convert into byte array as ascii chars
    DateTime now = DateTime.now();
    String formattedDateTime = DateFormat('ddMMyyHHmmss').format(now);

    List<int> dateByteList = [];

    for (int i = 0; i < formattedDateTime.length; i++) {
      int asciiValue = formattedDateTime.codeUnitAt(i); // ASCII value
      dateByteList.add(asciiValue);
    }
    Uint8List datebByteBuffer = Uint8List.fromList(dateByteList);
    print(datebByteBuffer);

    // set scan name stub
    // scanService.writeCharacteriticsByUUID(BleServiceUuids.GSDIS,
    //     BleCharacteristicUuids.GSDIS_SET_SCAN_NAME_STUB, datebByteBuffer);
    BluetoothCharacteristic characteristics = BluetoothCharacteristic(
        remoteId: device.remoteId,
        serviceUuid: BleServiceUuids.GSDIS,
        characteristicUuid: BleCharacteristicUuids.GSDIS_SET_SCAN_NAME_STUB);

    characteristics = BluetoothCharacteristic(
        remoteId: device.remoteId,
        serviceUuid: BleServiceUuids.GSDIS,
        characteristicUuid: BleCharacteristicUuids.GSDIS_START_SCAN);
    Uint8List value = Uint8List(1);
    value[0] = 0x01;
    await scanService.startScan(characteristics, characteristics, false);

    // BluetoothCharacteristic notifyCharacteristic = BluetoothCharacteristic(
    //   characteristicUuid: BleCharacteristicUuids.GSDIS_START_SCAN,
    //   serviceUuid: BleServiceUuids.GSDIS,
    //   remoteId: device.remoteId,
    // );
    // BluetoothCharacteristic writeCharacteristic = BluetoothCharacteristic(
    //   characteristicUuid: BleCharacteristicUuids.GSDIS_START_SCAN,
    //   serviceUuid: BleServiceUuids.GSDIS,
    //   remoteId: device.remoteId,
    // );
    // await scanService.startScan(
    //     notifyCharacteristic, writeCharacteristic, false);

    // set sd card save option and write start scan
    // Uint8List value = Uint8List(1);
    // value[0] = 0x01;
    // // await scanService.writeCharacteriticsByUUID(
    // //     BleServiceUuids.GSDIS, BleCharacteristicUuids.GSDIS_START_SCAN, value);
    // await Future.delayed(Duration(seconds: 5));
    // await scanService.readCharacteristicByUUID(
    //   BleServiceUuids.GSDIS,
    //   BleCharacteristicUuids.GSDIS_START_SCAN,
    // );

    // scanService.startScanAndNotify(
    //     BleServiceUuids.GSDIS, BleCharacteristicUuids.GSDIS_START_SCAN, false);

    // await scanService.writeCharacteriticsByUUID(
    //     BleServiceUuids.GSDIS, BleCharacteristicUuids.GSDIS_REQ_SCAN_NAME);
    // var result2 = scanService.notifyCharacteriticsByUUID(
    //     BleServiceUuids.GSDIS, BleCharacteristicUuids.GSDIS_RET_SCAN_NAME);
    // await Future.delayed(Duration(seconds: 5));
    // var responseDataArray = scanService.gscisNotifyCharacteristics(
    //   BleServiceUuids.GSDIS,
    //   BleCharacteristicUuids.GSDIS_START_SCAN,
    // );

    // return responseDataArray;
  }
}
