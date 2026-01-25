import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager {
  late BluetoothDevice device;
  BluetoothCharacteristic? _selectedCharacteristic;

  String _messagebox = "";
  String _messagebuffer = "";
  String get messagebox => _messagebox;
  String get messagebuffer => _messagebuffer;
  bool run = true;
  late StreamSubscription<List<int>> listener;

  BluetoothManager(this.device);

  Future<void> selectCharacteristic() async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        print(
            'Characteristic: ${characteristic.uuid}, Properties: ${characteristic.properties}');
        if (characteristic.properties.write &&
            characteristic.properties.notify) {
          _selectedCharacteristic = characteristic;
          break;
        } else {
          print(
              'Characteristic ${characteristic.uuid} does not support write operation');
        }
      }
    }
    await startReceivingMessages();
    updateMesasges();
  }

  // dispose
  void dispose() {
    run = false;
    listener.cancel();
  }

  Future<void> sendMessage(String message) async {
    List<int> bytes = utf8.encode(message);
    try {
      if (device.connectionState != BluetoothDeviceState.connected) {
        await device.connect();
      }
      await _selectedCharacteristic!.write(bytes, withoutResponse: false);
      print("Message sent: $message");
    } catch (e) {
      print("Failed to send message: $e");
    }
  }

  // update value
  Future<void> updateMesasges() async {
    while (run) {
      try {
        await Future.delayed(Duration(seconds: 1));
        List<int> readValue = await _selectedCharacteristic!.read();
        print("TTTXW : " + utf8.decode(readValue));
        //_messagebuffer = utf8.decode(readValue);
        print("Message buffer: $_messagebuffer");
      } catch (e) {
        print("Failed to read value: $e");
      }
    }
  }

  Future<void> startReceivingMessages() async {
    try {
      if (Platform.isAndroid) {
        await device.requestMtu(223);
      }

      if (_selectedCharacteristic != null) {
        listener =
            _selectedCharacteristic!.onValueReceived.listen((value) async {
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

        await _selectedCharacteristic!.setNotifyValue(true);
        // remove 3 first characters from string and return the rest (TX=)
      } else {
        print("No characteristic selected for receiving messages");
      }
    } catch (e) {
      print("Failed to receive messages: $e");
    }
  }

  void stopReceivingMessages() {
    _selectedCharacteristic?.value.drain();
  }
}
