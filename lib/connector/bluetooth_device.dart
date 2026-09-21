import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_service.dart'; // Ensure this points to your BluetoothServiceManager


/// Bluetooth Connector for connecting to bluetooth device only

class BleConnector {
  static final Guid serviceUuid = Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  static final Guid txUuid = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  static final Guid rxUuid = Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");

// Returns current connection status directly from FlutterBluePlus
  static bool get isConnected {
    return FlutterBluePlus.connectedDevices.isNotEmpty;
  }

  // Disconnects active Bluetooth devices directly without using the ServiceManager
  static Future<void> disconnect() async {
    for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
      await device.disconnect();
    }
  }

  // Call this from any screen's button to start the connection process
  static Future<void> connect(BuildContext context) async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (await FlutterBluePlus.isSupported == false) {
      print('Bluetooth is not supported on this device.');
      return;
    }

    _showDeviceSelectionDialog(context);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    Future.delayed(const Duration(seconds: 15), () {
      if (FlutterBluePlus.isScanningNow) {
        FlutterBluePlus.stopScan();
      }
    });
  }

  static void _showDeviceSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wybierz urządzenie Klupa'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<List<ScanResult>>(
              stream: FlutterBluePlus.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                final results = snapshot.data ?? [];
                return results.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Szukanie urządzeń...'),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final data = results[index];
                    String name = data.device.platformName;
                    if (name.isEmpty) name = data.advertisementData.localName;
                    if (name.isEmpty) name = 'Nieznane urządzenie';

                    return ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data.device.remoteId.toString()),
                      trailing: ElevatedButton(
                        child: const Text('Połącz'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await FlutterBluePlus.stopScan();

                          // Connect via your global manager
                          await BluetoothServiceManager().connectToDevice(
                            data.device,
                            serviceUuid,
                            rxUuid,
                            txUuid,
                                (msg) => print(msg),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FlutterBluePlus.stopScan();
                Navigator.of(context).pop();
              },
              child: const Text('Anuluj'),
            ),
          ],
        );
      },
    );
  }
}