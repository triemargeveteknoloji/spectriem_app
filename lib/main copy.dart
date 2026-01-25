import 'dart:async';
import 'package:ble_nirnano/bluetooth_manager.dart';
import 'package:ble_nirnano/scan_page.dart';
import 'package:ble_nirnano/scan_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BLE Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Pairing Page'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String sensorName = "NIRScanNano";
  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  _initBluetooth() async {
    // // Check Bluetooth status
    // var isBluetoothOn = await FlutterBluePlus.instance.isOn.first;
    // if (!isBluetoothOn) {
    //   await FlutterBluePlus.instance.turnOn();
    // }
    // İzinleri kontrol et
    var status = await Permission.location.status;
    if (status.isDenied) {
      final status = await Permission.location.request();
      if (status.isGranted || status.isLimited) {
        _startScan();
      }
    } else if (status.isGranted || status.isLimited) {
      _startScan();
    }

    if (await Permission.location.status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  void _startScan() {
    if (!_isScanning) {
      setState(() {
        _isScanning = true;
      });

      FlutterBluePlus.startScan();
      print(".........................{scanstarted}");
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          print("......................... {result}");
          if (result.device.advName == widget.sensorName) {
            FlutterBluePlus.stopScan();
            setState(() {
              _isScanning = false;
              _connectedDevice = result.device;
            });
            await _connectedDevice!.connect();
            // Discover services and register them
            List<BluetoothService> services =
                await _connectedDevice!.discoverServices();
            // Register the device
            GetIt.I.registerSingleton<BluetoothDevice>(_connectedDevice!);
            GetIt.I.registerSingleton<List<BluetoothService>>(services);
            GetIt.I.registerSingleton(ScanService());
            _navigateToScanPage();
            break;
          }
        }
      });

      // Belirli bir süre sonra taramayı durdur ve tekrar başlat
      Future.delayed(const Duration(seconds: 5), () {
        if (_isScanning) {
          FlutterBluePlus.stopScan();
          setState(() {
            _isScanning = false;
          });
          Future.delayed(const Duration(seconds: 10), () {
            _startScan(); // Taramayı yeniden başlat
          });
        }
      });
    }
  }

  void _navigateToScanPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _isScanning
            ? const Text('Lütfen cihazı aktifleştiriniz...')
            : const Text('Cihaz bağlanıyor...'),
      ),
    );
  }
}
