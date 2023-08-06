import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HC-05 Adapter Interface',
      home: BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _getAdapterState();
    _getBondedDevices();
    _enableAdapter();
    _startDiscovery();
  }

  Future<void> _getAdapterState() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;
    setState(() {});
  }

  Future<void> _getBondedDevices() async {
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _bondedDevices = bondedDevices;
    });
  }

  Future<void> _enableAdapter() async {
    await FlutterBluetoothSerial.instance.requestEnable();
    _getAdapterState();
  }

  Future<void> _startDiscovery() async {
    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        _discoveredDevices.add(r.device);
      });
    });
  }

  Future<void> _pairDevice(BluetoothDevice device) async {
    try {
      bool? paired = await FlutterBluetoothSerial.instance
          .bondDeviceAtAddress(device.address);
      if (paired!) {
        _getBondedDevices();
      }
    } catch (e) {
      print("Error while pairing: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _selectedDevice = device;
        _isConnected = true;
      });
      print("Connected to ${device.name}");
    } catch (e) {
      log("Error while connecting to device: $e");
    }
  }

  Future<void> _disconnect() async {
    _connection?.close();
    setState(() {
      _isConnected = false;
      _selectedDevice = null;
    });
  }

  Future<void> _sendMessage(String message) async {
    if (_connection != null && message.isNotEmpty) {
      Uint8List data = Uint8List.fromList(utf8.encode(message + '\n'));
      _connection!.output.add(data);
      await _connection!.output.allSent;
      log('Message sent: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HC-05 Adapter Interface'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _startDiscovery(),
            child: Text('Pair'),
          ),
          ListTile(
            title: Text(
                'Adapter Status: ${_bluetoothState.toString().substring(15)}'),
            trailing: ElevatedButton(
              onPressed: _enableAdapter,
              child: Text('Enable'),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('Bonded Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _bondedDevices.length,
              itemBuilder: (context, index) {
                final device = _bondedDevices[index];
                return ListTile(
                  title: Text(device.name!),
                  subtitle: Text(device.address),
                  onTap: _isConnected
                      ? null
                      : () {
                          log(device.address.toString());
                          _connectToDevice(device);
                        },
                  trailing: _isConnected && device == _selectedDevice
                      ? ElevatedButton(
                          onPressed: _disconnect,
                          child: Text('Disconnect'),
                        )
                      : ElevatedButton(
                          onPressed: () => _pairDevice(device),
                          child: Text('Pair'),
                        ),
                );
              },
            ),
          ),
          Divider(),
          ListTile(
            title: Text('Discovered Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return ListTile(
                  title: Text(device.name ?? "NA"),
                  subtitle: Text(device.address),
                  onTap: _isConnected ? null : () => _pairDevice(device),
                  trailing: _isConnected && device == _selectedDevice
                      ? ElevatedButton(
                          onPressed: _disconnect,
                          child: Text('Disconnect'),
                        )
                      : ElevatedButton(
                          onPressed: () => _pairDevice(device),
                          child: Text('Pair'),
                        ),
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(labelText: 'Send Message'),
              onChanged: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
