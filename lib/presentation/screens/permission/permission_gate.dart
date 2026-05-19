import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/reusable/app_loading_view.dart';
import '../camera_screen.dart';

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;

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
      return;
    }

    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _checking
            ? const AppLoadingView(message: 'جاري التحقق من الأذونات...')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryText,
                    size: 64,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'وريني يحتاج صلاحية الكاميرا\nوالميكروفون ليعمل.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.permissionMessage,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _checking = true);
                      _requestPermissions();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('حاول تاني'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text(
                      'افتح الإعدادات',
                      style: AppTextStyles.permissionSecondaryAction,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
