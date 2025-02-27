import 'dart:async';
import 'dart:convert';
import 'package:bluetooth/Bluetooth/write_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceDetailsPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothConnection? connection;

  const DeviceDetailsPage({super.key, required this.device, this.connection});

  @override
  _DeviceDetailsPageState createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  bool _isConnected = false;
  BluetoothConnection? _connection;
  List<String> _logs = [];
  List<Color> _logColors = []; // Add this list to store colors

  TextEditingController _textController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  TextEditingController _ssidController = TextEditingController();
  String _savedData = '';
  String writeData = '';
  Color _fabColor =
      Colors.grey; // Variable to hold the button's background color
  String _receivedDataBuffer = ""; // Buffer to hold split data
  @override
  void initState() {
    super.initState();
    _logMessage(
      "Trying to connecting ${widget.device.name ?? 'Unknown Device'}...",
      color: Colors.black,
    );
    _checkConnectionStatus();
    _startReadOperation();
  }

  // void _logMessage(String message, {Color color = Colors.white70}) {
  //   final timestamp = DateTime.now().toLocal().toString().split('.')[0];
  //   if (_logs.contains(message)) return;
  //
  //   setState(() {
  //     _logs.add("$timestamp - $message");
  //   });
  //
  //   // Scroll to the bottom when a new log is added
  //   Future.delayed(Duration(milliseconds: 100), () {
  //     if (_scrollController.hasClients) {
  //       _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  //     }
  //   });
  // }

  void _logMessage(String message, {Color? color}) {
    final timestamp = DateTime.now().toLocal().toString().split('.')[0];

    if (_logs.contains(message)) return;

    setState(() {
      _logs.add("$timestamp - $message");
      // Optionally handle the color if it's provided
      if (color != null) {
        _logColors.add(color); // Store the custom color if provided
      } else {
        _logColors.add(
          Colors.white70,
        ); // Use default color if no color is provided
      }
    });

    // Scroll to the bottom when a new log is added
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _checkConnectionStatus() async {
    const int maxRetries = 5; // Maximum number of retries
    const Duration retryDelay = Duration(seconds: 2); // Delay between retries
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _connection = await FlutterBlueClassic().connect(widget.device.address);

        if (_connection != null && _connection!.isConnected) {
          setState(() {
            _isConnected = true;
          });
          _logMessage(
            "Connected to ${widget.device.name ?? 'Unknown Device'}",
            color: Colors.black,
          );
          _startReadOperation();
          await writeDataAndVerify();

          return; // Exit the loop on successful connection
        }
      } on PlatformException catch (e) {
        // _logMessage("PlatformException occurred: $e");
      } catch (e) {
        // _logMessage("Connection failed: $e");
      }

      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(retryDelay); // Wait before the next retry
      }
    }

    _logMessage(
      "Failed to connect after $maxRetries attempts.",
      color: Colors.red,
    );
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _connection?.close();
      setState(() {
        _isConnected = false;
        _connection = null;
      });
      _logMessage(
        "Disconnected from ${widget.device.name ?? 'Unknown Device'}",
        color: Colors.black,
      );
    } else {
      _logMessage(
        "Reconnecting to ${widget.device.name ?? 'Unknown Device'}...",
        color: Colors.black,
      );
      _checkConnectionStatus();
    }
  }

  // Save the SSID data
  void _saveInputData() {
    setState(() {
      _savedData = _ssidController.text.trim(); // Save the SSID
    });
    print("saveddata:${_savedData}");
    // _logMessage("$_savedData");
    _ssidController.clear(); // Optionally clear the SSID field after saving
  }

  Future<void> writeDataAndVerify() async {
    try {
      if (_savedData.isEmpty) {
        throw Exception("No data saved to write.");
      }

      print("Checking connection status...");
      if (_connection == null || !_connection!.isConnected) {
        throw Exception("Device is not connected.");
      }

      // Append '\n' to the saved SSID for sending
      String dataToSend = "$_savedData\n";
      print("Data after appending newline: $dataToSend");

      // Send data to the device (we're just sending the SSID here)
      _connection!.output.add(Uint8List.fromList(utf8.encode(dataToSend)));
      await _connection!.output.allSent; // Ensures all data is sent
      print("Data successfully sent to device: $dataToSend");

      // Wait for a short delay
      await Future.delayed(Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();
      // String formattedData = '$_savedData';
      String formattedData = '$_savedData';

      await prefs.setString("writeData", formattedData);
      print("_connection!.address${_connection!.address}");

      // Update the UI with the saved SSID
      setState(() {
        writeData = formattedData;
        _fabColor = Colors.green;
        // Dark Green
        ; // Set the color to green for success
      });
      print("formattedData:${formattedData}");
      // Add to logs
      _logMessage("$formattedData", color: Colors.blue);
      if (_connection != null && _connection!.isConnected) {
        print("Device remains connected: ${_connection!.isConnected}");
      } else {
        // If the connection is lost, attempt to reconnect
        print("Device disconnected. Attempting to reconnect...");
        await _checkConnectionStatus();
      }

      // After the write operation, ensure the connection stays true
      // if (_connection != null && _connection!.isConnected) {
      //   setState(() {
      //     // Keep the connection status true
      //     _isConnected = true;
      //     // Optionally, update the UI to show connection status
      //   });
      //   print("Device remains connected: ${_connection!.isConnected}");
      // }
    } catch (e) {
      print("Error during write operation: $e");
      // _logMessage("Error during write operation: $e");
      // _logMessage(" ");
    }
  }

  // Start listening for incoming data from the device
  // Function to start the BLE read operation and log the data
  // Start listening for incoming data from the device
  void _startReadOperation() {
    print("Initializing BLE read operation...");

    // Ensure the Bluetooth connection is established
    if (_connection != null && _connection!.isConnected) {
      print("Bluetooth connection is active.");

      // Listen to the input stream for incoming data from the device
      _connection!.input!.listen(
        (data) {
          if (data.isNotEmpty) {
            // Convert the data to a string (decoding the byte data)
            // String receivedData = utf8.decode(data);
            final String receivedData = utf8.decode(data).trim();

            print("Received chunk: $receivedData");

            // Append the received chunk to the buffer
            _receivedDataBuffer += receivedData;
            if (_isFullWord(receivedData)) {
              String completeWord = _receivedDataBuffer.trim();
              _processAndSendWord(completeWord);
              _receivedDataBuffer = '';
            }
          } else {
            print("Received empty data chunk");
          }
        },
        onError: (error) {
          print("Error in data stream: $error");
        },
        onDone: () {
          print("Data stream closed.");
        },
      );
    } else {
      print(
        "Bluetooth connection is not active. Please ensure it is connected.",
      );
    }
  }

  bool _isFullWord(String receivedData) {
    return receivedData.isNotEmpty && receivedData.length > 1;
  }

  void _processAndSendWord(String word) async {
    print("Finalized word: $word");
    _logMessage("$word", color: Colors.greenAccent);
    // await saveDataToPreferences("latest_ble_data", formattedData);
  }

  Future<void> _saveDataToPreferences(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("latest_ble_data", data);
    print("Saved data to preferences: $data");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: const Color.fromARGB(
            255,
            28,
            56,
            139,
          ), // change your color here
        ),
        backgroundColor: Colors.white,
        title: Text(
          "Terminal",
          style: TextStyle(color: const Color.fromARGB(255, 28, 56, 139)),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: Color.fromARGB(255, 28, 56, 139),
            ),
            onPressed: _toggleConnection,
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          return true; // Allow navigation without disconnecting
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: const Color.fromARGB(255, 235, 235, 235),
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Attach the scroll controller
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final reversedIndex =
                        _logs.length -
                        1 -
                        index; // Reverse the index to display messages from bottom to top
                    final log = _logs[reversedIndex];
                    // final log = _logs[index];
                    final splitLog = log.split(
                      ' - ',
                    ); // Split into timestamp and message
                    final timestamp = splitLog[0];
                    final message = splitLog.length > 1 ? splitLog[1] : '';
                    final color =
                        _logColors[reversedIndex]; // Get the color for the log message

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "$timestamp - ",
                              style: TextStyle(
                                color: Color.fromARGB(255, 28, 56, 139),
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: message,
                              style: TextStyle(color: color, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final ssid = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WritePage()),
                      );

                      // .then((value) {
                      //   // Check if the connection is still active when returning
                      //   if (_connection != null && _connection!.isConnected) {
                      //     setState(() {
                      //       _isConnected = true;
                      //       // Keep the connection status intact
                      //     });
                      //   }
                      // }
                      // );

                      if (ssid != null && ssid is String) {
                        _ssidController.text = ssid; // Update the SSID field
                      }
                    },
                    child: Text("SSID"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 28, 56, 139),
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // SSID Button to navigate to WritePage
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.start,
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   children: [
            //     ElevatedButton(
            //       onPressed: () async {
            //         final ssid = await Navigator.push(
            //           context,
            //           MaterialPageRoute(
            //             builder: (context) => WritePage(),
            //           ),
            //         );

            //         // .then((value) {
            //         //   // Check if the connection is still active when returning
            //         //   if (_connection != null && _connection!.isConnected) {
            //         //     setState(() {
            //         //       _isConnected = true;
            //         //       // Keep the connection status intact
            //         //     });
            //         //   }
            //         // }
            //         // );

            //         if (ssid != null && ssid is String) {
            //           _ssidController.text = ssid; // Update the SSID field
            //         }
            //       },
            //       child: Text("SSID"),
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: Color.fromARGB(255, 28, 56, 139),
            //         foregroundColor: Colors.white,
            //         elevation: 5,
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(0),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            // Input Field and Send Button
            Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.black),
                      controller: _ssidController,
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                          ), // Bottom border color
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                          ), // Bottom border color when focused
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  FloatingActionButton(
                    backgroundColor: Color.fromARGB(255, 28, 56, 139),
                    onPressed: () {
                      _saveInputData(); // Save data
                      writeDataAndVerify(); // Write data after saving
                    },
                    child: Icon(Icons.send, color: Colors.white),
                    mini: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
