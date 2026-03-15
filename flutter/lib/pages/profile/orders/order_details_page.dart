import 'package:azalia/backend/models/payment/order_history.dart';
import 'package:azalia/backend/services/order_history.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/order_payment_status_config.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:flutter/material.dart';

class OrderDetailsPage extends StatefulWidget {
  final int orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isLoading = true;
  String? _error;
  OrderHistoryDetail? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await OrderHistoryService.getOrderDetails(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
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

  Widget _buildChip(String text, String status, {required bool isPayment}) {
    final color = isPayment
        ? OrderPaymentStatusConfig.paymentColor(status)
        : OrderPaymentStatusConfig.orderColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppText.medium_12.copyWith(color: color),
      ),
    );
  }

  bool _canCancelOrder(OrderHistoryDetail order) {
    final statusCode = order.statusCode.isNotEmpty ? order.statusCode : order.status;
    return statusCode != 'completed' && statusCode != 'cancelled';
  }

  Future<void> _cancelOrder(OrderHistoryDetail order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отмена заказа'),
        content: Text('Отменить заказ №${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await OrderHistoryService.cancelOrder(order.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Заказ отменен',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
      await _loadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось отменить заказ: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey_light.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.bold_18.copyWith(color: AppColors.black),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.medium_14.copyWith(color: AppColors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.medium_14.copyWith(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(OrderHistoryDetail order) {
    return Column(
      children: order.items.map((item) {
        final potParts = [
          item.pot.sizeName,
          item.pot.materialName,
          item.pot.colorName,
        ].whereType<String>().where((value) => value.isNotEmpty).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.grey_light.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppText.semibold_15.copyWith(color: AppColors.black),
              ),
              if (potParts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Горшок: ${potParts.join(', ')}',
                  style: AppText.medium_14.copyWith(
                    color: AppColors.black_transparent,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} шт.',
                      style: AppText.medium_14.copyWith(color: AppColors.grey),
                    ),
                  ),
                  Text(
                    _formatPrice(item.totalPrice),
                    style: AppText.semibold_15.copyWith(
                      color: AppColors.brown,
                    ),
                  ),
                ],
              ),
              if (item.returnedQuantity > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Возвращено: ${item.returnedQuantity}',
                  style: AppText.medium_14.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistory(OrderHistoryDetail order) {
    if (order.statusHistory.isEmpty) {
      return Text(
        'История статусов пока недоступна',
        style: AppText.medium_14.copyWith(color: AppColors.grey),
      );
    }

    return Column(
      children: order.statusHistory.map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: OrderPaymentStatusConfig.orderColor(
                    event.newStatusCode.isNotEmpty
                        ? event.newStatusCode
                        : event.newStatus,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrderPaymentStatusConfig.orderLabel(
                        event.newStatusCode.isNotEmpty
                            ? event.newStatusCode
                            : event.newStatus,
                      ),
                      style: AppText.medium_14.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(event.changedAt),
                      style: AppText.medium_12.copyWith(color: AppColors.grey),
                    ),
                    if (event.changedBy.employeeName != null &&
                        event.changedBy.employeeName!.isNotEmpty) ...[
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
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Заказ #${widget.orderId}',
          style: AppText.bold_18.copyWith(color: AppColors.black),
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null || order == null
          ? GenericErrorWidget(onRetry: _loadOrder)
          : RefreshIndicator(
              color: AppColors.brown,
              onRefresh: _loadOrder,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSection(
                    title: order.orderNumber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              OrderPaymentStatusConfig.orderLabel(
                                order.statusCode.isNotEmpty
                                    ? order.statusCode
                                    : order.status,
                              ),
                              order.statusCode.isNotEmpty
                                  ? order.statusCode
                                  : order.status,
                              isPayment: false,
                            ),
                            _buildChip(
                              OrderPaymentStatusConfig.paymentLabel(
                                order.paymentStatusCode.isNotEmpty
                                    ? order.paymentStatusCode
                                    : order.paymentStatus,
                              ),
                              order.paymentStatusCode.isNotEmpty
                                  ? order.paymentStatusCode
                                  : order.paymentStatus,
                              isPayment: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow('Создан', _formatDate(order.createdAt)),
                        _buildInfoRow('Обновлен', _formatDate(order.updatedAt)),
                        _buildInfoRow(
                          'Тип заказа',
                          order.orderType == 'pickup' ? 'Самовывоз' : 'Доставка',
                        ),
                        if (order.address != null && order.address!.isNotEmpty)
                          _buildInfoRow('Адрес', order.address!),
                        if (order.comment != null && order.comment!.isNotEmpty)
                          _buildInfoRow('Комментарий', order.comment!),
                        if (_canCancelOrder(order)) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () => _cancelOrder(order),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.error),
                                foregroundColor: AppColors.error,
                              ),
                              child: const Text('Отменить заказ'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Состав заказа',
                    child: _buildItems(order),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Сумма',
                    child: Column(
                      children: [
                        _buildInfoRow('Товары', _formatPrice(order.subtotal)),
                        _buildInfoRow(
                          'Доставка',
                          _formatPrice(order.deliveryFee),
                        ),
                        _buildInfoRow(
                          'Скидка',
                          _formatPrice(order.discountAmount),
                        ),
                        _buildInfoRow('Итого', _formatPrice(order.totalPrice)),
                      ],
                    ),
                  ),
                  if (order.payment != null) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Оплата',
                      child: Column(
                        children: [
                          _buildInfoRow(
                            'Статус',
                            OrderPaymentStatusConfig.paymentLabel(order.payment!.status),
                          ),
                          _buildInfoRow(
                            'Способ',
                            order.payment!.paymentMethodName ??
                                order.payment!.paymentMethodCode ??
                                'Не указан',
                          ),
                          _buildInfoRow(
                            'Сумма',
                            _formatPrice(order.payment!.amount),
                          ),
                          _buildInfoRow(
                            'Создан платеж',
                            _formatDate(order.payment!.createdAt),
                          ),
                          if (order.payment!.paidAt != null)
                            _buildInfoRow(
                              'Оплачен',
                              _formatDate(order.payment!.paidAt!),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'История статусов',
                    child: _buildHistory(order),
                  ),
                ],
              ),
            ),
    );
  }
}
