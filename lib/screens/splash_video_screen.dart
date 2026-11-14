import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:video_player/video_player.dart';
import '../main.dart' show AuthGate;
import '../utils/constants.dart'; // أو استبدله بلونAppColors.primary الخاص بك

// ── شاشة الفيديو الافتتاحية ─────────────────────────────
class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setVolume(0); // فيديو خلفية بدون صوت
        _controller.play();

        // 🟢 إزالة الشاشة الناتيف فقط بعد جاهزية إطارات الفيديو للعرض
        FlutterNativeSplash.remove();
      });

    _controller.addListener(_onVideoTick);

    // أمان: لو تعطل الفيديو لأي سبب ينقل للمستخدم ويزيل الشاشة الناتيف
    Future.delayed(const Duration(seconds: 6), () {
      FlutterNativeSplash.remove();
      _goNext();
    });
  }

  void _onVideoTick() {
    final v = _controller.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AuthGate(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // جعل الخلفية مطابقة للهوية البصرية (اللون الأزرق أو الأسود) يمنع الفلاش الأبيض
      backgroundColor: AppColors.primary,
      body: GestureDetector(
        onTap: _goNext,
        child: _controller.value.isInitialized
            ? SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        )
            : const SizedBox.shrink(), // لا داعي لعرض مؤشر تحميل بياني لأن الشاشة الناتيف تغطيه
      ),
    );
  }
}