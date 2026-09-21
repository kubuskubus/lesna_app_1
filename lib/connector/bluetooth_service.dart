import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothServiceManager {
  // Singleton pattern so it's globally unique
  static final BluetoothServiceManager _instance = BluetoothServiceManager._internal();
  factory BluetoothServiceManager() => _instance;
  BluetoothServiceManager._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? uartTxCharacteristic;
  StreamSubscription<List<int>>? notifySubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  bool get isConnected => connectedDevice != null;

  // Broadcast stream so any screen can listen to parsed tree measurements
  final StreamController<double> _treeStreamController = StreamController<double>.broadcast();
  Stream<double> get onTreeMeasured => _treeStreamController.stream;

  String _streamBuffer = '';

  Future<void> connectToDevice(BluetoothDevice device, Guid serviceUuid, Guid rxUuid, Guid txUuid, Function(String) logger) async {
    try {
      connectedDevice = device;
      String deviceName = device.platformName.isEmpty ? "Digitech BT" : device.platformName;
      logger('--> Connecting to $deviceName...');

      await device.connect(autoConnect: false);
      logger('--> Connected! Discovering Services...');

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == txUuid) {
              uartTxCharacteristic = characteristic;
            }
            if (characteristic.uuid == rxUuid) {
              await characteristic.setNotifyValue(true);
              await notifySubscription?.cancel();

              notifySubscription = characteristic.onValueReceived.listen((value) {
                if (value.isNotEmpty) {
                  _processIncomingBytes(value, logger);
                }
              });
            }
          }
        }
      }

      logger('--> [Subscribed to RX notifications - Ready for measurements]');

      await connectionSubscription?.cancel();
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          logger('--> Device disconnected.');
          disconnect();
        }
      });
    } catch (e) {
      logger('Connection Error: $e');
    }
  }

  void _processIncomingBytes(List<int> bytes, Function(String) logger) {
    String rawText = utf8.decode(bytes, allowMalformed: true);
    _streamBuffer += rawText;

    while (_streamBuffer.contains('\n') || _streamBuffer.contains('\r')) {
      int index = _streamBuffer.indexOf(RegExp(r'[\r\n]'));
      String line = _streamBuffer.substring(0, index).trim();
      _streamBuffer = _streamBuffer.substring(index + 1);

      if (line.isNotEmpty) {
        logger('Received Line: $line');
        if (line.startsWith('\$PHGF')) {
          List<String> parts = line.split(',');
          if (parts.length >= 4 && parts[1] == 'DIA') {
            double? rawValue = double.tryParse(parts[3]);
            if (rawValue != null) {
              double diameterCm = rawValue / 10.0;
              _treeStreamController.add(diameterCm); // Broadcast globally!
              logger('-> Parsed Diameter: $diameterCm cm');
            }
          }
        } else {
          double? diameter = double.tryParse(line);
          if (diameter != null) {
            _treeStreamController.add(diameter); // Broadcast globally!
            logger('-> Added Tree Diameter: $diameter cm');
          }
        }
      }
    }
  }

  void disconnect() {
    notifySubscription?.cancel();
    connectionSubscription?.cancel();
    connectedDevice?.disconnect();
    connectedDevice = null;
    uartTxCharacteristic = null;
  }
}