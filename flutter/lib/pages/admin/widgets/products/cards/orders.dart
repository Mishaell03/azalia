import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/order_payment_status_config.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartOrders extends StatefulWidget {
  const AdminProductsCartOrders({super.key});

  @override
  State<AdminProductsCartOrders> createState() =>
      _AdminProductsCartOrdersState();
}

class _AdminProductsCartOrdersState extends State<AdminProductsCartOrders> {
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  String _statusFilter = '';
  String _sortBy = 'created_at_desc';
  List<_AdminOrderSummary> _orders = const [];

  static final List<MapEntry<String, String>> _statusOptions =
      OrderPaymentStatusConfig.orderStatusFilterOptions();

  static const List<MapEntry<String, String>> _sortOptions = [
    MapEntry('created_at_desc', 'Сначала новые'),
    MapEntry('address_asc', 'По адресу (самовывоз)'),
  ];

  String _normalizeStatusCode(String? rawCodeOrLabel) {
    final raw = (rawCodeOrLabel ?? '').trim();
    if (raw.isEmpty) return '';

    for (final entry in _statusOptions) {
      if (entry.key == raw) return entry.key;
    }
    for (final entry in _statusOptions) {
      if (entry.value == raw) return entry.key;
    }
    return '';
  }

  String _statusLabelByCode(String code) {
    return OrderPaymentStatusConfig.orderLabel(code);
  }

  Color _orderStatusColor(String code) {
    return OrderPaymentStatusConfig.orderColor(code);
  }

  String _paymentStatusLabel(String code) {
    return OrderPaymentStatusConfig.paymentLabel(code);
  }

  Color _paymentStatusColor(String code) {
    return OrderPaymentStatusConfig.paymentColor(code);
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '-';
    final value = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (value == null) return raw;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  String _resolvedOrderCode(String statusCode, String statusLabelOrCode) {
    if (statusCode.isNotEmpty) return statusCode;
    return OrderPaymentStatusConfig.normalize(statusLabelOrCode);
  }

  String _resolvedPaymentCode(String statusCode, String statusLabelOrCode) {
    if (statusCode.isNotEmpty) return statusCode;
    return OrderPaymentStatusConfig.normalize(statusLabelOrCode);
  }

  List<MapEntry<String, String>> _fallbackEditableStatuses(String orderType) {
    return OrderPaymentStatusConfig.editableOrderStatusOptions(
      orderType: orderType,
    );
  }

  List<MapEntry<String, String>> _editableStatusesForOrder(
    _AdminOrderDetail detail,
  ) {
    if (detail.availableStatuses.isNotEmpty) {
      return detail.availableStatuses
          .map((s) => MapEntry(s.code, s.label))
          .toList();
    }
    return _fallbackEditableStatuses(detail.orderType);
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
        ApiConfig.adminOrders(
          limit: 100,
          status: _statusFilter.isEmpty ? null : _statusFilter,
          sortBy: _sortBy,
          includeClosed: true,
        ),
      );
      if (response['success'] != true) {
        throw Exception('Не удалось загрузить заказы');
      }

      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final items = (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminOrderSummary.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _orders = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки заказов: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<_AdminOrderDetail> _fetchOrderDetail(int orderId) async {
    final response = await _api.get(ApiConfig.adminOrderDetails(orderId));
    if (response['success'] != true ||
        response['data'] is! Map<String, dynamic>) {
      throw Exception('Не удалось загрузить состав заказа');
    }
    return _AdminOrderDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    await _api.patch(
      ApiConfig.adminOrderStatus(orderId),
      body: {'status': status},
    );
  }

  Future<void> _closeOrder(int orderId) async {
    await _api.post(ApiConfig.adminOrderClose(orderId));
  }

  Future<void> _markOrderPaid(int orderId) async {
    await _api.post(ApiConfig.adminOrderMarkPaid(orderId));
  }

  Future<void> _refundOrder(int orderId, {String? reason}) async {
    await _api.post(
      ApiConfig.adminOrderRefund(orderId),
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> _showOrderDialog(_AdminOrderSummary order) async {
    _AdminOrderDetail detail;
    try {
      detail = await _fetchOrderDetail(order.orderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось загрузить заказ: $e',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    String selectedStatus = _normalizeStatusCode(
      detail.statusCode.isNotEmpty ? detail.statusCode : detail.status,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentStatusCode = _normalizeStatusCode(
              detail.statusCode.isNotEmpty ? detail.statusCode : detail.status,
            );
            final editableStatuses = _editableStatusesForOrder(detail);
            final editableCodes = editableStatuses.map((x) => x.key).toSet();
            final dropdownValue =
                (selectedStatus.isNotEmpty &&
                    editableCodes.contains(selectedStatus))
                ? selectedStatus
                : null;
            final hasStatusChange =
                selectedStatus.isNotEmpty &&
                selectedStatus != currentStatusCode;
            final canCloseOrder =
                detail.paymentStatusCode == 'paid' &&
                currentStatusCode != 'completed' &&
                currentStatusCode != 'cancelled';
            final canMarkPaid =
                detail.paymentStatusCode != 'paid' &&
                currentStatusCode != 'completed' &&
                currentStatusCode != 'cancelled';
            final hasRefund = detail.refunds.any(
              (refund) =>
                  refund.status == 'processed' ||
                  refund.status == 'pending',
            );
            final canRefund =
                detail.paymentStatusCode == 'paid' && !hasRefund;

            return AlertDialog(
              title: Text('Заказ №${detail.orderNumber}'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _orderStatusColor(
                                  currentStatusCode,
                                ),
                              ),
                              color: _orderStatusColor(
                                currentStatusCode,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabelByCode(
                                _resolvedOrderCode(
                                  currentStatusCode,
                                  detail.status,
                                ),
                              ),
                              style: AppText.medium_12.copyWith(
                                color: _orderStatusColor(currentStatusCode),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _paymentStatusColor(
                                  _resolvedPaymentCode(
                                    detail.paymentStatusCode,
                                    detail.paymentStatus,
                                  ),
                                )
                              ),
                              color: _paymentStatusColor(
                                _resolvedPaymentCode(
                                  detail.paymentStatusCode,
                                  detail.paymentStatus,
                                ),
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _paymentStatusLabel(
                                _resolvedPaymentCode(
                                  detail.paymentStatusCode,
                                  detail.paymentStatus,
                                ),
                              ),
                              style: AppText.medium_12.copyWith(
                                color: _paymentStatusColor(
                                  _resolvedPaymentCode(
                                    detail.paymentStatusCode,
                                    detail.paymentStatus,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Клиент: ${detail.customerName}'),
                      Text('Телефон: ${detail.customerPhone}'),
                      Text(
                        'Тип заказа: ${detail.orderTypeLabel.isNotEmpty ? detail.orderTypeLabel : (detail.orderType == 'pickup' ? 'Без доставки' : 'С доставкой')}',
                      ),
                      Text('Точка: ${detail.storeAddress}'),
                      if (detail.paymentMode == 'on_delivery')
                        Text(
                          'Оплата при получении: ${detail.onDeliveryMethod == 'card' ? 'картой' : (detail.onDeliveryMethod == 'cash' ? 'наличными' : '-')}',
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(selectedStatus),
                        initialValue: dropdownValue,
                        decoration: const InputDecoration(
                          labelText: 'Изменить статус',
                          border: OutlineInputBorder(),
                        ),
                        items: editableStatuses
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  _statusLabelByCode(entry.key),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isActionLoading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedStatus = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      Text('Состав заказа', style: AppText.medium_16),
                      const SizedBox(height: 8),
                      ...detail.items.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.grey_light),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: AppText.medium_14),
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} шт. • ${item.totalPrice.toStringAsFixed(2)} ₽',
                                style: AppText.medium_12.copyWith(
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('История статусов', style: AppText.medium_16),
                      const SizedBox(height: 8),
                      if (detail.statusHistory.isEmpty)
                        Text(
                          'История статусов пока недоступна',
                          style: AppText.medium_12.copyWith(
                            color: AppColors.grey,
                          ),
                        )
                      else
                        ...detail.statusHistory.map(
                          (event) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey_light),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLabelByCode(
                                    _resolvedOrderCode(
                                      event.newStatusCode,
                                      event.newStatus,
                                    ),
                                  ),
                                  style: AppText.medium_14.copyWith(
                                    color: _orderStatusColor(
                                      _resolvedOrderCode(
                                        event.newStatusCode,
                                        event.newStatus,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(event.changedAt),
                                  style: AppText.medium_12.copyWith(
                                    color: AppColors.grey,
                                  ),
                                ),
                                if (event.changedBy.employeeName != null &&
                                    event
                                        .changedBy
                                        .employeeName!
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    event.changedBy.employeeName!,
                                    style: AppText.medium_12.copyWith(
                                      color: AppColors.black_transparent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isActionLoading
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    side: BorderSide(color: AppColors.brown),
                  ),
                  child: Text(
                    'Отмена',
                    style: AppText.medium_12.copyWith(color: AppColors.brown),
                  ),
                ),
                if (canMarkPaid)
                  TextButton(
                    onPressed: _isActionLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _isActionLoading = true;
                            });
                            try {
                              await _markOrderPaid(detail.orderId);
                              detail = await _fetchOrderDetail(detail.orderId);
                              if (!mounted) return;
                              setDialogState(() {});
                              await _loadOrders();
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Оплата отмечена',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Не удалось отметить оплату: $e',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isActionLoading = false;
                                });
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.brown,
                    ),
                    child: Text(
                      'Провести оплату',
                      style: AppText.medium_12.copyWith(
                        color: AppColors.white_transparent,
                      ),
                    ),
                  ),
                if (canRefund)
                  TextButton(
                    onPressed: _isActionLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _isActionLoading = true;
                            });
                            try {
                              await _refundOrder(
                                detail.orderId,
                                reason: 'Возврат из панели администратора',
                              );
                              detail = await _fetchOrderDetail(detail.orderId);
                              if (!mounted) return;
                              setDialogState(() {});
                              await _loadOrders();
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Возврат выполнен',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Не удалось сделать возврат: $e',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isActionLoading = false;
                                });
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      side: BorderSide(color: AppColors.brown),
                    ),
                    child: Text(
                      'Сделать возврат',
                      style: AppText.medium_12.copyWith(
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                if (hasStatusChange)
                  TextButton(
                    onPressed: _isActionLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (!hasStatusChange) {
                              Navigator.of(ctx).pop();
                              return;
                            }
                            setState(() {
                              _isActionLoading = true;
                            });
                            try {
                              await _updateOrderStatus(
                                detail.orderId,
                                selectedStatus,
                              );
                              detail = await _fetchOrderDetail(detail.orderId);
                              selectedStatus = _normalizeStatusCode(
                                detail.statusCode.isNotEmpty
                                    ? detail.statusCode
                                    : detail.status,
                              );
                              if (!mounted) return;
                              setDialogState(() {});
                              await _loadOrders();
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Статус обновлён',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Не удалось обновить статус: $e',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isActionLoading = false;
                                });
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.brown,
                    ),
                    child: Text(
                      'Применить статус',
                      style: AppText.medium_12.copyWith(
                        color: AppColors.white_transparent,
                      ),
                    ),
                  ),
                if (canCloseOrder)
                  TextButton(
                    onPressed: _isActionLoading
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _isActionLoading = true;
                            });
                            try {
                              await _closeOrder(detail.orderId);
                              if (!mounted) return;
                              if (navigator.canPop()) {
                                navigator.pop();
                              }
                              await _loadOrders();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Заказ закрыт',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.white,
                                  content: Text(
                                    'Не удалось закрыть заказ: $e',
                                    style: AppText.medium_14.copyWith(
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isActionLoading = false;
                                });
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      side: BorderSide(color: AppColors.brown),
                    ),
                    child: Text(
                      'Закрыть заказ',
                      style: AppText.medium_12.copyWith(color: AppColors.brown),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(_statusFilter),
                  initialValue: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Фильтр статуса',
                    floatingLabelStyle: AppText.medium_16,
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value, style: AppText.medium_16),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) async {
                          setState(() {
                            _statusFilter = value ?? '';
                          });
                          await _loadOrders();
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(_sortBy),
                  initialValue: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Сортировка',
                    floatingLabelStyle: AppText.medium_16,
                    border: OutlineInputBorder(),
                  ),
                  items: _sortOptions
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value, style: AppText.medium_16),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) async {
                          setState(() {
                            _sortBy = value ?? 'created_at_desc';
                          });
                          await _loadOrders();
                        },
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(child: Text(_error!));
                }
                if (_orders.isEmpty) {
                  return const Center(child: Text('Заказов пока нет'));
                }
                return RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return InkWell(
                        onTap: _isActionLoading
                            ? null
                            : () => _showOrderDialog(order),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '№${order.orderNumber}',
                                        style: AppText.medium_16,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${order.itemsCount} поз. • ${order.totalPrice.toStringAsFixed(2)} ₽',
                                        style: AppText.medium_14.copyWith(
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${order.customerName} • ${order.customerPhone}',
                                        style: AppText.medium_12.copyWith(
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.orderTypeLabel.isNotEmpty
                                            ? order.orderTypeLabel
                                            : (order.orderType == 'pickup'
                                                  ? 'Без доставки'
                                                  : 'С доставкой'),
                                        style: AppText.medium_12.copyWith(
                                          color: AppColors.black_transparent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _orderStatusColor(
                                            order.statusCode,
                                          )
                                        ),
                                        color: _orderStatusColor(
                                          order.statusCode,
                                        ).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabelByCode(
                                          _resolvedOrderCode(
                                            order.statusCode,
                                            order.status,
                                          ),
                                        ),
                                        style: AppText.medium_12.copyWith(
                                          color: _orderStatusColor(
                                            _resolvedOrderCode(
                                              order.statusCode,
                                              order.status,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _paymentStatusColor(
                                            _resolvedPaymentCode(
                                              order.paymentStatusCode,
                                              order.paymentStatus,
                                            ),
                                          ),
                                        ),
                                        color: _paymentStatusColor(
                                          _resolvedPaymentCode(
                                            order.paymentStatusCode,
                                            order.paymentStatus,
                                          ),
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _paymentStatusLabel(
                                          _resolvedPaymentCode(
                                            order.paymentStatusCode,
                                            order.paymentStatus,
                                          ),
                                        ),
                                        style: AppText.medium_12.copyWith(
                                          color: _paymentStatusColor(
                                            _resolvedPaymentCode(
                                              order.paymentStatusCode,
                                              order.paymentStatus,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderSummary {
  final int orderId;
  final String orderNumber;
  final String status;
  final String statusCode;
  final String paymentStatus;
  final String paymentStatusCode;
  final double totalPrice;
  final int itemsCount;
  final String orderType;
  final String orderTypeLabel;
  final String customerName;
  final String customerPhone;

  const _AdminOrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusCode,
    required this.paymentStatus,
    required this.paymentStatusCode,
    required this.totalPrice,
    required this.itemsCount,
    required this.orderType,
    required this.orderTypeLabel,
    required this.customerName,
    required this.customerPhone,
  });

  factory _AdminOrderSummary.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return _AdminOrderSummary(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentStatusCode: json['payment_status_code']?.toString() ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      orderType: json['order_type']?.toString() ?? '',
      orderTypeLabel: json['order_type_label']?.toString() ?? '',
      customerName: customer['name']?.toString() ?? 'Без имени',
      customerPhone: customer['phone']?.toString() ?? '-',
    );
  }
}

class _AdminOrderDetail {
  final int orderId;
  final String orderNumber;
  final String status;
  final String statusCode;
  final String paymentStatus;
  final String paymentStatusCode;
  final String orderType;
  final String orderTypeLabel;
  final String paymentMode;
  final String? paymentMethodCode;
  final String? onDeliveryMethod;
  final String customerName;
  final String customerPhone;
  final String storeAddress;
  final List<_AdminStatusOption> availableStatuses;
  final List<_AdminStatusHistoryItem> statusHistory;
  final List<_AdminRefund> refunds;
  final List<_AdminOrderItem> items;

  const _AdminOrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusCode,
    required this.paymentStatus,
    required this.paymentStatusCode,
    required this.orderType,
    required this.orderTypeLabel,
    required this.paymentMode,
    required this.paymentMethodCode,
    required this.onDeliveryMethod,
    required this.customerName,
    required this.customerPhone,
    required this.storeAddress,
    required this.availableStatuses,
    required this.statusHistory,
    required this.refunds,
    required this.items,
  });

  factory _AdminOrderDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    final store = json['store'] as Map<String, dynamic>? ?? const {};
    final payment = json['payment'] as Map<String, dynamic>? ?? const {};
    return _AdminOrderDetail(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentStatusCode: json['payment_status_code']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      orderTypeLabel: json['order_type_label']?.toString() ?? '',
      paymentMode: payment['payment_mode']?.toString() ?? 'online',
      paymentMethodCode: payment['payment_method_code']?.toString(),
      onDeliveryMethod: payment['on_delivery_method']?.toString(),
      customerName: customer['name']?.toString() ?? 'Без имени',
      customerPhone: customer['phone']?.toString() ?? '-',
      storeAddress: store['address']?.toString() ?? '-',
      availableStatuses: (json['available_statuses'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminStatusOption.fromJson)
          .toList(),
      statusHistory: (json['status_history'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminStatusHistoryItem.fromJson)
          .toList(),
      refunds: (json['refunds'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminRefund.fromJson)
          .toList(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminOrderItem.fromJson)
          .toList(),
    );
  }
}

class _AdminRefund {
  final String status;
  final double amount;
  final String? reason;
  final String? processedAt;
  final String createdAt;

  const _AdminRefund({
    required this.status,
    required this.amount,
    required this.reason,
    required this.processedAt,
    required this.createdAt,
  });

  factory _AdminRefund.fromJson(Map<String, dynamic> json) {
    return _AdminRefund(
      status: json['status']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString(),
      processedAt: json['processed_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class _AdminStatusHistoryItem {
  final String newStatus;
  final String newStatusCode;
  final String changedAt;
  final _AdminStatusChangedBy changedBy;

  const _AdminStatusHistoryItem({
    required this.newStatus,
    required this.newStatusCode,
    required this.changedAt,
    required this.changedBy,
  });

  factory _AdminStatusHistoryItem.fromJson(Map<String, dynamic> json) {
    return _AdminStatusHistoryItem(
      newStatus: json['new_status']?.toString() ?? '',
      newStatusCode: json['new_status_code']?.toString() ?? '',
      changedAt: json['changed_at']?.toString() ?? '',
      changedBy: _AdminStatusChangedBy.fromJson(
        json['changed_by'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class _AdminStatusChangedBy {
  final String? employeeName;

  const _AdminStatusChangedBy({required this.employeeName});

  factory _AdminStatusChangedBy.fromJson(Map<String, dynamic> json) {
    return _AdminStatusChangedBy(
      employeeName: json['employee_name']?.toString(),
    );
  }
}

class _AdminStatusOption {
  final String code;
  final String label;

  const _AdminStatusOption({required this.code, required this.label});

  factory _AdminStatusOption.fromJson(Map<String, dynamic> json) {
    return _AdminStatusOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class _AdminOrderItem {
  final String name;
  final int quantity;
  final double totalPrice;

  const _AdminOrderItem({
    required this.name,
    required this.quantity,
    required this.totalPrice,
  });

  factory _AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return _AdminOrderItem(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
    );
  }
}
