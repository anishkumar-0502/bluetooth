import 'dart:async';
import 'package:bluetooth/Bluetooth/terminal_page.dart';
import 'package:bluetooth/utilities/Seperater/gradientPainter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with AutomaticKeepAliveClientMixin {
  final _flutterBlueClassicPlugin = FlutterBlueClassic();
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final Set<BluetoothDevice> _scanResults = {};
  StreamSubscription? _scanSubscription;

  bool _isScanning = false;
  BluetoothDevice? connectedDevice;
  bool isDeviceConnected = false;
  String? connectedDeviceAddress;
  int? _connectingToIndex;

  Map<String, BluetoothConnection?> _connections = {};
  bool _skipScan = false;
  Map<String, Color> _deviceColors =
      {}; // Map to store colors for each device address

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      BluetoothAdapterState adapterState = _adapterState;

      // Listen to adapter state changes
      // Listen to scan results
      _scanSubscription = _flutterBlueClassicPlugin.scanResults.listen((
        device,
      ) {
        // Filter devices: Remove those with no name or labeled as "Unknown"
        if (device.name != null &&
            device.name!.isNotEmpty &&
            device.name != 'Unknown Device') {
          if (mounted) setState(() => _scanResults.add(device));
        }
      });

      if (!mounted) return;
      setState(() => _adapterState = adapterState);
      await retrieveDeviceInfo();
    } catch (e) {
      if (kDebugMode) print("Error initializing platform state: $e");
    }
  }

  Future<void> retrieveDeviceInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve previous connection state
    String? storedDeviceAddress = prefs.getString('connected_device_address');
    bool? wasDeviceConnected = prefs.getBool('is_device_connected') ?? false;

    print("Stored device address: $storedDeviceAddress");
    print("Was device connected: $wasDeviceConnected");

    if (storedDeviceAddress != null && wasDeviceConnected) {
      // Skip scanning and attempt to reconnect to the stored device
      print("Attempting to reconnect to the previously connected device...");
      try {
        BluetoothConnection? connection = await connectWithRetry(
          storedDeviceAddress,
        );
        if (connection != null && connection.isConnected) {
          setState(() {
            connectedDeviceAddress = storedDeviceAddress;
            connectedDevice = _scanResults.firstWhere(
              (d) => d.address == storedDeviceAddress,
            );
            isDeviceConnected = true;
            _skipScan = true;
          });
          print("Reconnected to the previously connected device.");
          _isScanning = false;
        } else {
          print("Failed to reconnect to the previously connected device.");
          startAutomaticScan();
        }
      } catch (e) {
        print("Reconnection error: $e");
        startAutomaticScan();
      }
    } else {
      print("No connected device found. Starting scan...");
      startAutomaticScan();
    }
  }

  void startAutomaticScan() async {
    if (_skipScan) {
      print("Skipping scan as a device is already connected.");
      return;
    }
    if (_isScanning) {
      print("Scan already in progress.");
      return;
    }

    print("Starting scan...");
    setState(() => _isScanning = true);

    _flutterBlueClassicPlugin.startScan();

    await Future.delayed(const Duration(seconds: 10)); // Set scan duration
    _flutterBlueClassicPlugin.stopScan();
    setState(() => _isScanning = false);

    print("Scan completed.");
  }

  Future<void> requestPermissions() async {
    Location location = Location();

    // Check if location service is enabled
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        await _showLocationServicesDialog();
        return;
      }
    }

    // Request location permission if not granted
    if (await Permission.location.isDenied ||
        await Permission.location.isPermanentlyDenied) {
      await Permission.location.request();
    }

    // Request Bluetooth permissions if not granted
    if (await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothScan.isPermanentlyDenied) {
      await Permission.bluetoothScan.request();
    }

    if (await Permission.bluetoothConnect.isDenied ||
        await Permission.bluetoothConnect.isPermanentlyDenied) {
      await Permission.bluetoothConnect.request();
    }
  }

  Future<void> _showLocationServicesDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 35),
                  SizedBox(width: 10),
                  Expanded(
                    // Add this to prevent the overflow issue
                    child: Text(
                      "Enable Location", // The heading text
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow:
                          TextOverflow
                              .ellipsis, // Optional: add ellipsis if text overflows
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CustomGradientDivider(), // Custom gradient divider
            ],
          ),
          content: const Text(
            'Location services are required to use this feature. Please enable location services in your phone settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
            ), // Adjusted text color for contrast
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Save the flag to not show the dialog again
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('LocationPromptClosed', true);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings(); // Open the location settings
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                "Settings",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<BluetoothConnection?> connectWithRetry(
    String address, {
    int retries = 3,
  }) async {
    BluetoothConnection? connection;
    BluetoothDevice? device;

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        print("Attempting to connect to $address (Attempt: $attempt)");

        // Find the BluetoothDevice during the scan and attempt to connect
        device = _scanResults.firstWhere((d) => d.address == address);

        connection = await _flutterBlueClassicPlugin
            .connect(address)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print("Connection timed out.");
                throw TimeoutException('Connection timed out.');
              },
            );

        print("Connection successful: $connection");

        if (connection != null && connection.isConnected) {
          setState(() {
            connectedDevice = device;
            connectedDeviceAddress = address;
            isDeviceConnected = true;
            _deviceColors[address] = Colors.green;
          });

          // Store the connected device address in SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('connected_device_address', address);
          await prefs.setBool('is_device_connected', true);

          print("Device connected successfully. ${connection.isConnected}");
          return connection;
        } else {
          print("Connection failed");
        }
      } catch (e) {
        print("Connection error: $e");

        if (attempt == retries) rethrow;
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Retry after 2 seconds
        print("Retrying connection...");
      }
    }

    print("Failed to connect to $address after $retries attempts.");
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Ensure AutomaticKeepAliveClientMixin works
    final double screenWidth = MediaQuery.of(context).size.width;
    List<BluetoothDevice> scanResults = _scanResults.toList();
    String? addressOfDevice = connectedDeviceAddress;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Bluetooth",
          style: TextStyle(
            color: const Color.fromARGB(255, 28, 56, 139),
            fontSize: screenWidth * 0.05, // Dynamic title font size
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              startAutomaticScan();
            },
            icon: Icon(
              Icons.refresh,
              size: screenWidth * 0.06,
              color: const Color.fromARGB(
                255,
                28,
                56,
                139,
              ), // Dynamic icon size
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              size: screenWidth * 0.06,
              color: const Color.fromARGB(
                255,
                28,
                56,
                139,
              ), // Dynamic icon size
            ),
          ),
        ],
        iconTheme: const IconThemeData(
          color: const Color.fromARGB(255, 28, 56, 139),
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          ListTile(
            tileColor: const Color.fromARGB(255, 235, 235, 235),
            title: const Text(
              "Enable your Bluetooth",
              style: TextStyle(color: Colors.black),
            ),
            subtitle: const Text(
              "Tap to enable",
              style: TextStyle(color: Colors.black),
            ),
            // trailing: Text(_adapterState.name),
            leading: const Icon(
              Icons.settings_bluetooth,
              color: Color.fromARGB(255, 28, 56, 139),
            ),
            onTap: () => _flutterBlueClassicPlugin.turnOn(),
          ),
          const Divider(),
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Scanning for Bluetooth devices...',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          if (scanResults.isEmpty)
            Center(
              child: Text(
                "No devices found yet",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.red,
                ),
              ),
            )
          else
            ...scanResults.asMap().entries.map((result) {
              return Column(
                children: [
                  ListTile(
                    title: Text(
                      result.value.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      result.value.address,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.black,
                      ),
                    ),
                    leading: Container(
                      width: 5.0,
                      height: 40.0,
                      color:
                          _deviceColors[result.value.address] ??
                          Colors.grey, // Dynamically assign color
                    ),
                    onTap: () async {
                      final deviceAddress = result.value.address;
                      print("device address: ${deviceAddress}");
                      print(
                        "connected device address: ${connectedDevice?.address}",
                      );

                      if (connectedDevice != null &&
                          isDeviceConnected &&
                          connectedDevice?.address == deviceAddress) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    DeviceDetailsPage(device: connectedDevice!),
                          ),
                        );
                      } else {
                        setState(() {
                          _connectingToIndex =
                              result.key; // Update connecting index
                          isDeviceConnected = true; // Update connection status
                          connectedDeviceAddress = deviceAddress;
                          // Store device address
                        });

                        // Ensure the device is in the scan results
                        BluetoothDevice? device = _scanResults.firstWhere(
                          (d) =>
                              d.address ==
                              deviceAddress, // Return null if not found
                        );

                        if (device != null) {
                          try {
                            final conn = await connectWithRetry(deviceAddress);
                            if (conn != null && conn.isConnected) {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        margin: const EdgeInsets.all(16),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color.fromARGB(
                                            255,
                                            28,
                                            56,
                                            139,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Connected to ${result.value.name ?? 'Unknown'}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            TextButton(
                                              child: const Text(
                                                'X',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => DeviceDetailsPage(
                                                          device:
                                                              connectedDevice!,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );

                              setState(() {
                                _connections[deviceAddress] =
                                    conn; // Save the connection
                                _connectingToIndex =
                                    null; // Reset connecting index
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Failed to connect to the device.",
                                  ),
                                ),
                              );
                              setState(
                                () => _connectingToIndex = null,
                              ); // Reset connecting index
                            }
                          } catch (e) {
                            print("Connection error: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Connection failed after retries.",
                                ),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Device not found in scan results.",
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(color: Colors.grey),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }
}
