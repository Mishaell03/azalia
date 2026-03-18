import 'package:azalia/backend/services/subscriptions.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/profile/subscriptions/subscription_checkout_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  bool _isLoading = true;
  String? _error;
  List<SubscriptionPlanDto> _plans = const [];
  String _currentPlanId = 'free';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await SubscriptionService.getPlans();
      if (!mounted) return;
      setState(() {
        _plans = response.items;
        _currentPlanId = response.currentPlanId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить тарифы: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onPayTap(SubscriptionPlanDto plan) async {
    try {
      final checkout = await SubscriptionService.createCheckout(
        planId: plan.id,
      );
      if (!mounted) return;
      await context.pushNamed(
        'profileSubscriptionCheckout',
        extra: SubscriptionCheckoutPageArgs(
          checkoutId: checkout.checkoutId,
          paymentUrl: checkout.paymentUrl,
          planName: plan.name,
        ),
      );
      if (!mounted) return;
      await _loadPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось создать ссылку на оплату: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  SubscriptionPlanDto? _getCurrentPlan() {
    for (final plan in _plans) {
      if (plan.id == _currentPlanId || plan.isCurrent) {
        return plan;
      }
    }
    return null;
  }

  Future<bool> _confirmDisableDialog({String? currentPlanName}) async {
    final withName =
        currentPlanName != null && currentPlanName.trim().isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text(
          withName
              ? 'Вы точно хотите отключить подписку $currentPlanName?'
              : 'Вы точно хотите отключить подписку?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Нет',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              side: BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Да',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _onDisableTap(SubscriptionPlanDto plan) async {
    final confirmed = await _confirmDisableDialog();
    if (!confirmed) return;

    try {
      await SubscriptionService.cancelCurrentPlan(plan.id);
      if (!mounted) return;
      await _loadPlans();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Подписка отключена. Активирован бесплатный тариф.',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось отключить подписку: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Future<void> _onSelectFreeTap(SubscriptionPlanDto freePlan) async {
    final current = _getCurrentPlan();
    if (current == null) return;
    final currentIsFree = current.id.toLowerCase() == 'free';
    if (currentIsFree) return;

    final confirmed = await _confirmDisableDialog(
      currentPlanName: current.name,
    );
    if (!confirmed) return;

    try {
      await SubscriptionService.cancelCurrentPlan(current.id);
      if (!mounted) return;
      await _loadPlans();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Активирован бесплатный тариф',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось переключиться на бесплатный: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Future<void> _onSelectPaidTap(SubscriptionPlanDto targetPlan) async {
    final current = _getCurrentPlan();
    final currentIsFree = current == null || current.id.toLowerCase() == 'free';

    if (!currentIsFree) {
      final confirmed = await _confirmDisableDialog(
        currentPlanName: current.name,
      );
      if (!confirmed) return;
      try {
        await SubscriptionService.cancelCurrentPlan(current.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              'Не удалось отключить текущую подписку: $e',
              style: AppText.medium_14.copyWith(color: AppColors.error),
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    await _onPayTap(targetPlan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text(
          'Подписки',
          style: AppText.bold_20.copyWith(color: AppColors.black),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  style: AppText.medium_14.copyWith(color: AppColors.error),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final isActive = plan.id == _currentPlanId || plan.isCurrent;
                final isFree = plan.id.toLowerCase() == 'free';
                final current = _getCurrentPlan();
                final hasActivePaid =
                    current != null && current.id.toLowerCase() != 'free';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey_light),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brown.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Активна',
                            style: AppText.medium_12.copyWith(
                              color: AppColors.brown,
                            ),
                          ),
                        ),
                      if (isActive) const SizedBox(height: 8),
                      Text(
                        plan.name,
                        style: AppText.bold_23.copyWith(color: AppColors.black),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plan.price.toStringAsFixed(plan.price % 1 == 0 ? 0 : 2)} ₽ / месяц',
                        style: AppText.medium_20.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.description,
                        style: AppText.medium_14.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...plan.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $feature',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Растений: ${plan.maxPlants}',
                              style: AppText.medium_14.copyWith(
                                color: AppColors.black_transparent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Уведомления: ${plan.notifications}',
                              style: AppText.medium_12.copyWith(
                                color: AppColors.black_transparent,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: isActive
                              ? (isFree
                                    ? null
                                    : () async => _onDisableTap(plan))
                              : (isFree
                                    ? (hasActivePaid
                                          ? () async => _onSelectFreeTap(plan)
                                          : null)
                                    : () async => _onSelectPaidTap(plan)),
                          style: TextButton.styleFrom(
                            side: BorderSide(
                              color: isFree
                                  ? AppColors.grey_light
                                  : AppColors.brown,
                            ),
                            backgroundColor: isActive
                                ? (isFree
                                      ? AppColors.grey_light
                                      : AppColors.white_transparent)
                                : (isFree
                                      ? AppColors.grey_light
                                      : AppColors.brown),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            isActive
                                ? (isFree ? 'Активна' : 'Отключить')
                                : (isFree ? 'Выбрать бесплатно' : 'Оформить'),
                            style: AppText.medium_16.copyWith(
                              color: isActive
                                  ? AppColors.brown
                                  : AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: _plans.length,
            ),
    );
  }
}
