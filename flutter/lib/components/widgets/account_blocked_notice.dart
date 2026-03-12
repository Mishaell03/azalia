import 'package:azalia/backend/services/device_id.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';

class AccountBlockedNotice extends StatelessWidget {
  final bool compact;

  const AccountBlockedNotice({super.key, this.compact = false});

  Future<void> _openSupport(BuildContext context) async {
    final ok = await DeviceService.launchTelegramSupport();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть Telegram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.not_interested, size: 40 , color: AppColors.brown),
            const SizedBox(height: 10),
            Text(
              'Аккаунт удален или деактивирован',
              textAlign: TextAlign.center,
              style: AppText.bold_20.copyWith(color: AppColors.brown),
            ),
            const SizedBox(height: 10),
            Text(
              'Обратитесь в поддержку',
              textAlign: TextAlign.center,
              style: AppText.medium_14.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openSupport(context),
                icon: const Icon(Icons.telegram, size: 30),
                label: Text('Открыть Telegram-бота', style: AppText.medium_16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brown,
                  side: const BorderSide(color: AppColors.brown),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
