import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/procurement.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartProcurement extends StatefulWidget {
  const AdminProductsCartProcurement({super.key});

  @override
  State<AdminProductsCartProcurement> createState() =>
      _AdminProductsCartProcurementState();
}

class _AdminProductsCartProcurementState
    extends State<AdminProductsCartProcurement> {
  final ProcurementService _service = ProcurementService(ApiClient());

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  bool _missingExpanded = true;
  bool _catalogExpanded = true;

  List<_StoreItem> _stores = const [];
  int? _selectedStoreId;
  List<_ProcurementItem> _missingItems = const [];
  List<_ProcurementItem> _catalogItems = const [];
  List<_CartItem> _cartItems = const [];
  Set<int> _selectedCartIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final storeRows = await _service.getStores();
      final stores = storeRows.map(_StoreItem.fromJson).toList();
      final storeId = stores.isNotEmpty ? stores.first.id : null;
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _selectedStoreId = storeId;
      });
      await _reloadStoreData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки закупок: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadStoreData() async {
    final storeId = _selectedStoreId;
    if (storeId == null) {
      setState(() {
        _missingItems = const [];
        _catalogItems = const [];
        _cartItems = const [];
        _selectedCartIds = <int>{};
      });
      return;
    }

    final results = await Future.wait([
      _service.getMissingProducts(storeId),
      _service.getCatalogProducts(storeId),
      _service.getCartItems(storeId),
    ]);
    if (!mounted) return;
    final missing = results[0].map(_ProcurementItem.fromJson).toList();
    final catalog = results[1].map(_ProcurementItem.fromJson).toList();
    final cart = results[2].map(_CartItem.fromJson).toList();
    final validSelected = _selectedCartIds
        .where((id) => cart.any((item) => item.id == id))
        .toSet();
    setState(() {
      _missingItems = missing;
      _catalogItems = catalog;
      _cartItems = cart;
      _selectedCartIds = validSelected;
    });
  }

  Future<void> _onStoreChanged(int? storeId) async {
    setState(() {
      _selectedStoreId = storeId;
      _selectedCartIds = <int>{};
    });
    await _reloadStoreData();
  }

  Future<void> _addToCart(_ProcurementItem item) async {
    final qty = await _showQuantityDialog(
      title: 'Добавить в закупку',
      initialValue: 1,
    );
    if (qty == null) return;
    final storeId = _selectedStoreId;
    if (storeId == null) return;

    setState(() {
      _isActionLoading = true;
    });
    try {
      await _service.upsertCartItem(
        storeId: storeId,
        productId: item.productId,
        quantity: qty,
      );
      await _reloadStoreData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Товар добавлен в корзину закупок',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Не удалось добавить товар: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _changeCartQuantity(_CartItem item) async {
    final qty = await _showQuantityDialog(
      title: 'Изменить количество',
      initialValue: item.quantityToOrder,
    );
    if (qty == null) return;
    final storeId = _selectedStoreId;
    if (storeId == null) return;
    setState(() {
      _isActionLoading = true;
    });
    try {
      await _service.upsertCartItem(
        storeId: storeId,
        productId: item.productId,
        quantity: qty,
      );
      await _reloadStoreData();
    } catch (e) {
      if (!mounted) return;
      _showError('Не удалось изменить количество: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _removeCartItem(_CartItem item) async {
    setState(() {
      _isActionLoading = true;
    });
    try {
      await _service.deleteCartItem(item.id);
      await _reloadStoreData();
    } catch (e) {
      if (!mounted) return;
      _showError('Не удалось удалить из корзины: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _checkout() async {
    final storeId = _selectedStoreId;
    if (storeId == null || _selectedCartIds.isEmpty) return;
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оформить закупку'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Комментарий (опционально)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(side: const BorderSide(color: AppColors.brown)),
            child: Text('Отмена', style: AppText.medium_14.copyWith(color: AppColors.brown)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text('Оформить', style: AppText.medium_14.copyWith(color: AppColors.white_transparent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isActionLoading = true;
    });
    try {
      final data = await _service.checkout(
        storeId: storeId,
        cartItemIds: _selectedCartIds.toList(),
        comment: commentController.text,
      );
      await _reloadStoreData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Закупка оформлена: №${data['purchase_number'] ?? '-'}',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
      setState(() {
        _selectedCartIds = <int>{};
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Не удалось оформить закупку: $e');
    } finally {
      commentController.dispose();
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<int?> _showQuantityDialog({
    required String title,
    required int initialValue,
  }) async {
    var rawValue = '$initialValue';
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: rawValue,
          onChanged: (value) {
            rawValue = value;
          },
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Количество',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(side: const BorderSide(color: AppColors.brown)),
            child: Text('Отмена', style: AppText.medium_14.copyWith(color: AppColors.brown)),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(rawValue.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.of(ctx).pop(parsed);
            },
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text('Сохранить', style: AppText.medium_14.copyWith(color: AppColors.white_transparent)),
          ),
        ],
      ),
    );
    return value;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.white,
        content: Text(
          message,
          style: AppText.medium_14.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required String name,
    required int quantityAvailable,
    required double costPrice,
    required double basePrice,
    required String imageUrl,
    Widget? trailing,
    Widget? bottom,
  }) {
    final resolvedImage = ApiConfig.imageUrl(imageUrl).trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.grey_light),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: resolvedImage.isEmpty
                ? Container(width: 72, height: 72, color: AppColors.grey_light)
                : Image.network(
                    resolvedImage,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(width: 72, height: 72, color: AppColors.grey_light),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.medium_16.copyWith(color: AppColors.black)),
                const SizedBox(height: 4),
                Text(
                  'На складе: $quantityAvailable шт.',
                  style: AppText.medium_12.copyWith(
                    color: quantityAvailable <= 0 ? AppColors.error : AppColors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Закуп: ${costPrice.toStringAsFixed(2)} ₽ • Продажа: ${basePrice.toStringAsFixed(2)} ₽',
                  style: AppText.medium_12.copyWith(color: AppColors.grey),
                ),
                if (bottom != null) ...[
                  const SizedBox(height: 6),
                  bottom,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCheckout = _selectedCartIds.isNotEmpty && !_isActionLoading;

    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _reloadStoreData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Закупки', style: AppText.bold_18.copyWith(color: AppColors.black)),
                      const SizedBox(height: 12),
                      if (_stores.isNotEmpty)
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _selectedStoreId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Выбор магазина',
                          ),
                          selectedItemBuilder: (context) {
                            return _stores
                                .map(
                                  (s) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        '${s.name} • ${s.address}',
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                )
                                .toList();
                          },
                          items: _stores
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s.id,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      '${s.name} • ${s.address}',
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isActionLoading ? null : _onStoreChanged,
                        )
                      else
                        Text('Нет доступных магазинов', style: AppText.medium_14.copyWith(color: AppColors.error)),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _missingExpanded = !_missingExpanded;
                          });
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Отсутствующие товары (${_missingItems.length})',
                                style: AppText.bold_18.copyWith(color: AppColors.black),
                              ),
                            ),
                            Icon(
                              _missingExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.brown,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_missingExpanded)
                        if (_missingItems.isEmpty)
                          Text('Отсутствующих товаров нет', style: AppText.medium_14.copyWith(color: AppColors.grey))
                        else
                          ..._missingItems.map(
                            (item) => _buildProductCard(
                              name: item.name,
                              quantityAvailable: item.quantityAvailable,
                              costPrice: item.costPrice,
                              basePrice: item.basePrice,
                              imageUrl: item.imageUrl,
                              trailing: IconButton(
                                onPressed: _isActionLoading ? null : () => _addToCart(item),
                                icon: const Icon(Icons.add_shopping_cart, color: AppColors.brown),
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _catalogExpanded = !_catalogExpanded;
                          });
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Каталог (${_catalogItems.length})',
                                style: AppText.bold_18.copyWith(color: AppColors.black),
                              ),
                            ),
                            Icon(
                              _catalogExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.brown,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_catalogExpanded)
                        if (_catalogItems.isEmpty)
                          Text('Доступных товаров нет', style: AppText.medium_14.copyWith(color: AppColors.grey))
                        else
                          ..._catalogItems.map(
                            (item) => _buildProductCard(
                              name: item.name,
                              quantityAvailable: item.quantityAvailable,
                              costPrice: item.costPrice,
                              basePrice: item.basePrice,
                              imageUrl: item.imageUrl,
                              trailing: IconButton(
                                onPressed: _isActionLoading ? null : () => _addToCart(item),
                                icon: const Icon(Icons.add_shopping_cart, color: AppColors.brown),
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      Text('Корзина закупки (${_cartItems.length})', style: AppText.bold_18.copyWith(color: AppColors.black)),
                      const SizedBox(height: 8),
                      if (_cartItems.isEmpty)
                        Text('Корзина пуста', style: AppText.medium_14.copyWith(color: AppColors.grey))
                      else
                        ..._cartItems.map((item) {
                          final isSelected = _selectedCartIds.contains(item.id);
                          return _buildProductCard(
                            name: item.name,
                            quantityAvailable: item.quantityAvailable,
                            costPrice: item.costPrice,
                            basePrice: item.basePrice,
                            imageUrl: item.imageUrl,
                            bottom: Text(
                              'Заказать: ${item.quantityToOrder} шт.',
                              style: AppText.medium_12.copyWith(color: AppColors.brown),
                            ),
                            trailing: Column(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.brown,
                                  onChanged: _isActionLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedCartIds.add(item.id);
                                            } else {
                                              _selectedCartIds.remove(item.id);
                                            }
                                          });
                                        },
                                ),
                                IconButton(
                                  onPressed: _isActionLoading ? null : () => _changeCartQuantity(item),
                                  icon: const Icon(Icons.edit, color: AppColors.brown),
                                ),
                                IconButton(
                                  onPressed: _isActionLoading ? null : () => _removeCartItem(item),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: canCheckout ? _checkout : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.brown,
                          side: const BorderSide(color: AppColors.white),
                        ),
                        child: Text(
                          _isActionLoading ? 'Обработка...' : 'Оформить заказ',
                          style: AppText.medium_14.copyWith(color: AppColors.white_transparent),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StoreItem {
  final int id;
  final String name;
  final String address;

  const _StoreItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _StoreItem.fromJson(Map<String, dynamic> json) {
    return _StoreItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class _ProcurementItem {
  final int productId;
  final String name;
  final int quantityAvailable;
  final double costPrice;
  final double basePrice;
  final String imageUrl;

  const _ProcurementItem({
    required this.productId,
    required this.name,
    required this.quantityAvailable,
    required this.costPrice,
    required this.basePrice,
    required this.imageUrl,
  });

  factory _ProcurementItem.fromJson(Map<String, dynamic> json) {
    return _ProcurementItem(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      quantityAvailable: (json['quantity_available'] as num?)?.toInt() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}

class _CartItem extends _ProcurementItem {
  final int id;
  final int quantityToOrder;

  const _CartItem({
    required this.id,
    required this.quantityToOrder,
    required super.productId,
    required super.name,
    required super.quantityAvailable,
    required super.costPrice,
    required super.basePrice,
    required super.imageUrl,
  });

  factory _CartItem.fromJson(Map<String, dynamic> json) {
    return _CartItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      quantityToOrder: (json['quantity_to_order'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      quantityAvailable: (json['quantity_available'] as num?)?.toInt() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}
