import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RemoteClientApp());
}

class RemoteClientApp extends StatelessWidget {
  const RemoteClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MobileClientPage(),
    );
  }
}

class MobileClientPage extends StatefulWidget {
  const MobileClientPage({super.key});

  @override
  State<MobileClientPage> createState() => _MobileClientPageState();
}

class _MobileClientPageState extends State<MobileClientPage> {
  Socket? _socket;
  RawDatagramSocket? _discoverySocket;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(text: "1234");
  final TextEditingController _keyboardController = TextEditingController(text: "\u200B");
  bool _isConnected = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  List<String> discoveredServers = [];
  String? _lastConnectedIp;

  static const int serverPort = 4040;

  @override
  void initState() {
    super.initState();
    _loadLastIp();
    _startDiscovery();
  }

  void _loadLastIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastConnectedIp = prefs.getString('last_ip');
    });
  }

  void _saveLastIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ip', ip);
    setState(() {
      _lastConnectedIp = ip;
    });
  }

  @override
  void dispose() {
    _socket?.destroy();
    _discoverySocket?.close();
    _keyboardController.dispose();
    super.dispose();
  }

  void _startDiscovery() async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 4041);
      _discoverySocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _discoverySocket?.receive();
          if (dg != null) {
            final message = utf8.decode(dg.data);
            if (message.startsWith("REMOTE_SERVER:")) {
              final serverIp = message.substring(14);
              if (!discoveredServers.contains(serverIp)) {
                setState(() {
                  discoveredServers.add(serverIp);
                  if (_ipController.text.isEmpty) _ipController.text = serverIp;
                });
              }
            }
          }
        }
      });
    } catch (e) {
      print("Discovery error: $e");
    }
  }

  void _connect([String? ip]) async {
    final targetIp = ip ?? _ipController.text;
    try {
      _socket = await Socket.connect(targetIp, serverPort, timeout: const Duration(seconds: 5));
      _socket?.setOption(SocketOption.tcpNoDelay, true);
      _saveLastIp(targetIp);
      setState(() {
        _isConnected = true;
        _ipController.text = targetIp;
      });
      _sendCommand("AUTH:${_passwordController.text}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to connect: $e")));
    }
  }

  void _sendCommand(String cmd) {
    if (_isConnected) {
      if (cmd == "KEY:Play") {
        setState(() => _isPlaying = !_isPlaying);
      } else if (cmd == "KEY:Mute") {
        setState(() => _isMuted = !_isMuted);
      }
      _socket?.write("$cmd\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Windows Remote"),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (!_isConnected) ...[
              if (_lastConnectedIp != null) ...[
                Card(
                  color: Colors.blueGrey[900],
                  child: ListTile(
                    title: const Text("Last Connected:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    subtitle: Text(_lastConnectedIp!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    leading: const Icon(Icons.history, color: Colors.blue),
                    onTap: () => _connect(_lastConnectedIp),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (discoveredServers.isNotEmpty) ...[
                const Text("Discovered Servers:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...discoveredServers.map((ip) => ListTile(
                  title: Text(ip),
                  leading: const Icon(Icons.computer),
                  onTap: () => _connect(ip),
                )),
                const Divider(),
              ],
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: "Server IP", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _connect(),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), textStyle: const TextStyle(fontSize: 18)),
                child: const Text("Connect Manually")
              ),
            ] else ...[
              // Touchpad & Scroll Bar Area
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Touchpad
                    Expanded(
                      child: GestureDetector(
                        onPanUpdate: (d) => _sendCommand("MOVE:${d.delta.dx},${d.delta.dy}"),
                        onTap: () => _sendCommand("CLICK"),
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[700]!)
                          ),
                          child: const Center(child: Icon(Icons.touch_app, size: 40, color: Colors.blue)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Scroll Bar
                    GestureDetector(
                      onVerticalDragUpdate: (d) => _sendCommand("SCROLL:${d.delta.dy.toStringAsFixed(0)}"),
                      child: Container(
                        width: 50,
                        decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[800]!)
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_drop_up, color: Colors.grey),
                            Icon(Icons.unfold_more, color: Colors.blue),
                            Text("SCROLL", style: TextStyle(fontSize: 9, color: Colors.grey)),
                            Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // Special Windows Keys Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                child: const Column(
                  children: [
                    KeyboardRow(keys: ['Prev', 'Play', 'Next', 'Mute', 'Vol-', 'Vol+']),
                    KeyboardRow(keys: ['Esc', 'Win', 'Shift', 'Del', 'Back']),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              
              // Standard Android Keyboard Input
              TextField(
                controller: _keyboardController,
                onChanged: (text) {
                  if (text.length < 1) {
                    // Backspace detected (invisible character was deleted)
                    _sendCommand("KEY:Back");
                    _keyboardController.text = "\u200B";
                    _keyboardController.selection = TextSelection.fromPosition(const TextPosition(offset: 1));
                  } else if (text.length > 1) {
                    // Character typed (text is now "\u200B" + new char)
                    String char = text.substring(1);
                    if (char == " ") {
                      _sendCommand("KEY:Space");
                    } else {
                      _sendCommand("KEY:$char");
                    }
                    _keyboardController.text = "\u200B";
                    _keyboardController.selection = TextSelection.fromPosition(const TextPosition(offset: 1));
                  }
                },
                decoration: const InputDecoration(
                  hintText: "Tap here to type...",
                  prefixIcon: Icon(Icons.keyboard),
                  border: OutlineInputBorder(),
                  fillColor: Colors.black26,
                  filled: true,
                ),
              ),
              
              TextButton(
                  onPressed: () => setState(() => _isConnected = false),
                  style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 18)),
                  child: const Text("Disconnect", style: TextStyle(color: Colors.red))
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class KeyboardRow extends StatelessWidget {
  final List<String> keys;
  const KeyboardRow({super.key, required this.keys});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) => KeyboardKey(label: key)).toList(),
      ),
    );
  }
}

class KeyboardKey extends StatelessWidget {
  final String label;
  const KeyboardKey({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_MobileClientPageState>();

    Widget buildKeyContent() {
      switch (label) {
        case 'Prev':
          return const Icon(Icons.skip_previous, color: Colors.white);
        case 'Play':
          return Icon(
            state?._isPlaying ?? false ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          );
        case 'Next':
          return const Icon(Icons.skip_next, color: Colors.white);
        case 'Mute':
          return Icon(
            state?._isMuted ?? false ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          );
        case 'Vol-':
          return const Icon(Icons.volume_down, color: Colors.white);
        case 'Vol+':
          return const Icon(Icons.volume_up, color: Colors.white);
        default:
          return Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          );
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => state?._sendCommand("KEY:$label"),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, offset: Offset(0, 1), blurRadius: 1),
            ],
          ),
          child: Center(
            child: buildKeyContent(),
          ),
        ),
      ),
    );
  }
}
