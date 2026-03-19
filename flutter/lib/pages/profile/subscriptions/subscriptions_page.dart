import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/subscriptions.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/profile/subscriptions/subscription_checkout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class _RuPhoneMaskFormatter extends TextInputFormatter {
  static const int _maxNationalDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    var national = rawDigits;
    if (national.startsWith('7') || national.startsWith('8')) {
      national = national.substring(1);
    }
    if (national.length > _maxNationalDigits) {
      national = national.substring(0, _maxNationalDigits);
    }

    final full = '7$national';
    final b = StringBuffer('+7');
    if (full.length > 1) {
      b.write(' (');
      b.write(full.substring(1, full.length > 4 ? 4 : full.length));
    }
    if (full.length > 4) {
      b.write(') ');
      b.write(full.substring(4, full.length > 7 ? 7 : full.length));
    }
    if (full.length > 7) {
      b.write('-');
      b.write(full.substring(7, full.length > 9 ? 9 : full.length));
    }
    if (full.length > 9) {
      b.write('-');
      b.write(full.substring(9, full.length > 11 ? 11 : full.length));
    }

    final formatted = b.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final _phoneFormatter = _RuPhoneMaskFormatter();

  bool _isLoading = true;
  bool _corporateLoading = false;
  String? _error;
  List<SubscriptionPlanDto> _plans = const [];
  String _currentPlanId = 'free';
  CorporateSubscriptionStateDto? _corporateState;

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
      await _loadCorporateState(silent: true);
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

  bool get _canManageCorporate {
    final current = _getCurrentPlan();
    if (current == null) return false;
    return current.hasCorporate || current.canCreateCompany;
  }

  Future<void> _loadCorporateState({bool silent = false}) async {
    if (!_canManageCorporate) {
      if (mounted) {
        setState(() => _corporateState = null);
      }
      return;
    }
    if (!silent && mounted) {
      setState(() => _corporateLoading = true);
    }
    try {
      final state = await SubscriptionService.getCorporateState();
      if (!mounted) return;
      setState(() => _corporateState = state);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              'Не удалось загрузить корпоративные данные: $e',
              style: AppText.medium_14.copyWith(color: AppColors.error),
            ),
          ),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _corporateLoading = false);
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
      if (!mounted) return;
      await _loadCorporateState(silent: true);
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

  String? _normalizePhoneForApi(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.length == 10) {
      digits = '7$digits';
    }
    if (digits.length != 11 || !digits.startsWith('7')) {
      return null;
    }
    return '+7${digits.substring(1)}';
  }

  bool _isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
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
            style: TextButton.styleFrom(
              side: const BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Нет',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Да',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
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
      await _loadCorporateState(silent: true);
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
      await _loadCorporateState(silent: true);
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

  Future<void> _openCreateCompanyDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать компанию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название компании',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneFormatter],
                decoration: const InputDecoration(
                  labelText: 'Контактный телефон',
                  hintText: '+7 (999) 999-99-99',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Контактный email',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Адрес'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              side: const BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Отмена',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Создать',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
        ],
      ),
    );
    if (save != true) return;

    final name = nameCtrl.text.trim();
    final emailRaw = emailCtrl.text.trim();
    final normalizedPhone = _normalizePhoneForApi(phoneCtrl.text.trim());

    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Название компании обязательно',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    if (phoneCtrl.text.trim().isNotEmpty && normalizedPhone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Введите телефон полностью: +7 (XXX) XXX-XX-XX',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    if (emailRaw.isNotEmpty && !_isValidEmail(emailRaw)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Введите корректный email',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
      return;
    }

    try {
      final state = await SubscriptionService.createCorporateCompany(
        name: name,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        contactPhone: normalizedPhone,
        contactEmail: emailRaw.isEmpty ? null : emailRaw,
        address: addressCtrl.text.trim().isEmpty
            ? null
            : addressCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _corporateState = state);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Компания создана. Теперь можно добавлять пользователей.',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            e.message,
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Ошибка создания компании: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Future<void> _openAddMemberDialog(CorporateCompanyDto company) async {
    final phoneCtrl = TextEditingController();
    final userIdCtrl = TextEditingController();
    String addMode = 'phone';
    String role = 'member';
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Добавить пользователя'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: addMode,
                items: const [
                  DropdownMenuItem(
                    value: 'phone',
                    child: Text('По номеру телефона'),
                  ),
                  DropdownMenuItem(
                    value: 'id',
                    child: Text('По ID пользователя'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() => addMode = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Способ добавления',
                ),
              ),
              const SizedBox(height: 8),
              if (addMode == 'phone')
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Телефон пользователя',
                    hintText: '+7 (999) 999-99-99',
                  ),
                )
              else
                TextField(
                  controller: userIdCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'ID пользователя',
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Участник')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Администратор'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() => role = v);
                },
                decoration: const InputDecoration(labelText: 'Роль'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                side: const BorderSide(color: AppColors.brown),
              ),
              child: Text(
                'Отмена',
                style: AppText.medium_14.copyWith(color: AppColors.brown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(backgroundColor: AppColors.brown),
              child: Text(
                'Добавить',
                style: AppText.medium_14.copyWith(
                  color: AppColors.white_transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;

    final normalizedPhone = _normalizePhoneForApi(phoneCtrl.text.trim());
    final userId = int.tryParse(userIdCtrl.text.trim());

    if (addMode == 'phone' && normalizedPhone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Введите корректный номер: +7 (XXX) XXX-XX-XX',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
      return;
    }
    if (addMode == 'id' && (userId == null || userId <= 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Введите корректный ID пользователя',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
      return;
    }

    try {
      final state = await SubscriptionService.addCorporateMember(
        companyId: company.id,
        userId: addMode == 'id' ? userId : null,
        userPhone: addMode == 'phone' ? normalizedPhone : null,
        role: role,
      );
      if (!mounted) return;
      setState(() => _corporateState = state);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Пользователь добавлен',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            e.message,
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Ошибка добавления: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Future<void> _removeMember(
    CorporateCompanyDto company,
    CorporateMemberDto member,
  ) async {
    try {
      final state = await SubscriptionService.removeCorporateMember(
        userId: member.userId,
        companyId: company.id,
      );
      if (!mounted) return;
      setState(() => _corporateState = state);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            e.message,
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Ошибка удаления: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Widget _buildCorporateSection() {
    final state = _corporateState;
    final company = state?.company;
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
          Text(
            'Корпоративная подписка',
            style: AppText.bold_20.copyWith(color: AppColors.black),
          ),
          const SizedBox(height: 8),
          if (_corporateLoading)
            const Center(child: CircularProgressIndicator())
          else if (company == null) ...[
            Text(
              'Компания ещё не создана. Создайте компанию, чтобы добавлять пользователей в корпоративную подписку.',
              style: AppText.medium_14.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brown,
                ),
                onPressed: _openCreateCompanyDialog,
                icon: const Icon(Icons.apartment, color: AppColors.white),
                label: Text(
                  'Создать компанию',
                  style: AppText.medium_14.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ] else ...[
            Text(company.name, style: AppText.bold_18),
            const SizedBox(height: 4),
            Text(
              company.description?.isNotEmpty == true
                  ? company.description!
                  : 'Описание не указано',
              style: AppText.medium_12.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Участники: ${state?.currentMembers ?? 0} / ${state?.maxMembers ?? 1}',
              style: AppText.medium_14.copyWith(color: AppColors.black),
            ),
            if (company.isOrganizer) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (state?.canAddMore ?? false)
                      ? () => _openAddMemberDialog(company)
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brown),
                  ),
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    color: AppColors.brown,
                  ),
                  label: const Text('Добавить пользователя'),
                ),
              ),
              if (!(state?.canAddMore ?? true))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Достигнут лимит участников для текущего тарифа',
                    style: AppText.medium_12.copyWith(color: AppColors.error),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            ...(state?.members ?? const <CorporateMemberDto>[]).map(
              (member) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.white_dark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.fullName, style: AppText.medium_14),
                          const SizedBox(height: 2),
                          Text(
                            '${member.phone} • ${member.role}',
                            style: AppText.medium_12.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (company.isOrganizer && member.role != 'owner')
                      IconButton(
                        onPressed: () => _removeMember(company, member),
                        icon: const Icon(
                          Icons.person_remove,
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
                if (index == _plans.length) {
                  return _buildCorporateSection();
                }
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
                            side: BorderSide(color: isFree ? AppColors.grey_light : AppColors.brown),
                            backgroundColor: isActive
                                ? (isFree
                                      ? AppColors.white_transparent
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
              itemCount: _plans.length + (_canManageCorporate ? 1 : 0),
            ),
    );
  }
}
