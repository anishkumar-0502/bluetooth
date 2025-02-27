import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WritePage extends StatefulWidget {
  // final BluetoothDevice device;
  final BluetoothConnection? connection;

  const WritePage({super.key, this.connection});
  // const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadSavedData();
  }

  _savedData(String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("username", username);
    await prefs.setString("password", password);
  }

  // Method to load saved data from shared preferences
  _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString('username');
    String? savedPassword = prefs.getString('password');

    if (savedUsername != null && savedPassword != null) {
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
    }
  }

  _handleTextChange() {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    _savedData(username, password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "SSID",
          style: TextStyle(color: Color.fromARGB(255, 28, 56, 139)),
        ),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 28, 56, 139)),
        actions: [
          TextButton.icon(
            onPressed: () {
              final username = _usernameController.text.trim();
              final password = _passwordController.text.trim();
              if (username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Username should not be empty")),
                );
              } else if (username.contains(' ')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Spaces are not allowed for user"),
                  ),
                );
              } else if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("password should not be empty")),
                );
              } else if (password.contains(' ')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Spaces are not allowed for password"),
                  ),
                );
              } else if (username.isEmpty && password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Username and password should not be empty"),
                  ),
                );
              } else {
                _savedData(username, password);
                final ssid = "SSID=$username:$password";
                print("ssid:${ssid}");
                Navigator.pop(
                  context,
                  ssid,
                ); // Pass the SSID back to the previous page
              }
            },
            label: const Text(
              "Save",
              style: TextStyle(
                color: Color.fromARGB(255, 28, 56, 139),
                fontSize: 18,
              ),
            ),
            icon: const Icon(
              Icons.check,
              color: Color.fromARGB(255, 28, 56, 139),
              size: 18,
            ),
          ),
        ],
        backgroundColor: Colors.white,
      ),
      body: WillPopScope(
        onWillPop: () async {
          return true; // Allow navigation without disconnecting
        },
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                TextField(
                  style: const TextStyle(color: Colors.black),
                  controller: _usernameController,
                  onChanged: (value) {
                    _handleTextChange();
                  },
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black,
                      ), // Bottom border color
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 28, 56, 139),
                      ), // Bottom border color when focused
                    ),
                    // hintText: "Enter your username here",
                    hintStyle: TextStyle(color: Colors.black),
                    labelText: "Username",
                    labelStyle: TextStyle(color: Colors.black, fontSize: 20),
                    floatingLabelBehavior:
                        FloatingLabelBehavior
                            .always, // Ensures both are visible
                    // border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 40),

                TextField(
                  style: const TextStyle(color: Colors.black),
                  controller: _passwordController,
                  onChanged: (value) {
                    _handleTextChange();
                  },
                  decoration: const InputDecoration(
                    // hintText: "Enter your password here",
                    hintStyle: TextStyle(color: Colors.grey),
                    labelText: "Password",
                    labelStyle: TextStyle(color: Colors.black, fontSize: 20),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black,
                      ), // Bottom border color
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 28, 56, 139),
                      ), // Bottom border color when focused
                    ),
                    floatingLabelBehavior:
                        FloatingLabelBehavior
                            .always, // Ensures both are visible
                    // border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                // ElevatedButton(
                //   onPressed: () {
                //     final username = _usernameController.text.trim();
                //     final password = _passwordController.text.trim();
                //     if (username.isNotEmpty && password.isNotEmpty) {
                //       final ssid = "SSID=$username:$password";
                //       Navigator.pop(context, ssid); // Pass the SSID back to the previous page
                //     } else {
                //       // Handle validation if fields are empty
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(content: Text("Both fields must be filled")),
                //       );
                //     }
                //   },
                //   child: Text("Save"),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
