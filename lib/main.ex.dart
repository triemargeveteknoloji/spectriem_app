import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BLE Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Flutter BLE Demo'),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title});
  final String sensorName = "NIRScanNano";
  final String title;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final Map<Guid, dynamic> readValues = <Guid, dynamic>{};

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  List<double> combinedSpectrumCalibartionCoeff = [];
  StreamSubscription<List<int>>? notificationSubscription;

  // String olarak dönen verilerin UUID listesi
  final List<Guid> stringCharacteristicUUIDs = [
    Guid("00002a29-0000-1000-8000-00805f9b34fb"), // Manufacturer Name String
    Guid("00002a24-0000-1000-8000-00805f9b34fb"), // Model Number String
    Guid("00002a25-0000-1000-8000-00805f9b34fb"), // Serial Number String
    Guid("00002a27-0000-1000-8000-00805f9b34fb"), // Hardware Revision String
    Guid("00002a26-0000-1000-8000-00805f9b34fb"), // Firmware Revision String
  ];

  // Sıcaklık ve Nem karakteristik UUID'leri
  final Guid temperatureCharacteristicUUID =
      Guid("43484101-444C-5020-4E49-52204E616E6F");

  final Guid humidityCharacteristicUUID =
      Guid("43484102-444C-5020-4E49-52204E616E6F");

  void performCalibrationRequest(BluetoothDevice device) async {
    final Guid requestCalibrationUUID =
        Guid("4348410D-444C-5020-4E49-52204E616E6F");
    final Guid spectrumCalibrationUUID =
        Guid("4348410E-444C-5020-4E49-52204E616E6F");
    final Guid serviceUUID = Guid("53455204-444C-5020-4E49-52204E616E6F");

    try {
      if (notificationSubscription != null) {
        await notificationSubscription!.cancel();
        notificationSubscription = null;
      }

      List<int> combinedData = [];
      int expectedDataSize = 0;
      combinedSpectrumCalibartionCoeff = [];

      // Write işlemi
      BluetoothCharacteristic requestCharacteristic = BluetoothCharacteristic(
        characteristicUuid: requestCalibrationUUID,
        serviceUuid: serviceUUID,
        remoteId: device.remoteId,
      );

      await requestCharacteristic.write(utf8.encode("01"));
      print("WRITE DONE");

      BluetoothCharacteristic notifyCharacteristic = BluetoothCharacteristic(
        characteristicUuid: spectrumCalibrationUUID,
        serviceUuid: serviceUUID,
        remoteId: device.remoteId,
      );

      // Notify işlemini dinleme
      await notifyCharacteristic.setNotifyValue(true);
      notificationSubscription =
          notifyCharacteristic.lastValueStream.listen((value) {
        print("Received data: $value");

        if (value.isNotEmpty) {
          int packetIndex = value[0];

          if (packetIndex == 0) {
            // İlk paket: veri boyutunu belirler
            expectedDataSize = value[1] |
                (value[2] << 8) |
                (value[3] << 16) |
                (value[4] << 24);
            print("Total data size expected: $expectedDataSize bytes");
          } else if (packetIndex == 1) {
            // İkinci paket: ACK/NACK ve ardından veri
            combinedData.addAll(
                value.sublist(2)); // 2. byte'tan sonraki tüm veriyi ekle
            print("value 1 : ${value.sublist(2)}");
          } else if (packetIndex >= 2) {
            // Diğer paketler: tüm byte'lar veri olarak kabul edilir
            combinedData.addAll(
                value.sublist(1)); // 1. byte'tan sonraki tüm veriyi ekle
            print("value <=2 : ${value.sublist(1)}");
          }

          // Tüm veriler geldiğinde işlem yap
          if (combinedData.length >= expectedDataSize) {
            print("All data received, length: ${combinedData.length}");

            // Veriyi 8-byte'lık double dizisine çevir
            for (int i = 0; i < combinedData.length; i += 8) {
              if (i + 8 <= combinedData.length) {
                ByteData byteData = ByteData.sublistView(
                    Uint8List.fromList(combinedData.sublist(i, i + 8)));
                double coefficient = byteData.getFloat64(0, Endian.little);
                combinedSpectrumCalibartionCoeff.add(coefficient);
              }
            }
          }

          print(combinedSpectrumCalibartionCoeff);
        }
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  void writeCalibrationRequest(
      BluetoothCharacteristic characteristic, int requestValue) async {
    Uint8List value = Uint8List(1);
    value[0] = requestValue; // İlgili isteği temsil eden değeri buraya yazın.
    await characteristic.write(value);
  }

  void readAndNotifyCharacteristic(
      BluetoothCharacteristic characteristic) async {
    await characteristic
        .setNotifyValue(true); // Notify özelliğini etkinleştirme
    characteristic.value.listen((value) {
      // Her paket geldiğinde bu kod bloğu çalışır.
      print("Received data: $value");

      // Gelen veriyi işleme (çoklu paket mantığıyla)
      Uint8List data = Uint8List.fromList(value);
      print("DATA.....: $data");
      // Verileri işlemek için burada gerekli işlemleri yapabilirsiniz.
    });
  }

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  _initBluetooth() async {
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          for (ScanResult result in results) {
            _addDeviceTolist(result.device);
          }
        }
      },
      onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      ),
    );

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    await FlutterBluePlus.startScan();

    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    FlutterBluePlus.connectedDevices.map((device) {
      _addDeviceTolist(device);
    });
  }

  @override
  void initState() {
    () async {
      var status = await Permission.location.status;
      if (status.isDenied) {
        final status = await Permission.location.request();
        if (status.isGranted || status.isLimited) {
          _initBluetooth();
        }
      } else if (status.isGranted || status.isLimited) {
        _initBluetooth();
      }

      if (await Permission.location.status.isPermanentlyDenied) {
        openAppSettings();
      }
    }();
    super.initState();
  }

  ListView _buildListViewOfDevices() {
    List<Widget> containers = <Widget>[];
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        SizedBox(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.platformName == ''
                        ? '(unknown device)'
                        : device.advName),
                    Text(device.remoteId.toString()),
                  ],
                ),
              ),
              TextButton(
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.black),
                ),
                onPressed: () async {
                  FlutterBluePlus.stopScan();
                  try {
                    await device.connect();
                  } on PlatformException catch (e) {
                    if (e.code != 'already_connected') {
                      rethrow;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(
      BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = <ButtonTheme>[];

    if (characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              child: const Text('READ', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                var sub = characteristic.lastValueStream.listen((value) {
                  setState(() {
                    // Sıcaklık ve Nem için veriyi işleme
                    if (characteristic.uuid == temperatureCharacteristicUUID) {
                      int rawTemperature =
                          ByteData.sublistView(Uint8List.fromList(value))
                              .getInt32(0, Endian.little);
                      widget.readValues[characteristic.uuid] =
                          '${rawTemperature / 100} °C';
                    } else if (characteristic.uuid ==
                        humidityCharacteristicUUID) {
                      int rawHumidity =
                          ByteData.sublistView(Uint8List.fromList(value))
                              .getUint16(0, Endian.little);
                      widget.readValues[characteristic.uuid] =
                          '${rawHumidity / 100} %';
                    } else if (stringCharacteristicUUIDs
                        .contains(characteristic.uuid)) {
                      widget.readValues[characteristic.uuid] =
                          utf8.decode(value);
                    } else {
                      widget.readValues[characteristic.uuid] = value;
                    }
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              child: const Text('WRITE', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Write"),
                        content: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _writeController,
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Send"),
                            onPressed: () {
                              characteristic.write(
                                  utf8.encode(_writeController.value.text));
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              child:
                  const Text('NOTIFY', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                characteristic.lastValueStream.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List containers = [];
    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = <Widget>[];

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            "Value: ${widget.readValues[characteristic.uuid] != null ? (widget.readValues[characteristic.uuid] is String ? widget.readValues[characteristic.uuid] : widget.readValues[characteristic.uuid].toString()) : "N/A"}")),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        ExpansionTile(
            title: Text(service.uuid.toString()),
            children: characteristicsWidget),
      );
    }

// Buraya kalibrasyon isteğini tetikleyen buton ekliyoruz
    if (_connectedDevice != null) {
      containers.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () => performCalibrationRequest(_connectedDevice!),
            child: const Text('Perform Calibration Request'),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  ListView _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: _buildView(),
      );
}
