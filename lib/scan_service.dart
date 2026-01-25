import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_it/get_it.dart';
import 'ble_uuids.dart';

class ScanService {
  late final List<BluetoothService> services;
  late final BluetoothDevice device;
  StreamSubscription<List<int>>? notificationSubscription;

  String _messagebox = "";
  String _messagebuffer = "";
  String get messagebox => _messagebox;
  String get messagebuffer => _messagebuffer;
  bool run = true;
  late StreamSubscription<List<int>> listener;

  ScanService() {
    device = GetIt.I<BluetoothDevice>();
    services = GetIt.I<List<BluetoothService>>();
    // List<BluetoothService> services =   await device.discoverServices();
  }

  Future<dynamic> readCharacteristicByUUID(
      Guid serviceUUID, Guid characteristicUUID) async {
    // ignore: prefer_typing_uninitialized_variables
    var result;
    List<int> value;
    // BluetoothCharacteristic characteristic = BluetoothCharacteristic(
    //   characteristicUuid: characteristicUUID,
    //   serviceUuid: serviceUUID,
    //   remoteId: device.remoteId,
    // );

    try {
      var value;
      for (var service in services) {
        if (service.uuid == serviceUUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == characteristicUUID) {
              value = await characteristic.read();
              print("VALUE : $value");
            }
          }
        }
      }
      // Sıcaklık ve Nem için veriyi işleme
      if (characteristicUUID == BleCharacteristicUuids.GGIS_TEMP_MEASUREMENT ||
          characteristicUUID == BleCharacteristicUuids.BAS_BATT_LVL) {
        var response = ByteData.sublistView(Uint8List.fromList(value))
            .getInt32(0, Endian.little);
        // ByteData.sublistView(Uint8List.fromList(value.sublist(2, 4)))
        //     .getInt16(0, Endian.little);
        result = (response / 100).toDouble();

        print("REULST : $result");
      } else if (characteristicUUID ==
          BleCharacteristicUuids.GGIS_HUMID_MEASUREMENT) {
        var response = ByteData.sublistView(Uint8List.fromList(value))
            .getInt16(0, Endian.little);
        result = (response / 100).toDouble();

        print("REULST : $result");
      } else if (characteristicUUID == BleCharacteristicUuids.BAS_BATT_LVL) {
        // bu kısım cihaza pil takılınca düzeltilecek.
        var response =
            ByteData.sublistView(Uint8List.fromList(value)).getInt8(0);

        result = (response).toDouble();

        print("REULST : $result");
      } else {
        result = utf8.decode(value);
      }
    } catch (e) {
      print("Error reading characteristic: $e");
    }
    return result;
  }

  Future<void> startScan(BluetoothCharacteristic notifyCharacteristic,
      BluetoothCharacteristic writeCharacteristic, bool storeOnSDCard) async {
    try {
      // Write 0x00 for no SD card storage, or 0x01 to save to SD card
      Uint8List value = storeOnSDCard
          ? Uint8List.fromList([0x01])
          : Uint8List.fromList([0x00]);
      print("--------------------- haydi write");
      await writeCharacteristic.write(value);
      await Future.delayed(Duration(seconds: 6));
      // Wait for the notification of scan completion
      //sawait notifyCharacteristic.setNotifyValue(true);
      print("--------------------- haydi write");
      var notificationSubscription =
          notifyCharacteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty && value[0] == 0xFF) {
          print("Scan completed, Scan Index: ${value.sublist(1)}");
        }
      });

      await notificationSubscription?.cancel();
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  Future<List<double>> gcisCharacterisics(
      Guid? writeServiceUUID,
      Guid? writeCharacteristicUUID,
      Uint8List? writeValue,
      Guid? notifyServiceUUID,
      Guid? notifyCharacteristicUUID) async {
    writeCharacteriticsByUUID(
        writeServiceUUID!, writeCharacteristicUUID!, writeValue!);

    var combinedResultArray = await notifyCharacteriticsByUUID(
        notifyServiceUUID!, notifyCharacteristicUUID!);
    return combinedResultArray;
  }

  Future<void> writeCharacteriticsByUUID(
      Guid serviceUUID, Guid characteristicUUID,
      [Uint8List? value]) async {
    // Write işlemi
    try {
      BluetoothCharacteristic requestCharacteristic = BluetoothCharacteristic(
        characteristicUuid: characteristicUUID,
        serviceUuid: serviceUUID,
        remoteId: device.remoteId,
      );

      // for (var service in services) {
      //   if (service.uuid == serviceUUID) {
      //     for (var characteristic in service.characteristics) {
      //       if (characteristic.uuid == characteristicUUID) {
      if (value == null) {
        requestCharacteristic.write([]); //utf8.encode(value.toString())
      } else {
        requestCharacteristic.write(value);
      }
      //       }
      //     }
      //   }
      // }

      print("WRITE DONE");
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<List<double>> notifyCharacteriticsByUUID(
      Guid serviceUUID, Guid characteristicUUID) async {
    List<double> combinedResultingDataArray = [];
    List<int> combinedData = [];
    int expectedDataSize = 0;

    BluetoothCharacteristic notifyCharacteristic = BluetoothCharacteristic(
      characteristicUuid: characteristicUUID,
      serviceUuid: serviceUUID,
      remoteId: device.remoteId,
    );

    Completer<List<double>> completer = Completer<List<double>>();
    try {
      // Notify işlemini dinleme
      notifyCharacteristic.setNotifyValue(true);
      // for (var service in services) {
      //   if (service.uuid == serviceUUID) {
      //     for (var characteristic in service.characteristics) {
      //       if (characteristic.uuid == characteristicUUID) {
      notificationSubscription =
          notifyCharacteristic.onValueReceived.listen((value) async {
        // print("Received data: $value");

        if (value.isNotEmpty) {
          int packetIndex = value[0];

          if (packetIndex == 0) {
            // İlk paket: veri boyutunu belirler
            expectedDataSize = value[1] |
                (value[2] << 8) |
                (value[3] << 16) |
                (value[4] << 24);
            print(
                ".........................................Total data size expected: $expectedDataSize bytes");
            print("$packetIndex: ${value.sublist(0)}");
          } else if (packetIndex == 1) {
            // İkinci paket: ACK/NACK ve ardından veri
            combinedData.addAll(
                value.sublist(2)); // 2. byte'tan sonraki tüm veriyi ekle
            print("sil bunu: $combinedData");
            print("$packetIndex: ${value.sublist(0)}");
          } else if (packetIndex >= 2) {
            // Diğer paketler: tüm byte'lar veri olarak kabul edilir
            combinedData.addAll(
                value.sublist(1)); // 1. byte'tan sonraki tüm veriyi ekle
            print("$packetIndex : ${value.sublist(0)}");
          }
        }
        print(
            ".........................................Total data size expected: $expectedDataSize bytes");
        print(
            "............................................Total size of data received: ${combinedData.length}");

        print("Total size of data received: ${combinedData.length}");

        if (combinedData.length >= expectedDataSize - 1) {
          List<double> coefficients = [];
          combinedResultingDataArray.clear();
          for (int i = 0; i < combinedData.length; i += 8) {
            if (i + 8 <= combinedData.length) {
              ByteData byteData = ByteData.sublistView(
                  Uint8List.fromList(combinedData.sublist(i, i + 8)));
              double singleCoeffValue = byteData.getFloat64(0, Endian.little);
              combinedResultingDataArray.add(singleCoeffValue);
            }
          }

          await notificationSubscription?.cancel();
          completer
              .complete(combinedResultingDataArray); // Complete the completer
        }
      });
    } catch (e) {
      print("error happened during listenning notification ssevice : $e");
    }
    // Wait for the completer to complete
    List<double> result = await completer.future;

    print("Finito");
    return result;
  }

  Future<void> startScanAndNotify(
      Guid serviceUUID, Guid characteristicUUID, bool storeOnSDCard) async {
    // try {
    //   StreamSubscription<List<int>>? subscription;

    //   Uint8List value = storeOnSDCard
    //       ? Uint8List.fromList([0x01])
    //       : Uint8List.fromList([0x00]);

    //   BluetoothCharacteristic characteristic = BluetoothCharacteristic(
    //     characteristicUuid: characteristicUUID,
    //     serviceUuid: serviceUUID,
    //     remoteId: device.remoteId,
    //   );

    //   for (var service in services) {
    //     if (service.uuid == serviceUUID) {
    //       for (var characteristic in service.characteristics) {
    //         if (characteristic.uuid == characteristicUUID) {
    //           // Write to characteristic
    //           await characteristic.write(value);
    //           //await Future.delayed(const Duration(seconds: 15));
    //           await characteristic.setNotifyValue(true);
    //           // Listen for responses
    //           if (Platform.isAndroid) {
    //             await device.requestMtu(512);
    //           }

    //           subscription = characteristic.value.listen((response) {
    //             print('Scan notification received: $response');
    //             if (response.isNotEmpty && response[0] == 0xFF) {
    //               print('Scan complete, Scan index: ${response.sublist(1, 5)}');
    //             }
    //           });
    //           subscription!.cancel();
    //         }
    //       }
    //     }
    //   }

    //   subscription!.cancel();
    // } catch (e) {
    //   print("Error: $e");
    // }
  }

  Future<void> sendMessage(
      BluetoothCharacteristic characteristic, String message) async {
    List<int> bytes = utf8.encode(message);
    try {
      await characteristic!.write(bytes, withoutResponse: false);
      print("Message sent: $message");
    } catch (e) {
      print("Failed to send message: $e");
    }
  }

  Future<void> startReceivingMessages(
      BluetoothCharacteristic selectedCharacteristic) async {
    try {
      if (Platform.isAndroid) {
        await device.requestMtu(512);
      }

      if (selectedCharacteristic != null) {
        listener =
            selectedCharacteristic!.onValueReceived.listen((value) async {
          print("Raw value received: $value");
          if (value.isNotEmpty) {
            String message = utf8.decode(value);
            _messagebuffer = "$message\n";
            // Add a read operation
            print("Received message: $message");
          } else {
            print("Received empty value");
          }
        });

        await selectedCharacteristic!.setNotifyValue(true);
        // remove 3 first characters from string and return the rest (TX=)
      } else {
        print("No characteristic selected for receiving messages");
      }
    } catch (e) {
      print("Failed to receive messages: $e");
    }
  }
}
