import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/models/employeesAdmin.dart';
import 'package:azalia/backend/services/employeesAdmin.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';

class AdminUserViewData {
  final int userId;
  final String name;
  final bool canManage;

  const AdminUserViewData({
    required this.userId,
    required this.name,
    required this.canManage,
  });
}

Future<bool> showAdminUserViewDialog(
  BuildContext context, {
  required AdminUserViewData user,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => AdminUserViewDialog(user: user),
  );
  return changed ?? false;
}

class AdminUserViewDialog extends StatefulWidget {
  final AdminUserViewData user;

  const AdminUserViewDialog({super.key, required this.user});

  @override
  State<AdminUserViewDialog> createState() => _AdminUserViewDialogState();
}

class _AdminUserViewDialogState extends State<AdminUserViewDialog> {
  final EmployeesService _service = EmployeesService(ApiClient());

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _error;
  AdminUserDetails? _details;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.white,
        content: Text(
          message,
          style: AppText.medium_14.copyWith(color: AppColors.brown),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final details = await _service.getUserDetails(widget.user.userId);
      if (!mounted) return;
      setState(() {
        _details = details;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runAction(Future<AdminUserDetails> Function() action) async {
    setState(() => _isSaving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _details = updated;
        _hasChanges = true;
      });
      _showSnack('Изменения сохранены');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatPrice(double value) {
    return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ₽';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final value = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (value == null) return raw;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  String _prettyStatus(String status) {
    switch (status) {
      case 'active':
        return 'Активен';
      case 'blocked':
        return 'Заблокирован';
      case 'deleted':
        return 'Удален';
      case 'awaiting_payment':
        return 'Ожидает оплаты';
      case 'processing':
        return 'В работе';
      case 'assembled':
        return 'Собран';
      case 'shipped':
        return 'В доставке';
      case 'ready_for_pickup':
        return 'Готов к выдаче';
      case 'delivered':
        return 'Доставлен';
      case 'completed':
        return 'Завершен';
      case 'cancelled':
        return 'Отменен';
      case 'pending':
        return 'Ожидает';
      case 'paid':
        return 'Оплачен';
      case 'failed':
        return 'Ошибка';
      default:
        return status.isEmpty ? 'Не задан' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
      case 'completed':
      case 'paid':
      case 'delivered':
        return AppColors.brown;
      case 'blocked':
      case 'deleted':
      case 'cancelled':
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.star;
    }
  }

  Widget _buildStatusChip(String label, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppText.medium_12.copyWith(color: color)),
    );
  }

  Future<void> _confirmDelete() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить учетную запись?'),
        content: const Text('Пользователь получит статус deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (approved == true) {
      await _runAction(() => _service.deleteUser(widget.user.userId));
    }
  }

  Future<void> _deactivateWithReason(AdminUserDetails details) async {
    final controller = TextEditingController();
    String? errorText;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Причина деактивации'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Укажите причину деактивации',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setLocalState(() {
                    errorText = 'Поле обязательно для заполнения';
                  });
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Деактивировать'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || reason == null) return;

    await _runAction(
      () => _service.deactivateUser(
        userId: details.id,
        reason: reason,
      ),
    );
  }

  Future<void> _hire(AdminUserDetails details) async {
    if (details.employee != null) {
      await _runAction(() => _service.rehireUser(details.id));
      return;
    }

    final positionId = details.positions.isNotEmpty
        ? details.positions.first.id
        : 1;
    final storeId = details.stores.isNotEmpty ? details.stores.first.id : 1;
    await _runAction(
      () => _service.hireUser(
        userId: details.id,
        positionId: positionId,
        storeId: storeId,
      ),
    );
  }

  String _positionNameById(AdminUserDetails details, int positionId) {
    for (final position in details.positions) {
      if (position.id == positionId) {
        return position.title;
      }
    }
    return 'Должность #$positionId';
  }

  Future<void> _editEmployee(AdminUserDetails details) async {
    final employee = details.employee;
    if (employee == null) return;
    if (details.positions.isEmpty || details.stores.isEmpty) {
      _showSnack('Недостаточно данных для редактирования сотрудника');
      return;
    }

    int selectedPositionId = employee.positionId;
    int selectedStoreId = employee.storeId;
    final salaryController = TextEditingController(
      text: employee.salary.toStringAsFixed(employee.salary % 1 == 0 ? 0 : 2),
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Редактировать сотрудника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPositionId,
                items: details.positions
                    .map(
                      (position) => DropdownMenuItem<int>(
                        value: position.id,
                        child: Text(position.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() => selectedPositionId = value);
                },
                decoration: const InputDecoration(labelText: 'Должность'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedStoreId,
                items: details.stores
                    .map(
                      (store) => DropdownMenuItem<int>(
                        value: store.id,
                        child: Text(store.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() => selectedStoreId = value);
                },
                decoration: const InputDecoration(labelText: 'Место работы'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'ЗП'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || approved != true) return;

    final newSalary = double.tryParse(
      salaryController.text.trim().replaceAll(',', '.'),
    );
    if (newSalary == null || newSalary < 0) {
      _showSnack('Введите корректную ЗП');
      return;
    }

    final positionChanged = selectedPositionId != employee.positionId;
    final storeChanged = selectedStoreId != employee.storeId;
    final salaryChanged = (newSalary - employee.salary).abs() > 0.0001;

    if (!positionChanged && !storeChanged && !salaryChanged) {
      _showSnack('Изменений нет');
      return;
    }

    final changes = <String>[
      if (positionChanged)
        'Должность: "${_positionNameById(details, employee.positionId)}" → "${_positionNameById(details, selectedPositionId)}"',
      if (storeChanged)
        'Место работы: "${_storeNameById(details, employee.storeId)}" → "${_storeNameById(details, selectedStoreId)}"',
      if (salaryChanged)
        'ЗП: ${_formatPrice(employee.salary)} → ${_formatPrice(newSalary)}',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Подтвердить изменения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: changes.map((line) => Text('• $line')).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await _runAction(
        () => _service.updateEmployeeProfile(
          userId: details.id,
          positionId: positionChanged ? selectedPositionId : null,
          storeId: storeChanged ? selectedStoreId : null,
          salary: salaryChanged ? newSalary : null,
        ),
      );
    }
  }

  String _storeNameById(AdminUserDetails details, int storeId) {
    for (final store in details.stores) {
      if (store.id == storeId) {
        return store.title;
      }
    }
    return 'Магазин #$storeId';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Пользователь'),
      content: SizedBox(
        width: 620,
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? SizedBox(
                height: 180,
                child: Center(
                  child: Text('Не удалось загрузить данные: $_error'),
                ),
              )
            : _buildContent(_details!),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _loadDetails,
          child: const Text('Обновить'),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(_hasChanges),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _buildContent(AdminUserDetails details) {
    final isEmployee = details.employee != null;
    final isActive = details.status == 'active';
    final isEmployeeActive = details.employee?.isActive == true;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 560),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${details.id}', style: AppText.medium_14),
            const SizedBox(height: 4),
            Text(
              'Имя: ${details.name.isEmpty ? widget.user.name : details.name}',
              style: AppText.medium_14,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(_prettyStatus(details.status), details.status),
                if (isEmployee)
                  _buildStatusChip(
                    details.employee!.isActive
                        ? 'Сотрудник активен'
                        : 'Сотрудник уволен',
                    details.employee!.isActive ? 'active' : 'blocked',
                  ),
              ],
            ),
            if (isEmployee) ...[
              const SizedBox(height: 12),
              _detailLine('Должность', details.employee!.positionTitle),
              _detailLine('Место работы', details.employee!.storeName),
              _detailLine('ЗП', _formatPrice(details.employee!.salary)),
            ],
            if (widget.user.canManage) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isEmployee)
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _editEmployee(details),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        side: BorderSide(color: AppColors.grey_light),
                      ),
                      child: const Text(
                        'Редактировать сотрудника',
                        style: AppText.medium_12,
                      ),
                    ),
                  if(isEmployee)
                    SizedBox(height: 70),

                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : isEmployeeActive
                        ? () => _runAction(() => _service.fireUser(details.id))
                        : () => _hire(details),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      side: BorderSide(color: AppColors.grey_light),
                    ),
                    child: Text(
                      isEmployeeActive ? 'Уволить' : 'Нанять',
                      style: AppText.medium_14,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isSaving ? null : _confirmDelete,
                    child: Text(
                      'Удалить',
                      style: AppText.medium_14.copyWith(color: AppColors.white),
                    ),
                  ),

                  if (!isActive)
                    Center(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _runAction(
                                () => _service.activateUser(details.id),
                              ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          side: BorderSide(color: AppColors.grey_light),
                        ),
                        child: const Text(
                          'Активировать',
                          style: AppText.medium_14,
                        ),
                      ),
                    ),
                  if (isActive)
                    Center(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _deactivateWithReason(details),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          side: BorderSide(color: AppColors.grey_light),
                        ),
                        child: const Text(
                          'Деактивировать',
                          style: AppText.medium_14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('История заказов', style: AppText.semibold_15),
            const SizedBox(height: 10),
            if (details.orders.isEmpty)
              Text('Заказы не найдены', style: AppText.medium_14)
            else
              ...details.orders.map((order) => _buildOrderTile(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(AdminUserOrderSummary order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey_light.withValues(alpha: 0.45)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Заказ #${order.orderNumber}',
                style: AppText.semibold_15.copyWith(color: AppColors.black),
              ),
            ),
            Text(_formatPrice(order.totalPrice), style: AppText.semibold_15),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(_prettyStatus(order.status), order.status),
              _buildStatusChip(
                _prettyStatus(order.paymentStatus),
                order.paymentStatus,
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            color: AppColors.white,
            child: Column(
              children: [
                _detailLine(
                  'Тип',
                  order.orderType == 'pickup' ? 'Самовывоз' : 'Доставка',
                ),
                _detailLine('Магазин', order.storeName),
                _detailLine('Подытог', _formatPrice(order.subtotal)),
                _detailLine('Доставка', _formatPrice(order.deliveryFee)),
                _detailLine('Скидка', _formatPrice(order.discountAmount)),
                _detailLine('Создан', _formatDate(order.createdAt)),
                _detailLine('Обновлен', _formatDate(order.updatedAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.medium_14)),
          Expanded(child: Text(value, style: AppText.medium_14)),
        ],
      ),
    );
  }
}
