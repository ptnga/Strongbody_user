import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/strongbody_logo.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';

/// Màn chờ khi mở app (như Multime `SplashScreen`): nền trắng, logo ở giữa,
/// giữ tối thiểu [minDuration] rồi `go` về Home.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const minDuration = Duration(seconds: 2);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
  late final _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashPage.minDuration, () {
      if (mounted) context.go(RouteName.rootScreen);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colour.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: StrongBodyLogo(height: 44.r),
          ),
        ),
      ),
    );
  }
}
