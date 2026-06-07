// lib/ble_measurement_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/measurement_models.dart';

class BleMeasurementService {
  // Adjust these once your firmware has fixed UUIDs
  static final Guid serviceUuid =
      Guid('0000abcd-0000-1000-8000-00805f9b34fb');
  static final Guid measurementCharUuid =
      Guid('0000abce-0000-1000-8000-00805f9b34fb');

  // You can use a name filter OR service UUID filter when scanning
  static const String targetDeviceName = 'WellSync Core2';

  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String?> statusMessage = ValueNotifier<String?>(null);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _measurementChar;
  StreamSubscription<List<int>>? _notifySub;

  final StreamController<MeasurementSample> _samplesController =
      StreamController<MeasurementSample>.broadcast();

  Stream<MeasurementSample> get samplesStream => _samplesController.stream;

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.bluetooth,
    ].request();

    final scanGranted =
        statuses[Permission.bluetoothScan] == PermissionStatus.granted ||
        statuses[Permission.location] == PermissionStatus.granted;

    final connectGranted =
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted ||
        statuses[Permission.bluetooth] == PermissionStatus.granted;

    return scanGranted && connectGranted;
  }

  Future<void> connectAndListen() async {
    if (isConnected.value) return;

    // 1) Check permissions
    final ok = await _ensurePermissions();
    if (!ok) {
      statusMessage.value =
          'Bluetooth permissions are required to scan for your watch.';
      return;
    }

    // 2) Check that Bluetooth is ON
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      statusMessage.value = 'Please turn on Bluetooth on your phone.';
      return;
    }

    statusMessage.value = 'Scanning for device...';
    isScanning.value = true;

    try {
      // Start scan (static API)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        // optionally: withServices: [serviceUuid],
      );

      BluetoothDevice? foundDevice;

      await for (final results in FlutterBluePlus.scanResults) {
        // results is List<ScanResult>
        for (final r in results) {
          final device = r.device;
          final name = device.platformName; // platformName is the new field

          if (name == targetDeviceName ||
              r.advertisementData.serviceUuids.contains(serviceUuid)) {
            foundDevice = device;
            break;
          }
        }

        if (foundDevice != null) break;
      }

      await FlutterBluePlus.stopScan();
      isScanning.value = false;

      if (foundDevice == null) {
        statusMessage.value = 'Device not found. Make sure the watch is on.';
        return;
      }

      _device = foundDevice;
      statusMessage.value =
          'Connecting to ${foundDevice.platformName}...';

      await foundDevice.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      isConnected.value = true;

      // Discover services
      final services = await foundDevice.discoverServices();
      BluetoothCharacteristic? measurementChar;

      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final c in service.characteristics) {
            if (c.uuid == measurementCharUuid) {
              measurementChar = c;
              break;
            }
          }
        }
      }

      if (measurementChar == null) {
        statusMessage.value = 'Measurement characteristic not found.';
        await _safeDisconnect();
        return;
      }

      _measurementChar = measurementChar;

      // Enable notifications
      await measurementChar.setNotifyValue(true);

      _notifySub?.cancel();
      _notifySub = measurementChar.onValueReceived.listen((data) {
        try {
          final jsonStr = utf8.decode(data);
          final decoded = json.decode(jsonStr) as Map<String, dynamic>;
          final sample = MeasurementSample.fromJson(decoded);
          _samplesController.add(sample);
        } catch (e, st) {
          if (kDebugMode) {
            print('Error parsing BLE data: $e');
            print(st);
          }
        }
      });

      statusMessage.value = 'Connected and receiving data.';
    } catch (e) {
      statusMessage.value = 'BLE error: $e';
      await _safeDisconnect();
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> _safeDisconnect() async {
    try {
      _notifySub?.cancel();
      _notifySub = null;

      if (_measurementChar != null) {
        try {
          await _measurementChar!.setNotifyValue(false);
        } catch (_) {}
      }

      if (_device != null) {
        await _device!.disconnect();
      }
    } catch (_) {
      // ignore
    } finally {
      _device = null;
      _measurementChar = null;
      isConnected.value = false;
    }
  }

  Future<void> disconnect() async {
    await _safeDisconnect();
    statusMessage.value = 'Disconnected';
  }

  void dispose() {
    _samplesController.close();
    isScanning.dispose();
    isConnected.dispose();
    statusMessage.dispose();
  }
}