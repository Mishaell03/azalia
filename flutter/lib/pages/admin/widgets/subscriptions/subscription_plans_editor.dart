import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/models/admin_subscription_plan.dart';
import 'package:azalia/backend/services/admin_subscription_plans.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';

class AdminSubscriptionPlansEditor extends StatefulWidget {
  const AdminSubscriptionPlansEditor({super.key});

  @override
  State<AdminSubscriptionPlansEditor> createState() =>
      _AdminSubscriptionPlansEditorState();
}

class _AdminSubscriptionPlansEditorState
    extends State<AdminSubscriptionPlansEditor> {
  final AdminSubscriptionPlansService _service = AdminSubscriptionPlansService(
    ApiClient(),
  );

  bool _isLoading = true;
  String? _error;
  List<AdminSubscriptionPlan> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plans = await _service.getPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки подписок: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyUpdated(AdminSubscriptionPlan updated) {
    final index = _plans.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;
    setState(() {
      final next = _plans.toList();
      next[index] = updated;
      _plans = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: AppText.medium_14.copyWith(color: AppColors.error),
        ),
      );
    }
    if (_plans.isEmpty) {
      return Center(
        child: Text(
          'Подписки не найдены',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey_light),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plan.name} (${plan.code})',
                        style: AppText.bold_18.copyWith(color: AppColors.black),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final updated = await showDialog<AdminSubscriptionPlan>(
                          context: context,
                          builder: (_) =>
                              _EditPlanDialog(plan: plan, service: _service),
                        );
                        if (updated != null) {
                          _applyUpdated(updated);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.brown,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Месяц: ${plan.monthlyPrice.toStringAsFixed(0)} ₽ • Год: ${plan.yearlyPrice.toStringAsFixed(0)} ₽',
                  style: AppText.medium_14.copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Растений: ${plan.maxPlants} • Участников: ${plan.maxMembers}',
                  style: AppText.medium_12.copyWith(color: AppColors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.isActive ? 'Активен' : 'Отключен',
                  style: AppText.medium_12.copyWith(
                    color: plan.isActive ? AppColors.success : AppColors.error,
                  ),
                ),
                if (plan.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    plan.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.medium_12.copyWith(color: AppColors.black),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditPlanDialog extends StatefulWidget {
  final AdminSubscriptionPlan plan;
  final AdminSubscriptionPlansService service;

  const _EditPlanDialog({required this.plan, required this.service});

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _monthlyPriceController;
  late final TextEditingController _yearlyPriceController;
  late final TextEditingController _maxPlantsController;
  late final TextEditingController _maxMembersController;
  late final TextEditingController _featuresController;

  late String _notifications;
  late bool _isActive;
  late bool _hasCorporate;
  late bool _canCreateCompany;
  late bool _hasAnalytics;
  late bool _hasExtendedFeatures;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameController = TextEditingController(text: plan.name);
    _descriptionController = TextEditingController(text: plan.description);
    _monthlyPriceController = TextEditingController(
      text: plan.monthlyPrice.toStringAsFixed(
        plan.monthlyPrice % 1 == 0 ? 0 : 2,
      ),
    );
    _yearlyPriceController = TextEditingController(
      text: plan.yearlyPrice.toStringAsFixed(plan.yearlyPrice % 1 == 0 ? 0 : 2),
    );
    _maxPlantsController = TextEditingController(text: '${plan.maxPlants}');
    _maxMembersController = TextEditingController(text: '${plan.maxMembers}');
    _featuresController = TextEditingController(text: plan.features.join('\n'));
    _notifications = plan.notifications;
    _isActive = plan.isActive;
    _hasCorporate = plan.hasCorporate;
    _canCreateCompany = plan.canCreateCompany;
    _hasAnalytics = plan.hasAnalytics;
    _hasExtendedFeatures = plan.hasExtendedFeatures;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _monthlyPriceController.dispose();
    _yearlyPriceController.dispose();
    _maxPlantsController.dispose();
    _maxMembersController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final monthly = double.tryParse(
      _monthlyPriceController.text.trim().replaceAll(',', '.'),
    );
    final yearly = double.tryParse(
      _yearlyPriceController.text.trim().replaceAll(',', '.'),
    );
    final maxPlants = int.tryParse(_maxPlantsController.text.trim());
    final maxMembers = int.tryParse(_maxMembersController.text.trim());

    if (_nameController.text.trim().isEmpty ||
        monthly == null ||
        yearly == null ||
        maxPlants == null ||
        maxMembers == null ||
        maxPlants < 1 ||
        maxMembers < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Проверьте заполнение полей',
            style: AppText.medium_14.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final features = _featuresController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await widget.service.updatePlan(
        planId: '${widget.plan.id}',
        payload: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'monthly_price': monthly,
          'yearly_price': yearly,
          'max_plants': maxPlants,
          'max_members': maxMembers,
          'notifications': _notifications,
          'has_corporate': _hasCorporate,
          'can_create_company': _canCreateCompany,
          'has_analytics': _hasAnalytics,
          'has_extended_features': _hasExtendedFeatures,
          'is_active': _isActive,
          'features': features,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка сохранения: $e',
            style: AppText.medium_14.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      title: Text(
        'Редактирование тарифа',
        style: AppText.bold_18.copyWith(color: AppColors.black),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название тарифа',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _monthlyPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Цена в месяц',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _yearlyPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Цена в год',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxPlantsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Лимит растений',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxMembersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Лимит участников',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _notifications,
                decoration: const InputDecoration(
                  labelText: 'Тип уведомлений',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'basic', child: Text('basic')),
                  DropdownMenuItem(value: 'extended', child: Text('extended')),
                  DropdownMenuItem(value: 'smart', child: Text('smart')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _notifications = v;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _featuresController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Возможности (по одной строке)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Тариф активен'),
                activeThumbColor: AppColors.brown,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _hasCorporate,
                onChanged: (v) => setState(() => _hasCorporate = v),
                title: const Text('Корпоративный доступ'),
                activeThumbColor: AppColors.brown,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _canCreateCompany,
                onChanged: (v) => setState(() => _canCreateCompany = v),
                title: const Text('Можно создавать компанию'),
                activeThumbColor: AppColors.brown,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _hasAnalytics,
                onChanged: (v) => setState(() => _hasAnalytics = v),
                title: const Text('Доступ к аналитике'),
                activeThumbColor: AppColors.brown,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _hasExtendedFeatures,
                onChanged: (v) => setState(() => _hasExtendedFeatures = v),
                title: const Text('Расширенные функции'),
                activeThumbColor: AppColors.brown,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            side: const BorderSide(color: AppColors.brown),
          ),
          child: Text(
            'Отмена',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          style: TextButton.styleFrom(backgroundColor: AppColors.brown),
          child: Text(
            _isSaving ? 'Сохранение...' : 'Сохранить',
            style: AppText.medium_14.copyWith(
              color: AppColors.white_transparent,
            ),
          ),
        ),
      ],
    );
  }
}
