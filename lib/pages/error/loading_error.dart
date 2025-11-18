import 'package:flutter/material.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/colors.dart';

class GenericErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const GenericErrorWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/error.png',
                      fit: BoxFit.contain,
                      width: 250,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Что-то пошло не так',
                      textAlign: TextAlign.center,
                      style: AppText.medium_20.copyWith(color: AppColors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Перезагрузить', style: AppText.bold_15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final Color? color;

  const LoadingWidget({
    super.key,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth!,
          valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.brown),
        ),
      ),
    );
  }
}

class ErrorWidgetWithRetry extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final double? height;

  const ErrorWidgetWithRetry({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage,
              style: AppText.medium_16.copyWith(color: AppColors.grey),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final double? height;

  const EmptyStateWidget({super.key, required this.message, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          style: AppText.medium_16.copyWith(color: AppColors.grey),
        ),
      ),
    );
  }
}

class LoadingMoreIndicator extends StatelessWidget {
  const LoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: LoadingWidget(size: 24, strokeWidth: 2),
    );
  }
}
