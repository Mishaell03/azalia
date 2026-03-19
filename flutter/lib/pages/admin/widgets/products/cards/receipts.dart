import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/procurement.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartReceipts extends StatefulWidget {
  const AdminProductsCartReceipts({super.key});

  @override
  State<AdminProductsCartReceipts> createState() =>
      _AdminProductsCartReceiptsState();
}

class _AdminProductsCartReceiptsState extends State<AdminProductsCartReceipts> {
  final ProcurementService _service = ProcurementService(ApiClient());

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  int? _selectedStoreId;
  List<_StoreReceiptItem> _stores = const [];
  List<_ReceiptOrder> _orders = const [];
  final Map<int, Map<int, int>> _draftAcceptedByOrder = <int, Map<int, int>>{};

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts({int? storeId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getReceipts(storeId: storeId, limit: 300);
      final storesRaw = data['stores'] as List? ?? const [];
      final itemsRaw = data['items'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _stores = storesRaw
            .whereType<Map<String, dynamic>>()
            .map(_StoreReceiptItem.fromJson)
            .toList();
        _orders = itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(_ReceiptOrder.fromJson)
            .toList();
        _selectedStoreId = storeId;
        _cleanupDraftAccepted();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки разгрузки: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cleanupDraftAccepted() {
    final validOrderIds = _orders.map((o) => o.id).toSet();
    _draftAcceptedByOrder.removeWhere(
      (orderId, _) => !validOrderIds.contains(orderId),
    );
    for (final order in _orders) {
      final validItemIds = order.items.map((i) => i.id).toSet();
      final byItems = _draftAcceptedByOrder[order.id];
      if (byItems == null) continue;
      byItems.removeWhere((itemId, _) => !validItemIds.contains(itemId));
      if (byItems.isEmpty) {
        _draftAcceptedByOrder.remove(order.id);
      }
    }
    _initDefaultAcceptedForEditableOrders();
  }

  void _initDefaultAcceptedForEditableOrders() {
    for (final order in _orders) {
      if (!order.canAccept) continue;
      final byItems = _draftAcceptedByOrder.putIfAbsent(
        order.id,
        () => <int, int>{},
      );
      for (final item in order.items) {
        byItems.putIfAbsent(item.id, () => item.remainingQuantity);
      }
    }
  }

  int _draftAcceptedForItem(int orderId, int itemId, int fallbackValue) {
    return _draftAcceptedByOrder[orderId]?[itemId] ?? fallbackValue;
  }

  Color _statusColor(String code) {
    switch (code.trim().toLowerCase()) {
      case 'received':
        return AppColors.success;
      case 'partially_received':
        return AppColors.brown;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _formatDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '-';
    final dt = DateTime.tryParse(text);
    if (dt == null) return text;
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Future<int?> _showAcceptedQtyDialog({
    required String productName,
    required int maxValue,
    required int initialValue,
  }) async {
    var rawValue = '$initialValue';
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Приемка: $productName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Введите количество к приемке (0..$maxValue):',
              style: AppText.medium_14,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: rawValue,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                rawValue = value;
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Количество',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              side: const BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Отмена',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(rawValue.trim());
              if (parsed == null || parsed < 0 || parsed > maxValue) return;
              Navigator.of(ctx).pop(parsed);
            },
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Принять',
              style: AppText.medium_14.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptItem(_ReceiptOrder order, _ReceiptItem item) async {
    if (!order.canAccept) return;
    final acceptedQty = await _showAcceptedQtyDialog(
      productName: item.name,
      maxValue: item.remainingQuantity,
      initialValue: _draftAcceptedForItem(
        order.id,
        item.id,
        item.remainingQuantity,
      ),
    );
    if (acceptedQty == null) return;

    setState(() {
      final byItems = _draftAcceptedByOrder.putIfAbsent(
        order.id,
        () => <int, int>{},
      );
      byItems[item.id] = acceptedQty;
    });
  }

  Future<bool> _confirmAcceptOrder(_ReceiptOrder order) async {
    final byItems = _draftAcceptedByOrder[order.id] ?? const <int, int>{};
    final totalToAccept = byItems.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Принять поставку №${order.purchaseNumber}'),
        content: Text(
          'Подтвердить приемку?\n'
          'Позиции: ${order.items.length}\n'
          'К приемке: $totalToAccept шт.',
          style: AppText.medium_14.copyWith(color: AppColors.black),
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
              'Принять',
              style: AppText.medium_14.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _submitOrder(_ReceiptOrder order) async {
    if (_isSaving || !order.canAccept) return;
    final confirmed = await _confirmAcceptOrder(order);
    if (!confirmed) return;

    final byItems = _draftAcceptedByOrder[order.id] ?? const <int, int>{};
    final itemPayload = order.items
        .map(
          (item) => {
            'purchase_order_item_id': item.id,
            'accepted_quantity': byItems[item.id] ?? item.remainingQuantity,
          },
        )
        .toList();

    setState(() {
      _isSaving = true;
    });
    try {
      await _service.createReceipt(
        purchaseOrderId: order.id,
        items: itemPayload,
      );
      if (!mounted) return;
      setState(() {
        _draftAcceptedByOrder.remove(order.id);
      });
      await _loadReceipts(storeId: _selectedStoreId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Поставка №${order.purchaseNumber} принята',
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
            'Ошибка приемки: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
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

  Widget _buildItemCard(_ReceiptOrder order, _ReceiptItem item) {
    final image = ApiConfig.imageUrl(item.imageUrl).trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _isSaving || !order.canAccept
              ? null
              : () => _acceptItem(order, item),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey_light),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image.isEmpty
                      ? Container(
                          width: 58,
                          height: 58,
                          color: AppColors.grey_light,
                        )
                      : Image.network(
                          image,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stackTrace) => Container(
                            width: 58,
                            height: 58,
                            color: AppColors.grey_light,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppText.medium_14.copyWith(
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Заказали: ${item.orderedQuantity} шт.',
                        style: AppText.medium_12.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                      Text(
                        'Принято: ${item.receivedQuantity} шт. • Осталось: ${item.remainingQuantity} шт.',
                        style: AppText.medium_12.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      Text(
                        'К приемке: ${_draftAcceptedForItem(order.id, item.id, item.remainingQuantity)} шт.',
                        style: AppText.medium_12.copyWith(
                          color: AppColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.inventory_2_outlined, color: AppColors.brown),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: AppText.medium_14.copyWith(color: AppColors.error),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadReceipts(storeId: _selectedStoreId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Админ-разгрузка',
                    style: AppText.bold_18.copyWith(color: AppColors.black),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _selectedStoreId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Магазин',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Все магазины'),
                      ),
                      ..._stores.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text('${s.name} • ${s.address}'),
                        ),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) => _loadReceipts(storeId: value),
                  ),
                  const SizedBox(height: 16),
                  if (_orders.isEmpty)
                    Text(
                      'Поставок для разгрузки нет',
                      style: AppText.medium_14.copyWith(color: AppColors.grey),
                    )
                  else
                    ..._orders.map(
                      (order) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey_light),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Поставка №${order.purchaseNumber}',
                                  style: AppText.bold_15.copyWith(
                                    color: AppColors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      order.statusCode,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: AppText.medium_12.copyWith(
                                      color: _statusColor(order.statusCode),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${order.storeName}, ${order.storeAddress}\n${_formatDate(order.orderedAt)}',
                                  style: AppText.medium_12.copyWith(
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            ...order.items.map(
                              (item) => _buildItemCard(order, item),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: _isSaving || !order.canAccept
                                  ? null
                                  : () => _submitOrder(order),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.brown,
                                side: const BorderSide(color: AppColors.brown),
                              ),
                              child: Text(
                                _isSaving
                                    ? 'Обработка...'
                                    : order.canAccept
                                    ? 'Принять поставку'
                                    : 'Поставка завершена',
                                style: AppText.medium_14.copyWith(
                                  color: AppColors.white_transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StoreReceiptItem {
  final int id;
  final String name;
  final String address;

  const _StoreReceiptItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _StoreReceiptItem.fromJson(Map<String, dynamic> json) {
    return _StoreReceiptItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class _ReceiptOrder {
  final int id;
  final String purchaseNumber;
  final String status;
  final String statusCode;
  final bool canAccept;
  final String storeName;
  final String storeAddress;
  final String? orderedAt;
  final List<_ReceiptItem> items;

  const _ReceiptOrder({
    required this.id,
    required this.purchaseNumber,
    required this.status,
    required this.statusCode,
    required this.canAccept,
    required this.storeName,
    required this.storeAddress,
    required this.orderedAt,
    required this.items,
  });

  factory _ReceiptOrder.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map<String, dynamic>? ?? const {};
    return _ReceiptOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      purchaseNumber: json['purchase_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      canAccept: json['can_accept'] == true,
      storeName: store['name']?.toString() ?? '',
      storeAddress: store['address']?.toString() ?? '',
      orderedAt: json['ordered_at']?.toString(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_ReceiptItem.fromJson)
          .toList(),
    );
  }
}

class _ReceiptItem {
  final int id;
  final int orderedQuantity;
  final int receivedQuantity;
  final int remainingQuantity;
  final String name;
  final String imageUrl;

  const _ReceiptItem({
    required this.id,
    required this.orderedQuantity,
    required this.receivedQuantity,
    required this.remainingQuantity,
    required this.name,
    required this.imageUrl,
  });

  factory _ReceiptItem.fromJson(Map<String, dynamic> json) {
    return _ReceiptItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderedQuantity: (json['ordered_quantity'] as num?)?.toInt() ?? 0,
      receivedQuantity: (json['received_quantity'] as num?)?.toInt() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}
