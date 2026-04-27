import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/speech_service.dart';
import 'ui/screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Error loading .env file: $e");
  }

  // Initialize Speech Service early
  await SpeechService().init();

  runApp(const WareneApp());
}

class WareneApp extends StatelessWidget {
  const WareneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warene',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const PermissionGate(),
    );
  }
}

// ── Permission gate ─────────────────────────────────────────────────
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
    final cameraOk = await Permission.camera.isGranted;
    final micOk = await Permission.microphone.isGranted;

    if (!mounted) return;

    if (cameraOk && micOk) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } else {
      setState(() {
        _checking = false;
        _denied = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _checking
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 16),
                  Text(
                    'جاري التحقق من الأذونات...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 64),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'وريني يحتاج صلاحية الكاميرا\nوالميكروفون ليعمل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _checking = true);
                      _requestPermissions();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('حاول تاني'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text(
                      'افتح الإعدادات',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}