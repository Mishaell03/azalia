import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/backend/services/session.dart';

class AppStartPage extends StatefulWidget {
  const AppStartPage({super.key});

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage>
    with SingleTickerProviderStateMixin {
  final SessionService _session = SessionService();

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация плавного появления
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Даем интерфейсу немного «подышать»
      await Future.delayed(const Duration(seconds: 8));

      await _session.initialize();

      if (!mounted) return;

      if (_session.isLoggedIn && _session.isTokenValid) {
        context.go('/');
      } else {
        context.go('/auth');
      }
    } catch (e) {
      debugPrint('AppStart error: $e');
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset('assets/images/start.jpg', fit: BoxFit.cover),
          ),

          Container(color: AppColors.black_transparent.withOpacity(0.3)),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white_transparent.withOpacity(0.15),
                    ),
                    child: Image.asset(
                      'assets/images/cactus.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'Azalia',
                    style: AppText.semibold_28.copyWith(
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.black.withOpacity(0.7),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsetsGeometry.symmetric(horizontal: 24),
                    child: Text(
                      'Приложение для идеальных подарков и украшения вашего сада',
                      textAlign: TextAlign.center,
                      style: AppText.medium_18.copyWith(
                        color: AppColors.white,
                        shadows: [
                          Shadow(
                            color: AppColors.grey.withOpacity(0.5),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  const CircularProgressIndicator(color: AppColors.grey_light),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
