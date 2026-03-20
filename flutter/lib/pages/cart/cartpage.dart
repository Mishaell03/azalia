import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/account_blocked_notice.dart';
import 'package:azalia/pages/cart/widgets/unauthorized.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/selected_items_service.dart';
import 'package:azalia/pages/cart/widgets/cards.dart';
import 'package:azalia/pages/cart/widgets/out_of_stock.dart';
import 'package:azalia/pages/cart/widgets/header.dart';
import 'package:azalia/pages/error/app_errors.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/router.dart';
import 'package:azalia/components/state/auth_guarded_state.dart';
import 'package:go_router/go_router.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends AuthGuardedState<CartPage> {
  List<CartItemWithPot> _cartItems = [];
  List<CartItemWithPot> _outOfStockItems = [];
  bool _isLoading = true;
  bool _isUnauthorized = false;
  String _error = '';
  double _totalPrice = 0;
  int _totalItems = 0;
  Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    safeSetState(() {
      _isLoading = true;
      _error = '';
      _isUnauthorized = false;
    });
    try {
      final cartResponse = await CartService.getCart();
      await _processCartItems(cartResponse.items);
    } catch (e) {
      if (!mounted) return;
      _handleLoadError(e);
    }
  }

  void _handleUnauthorized() {
    safeSetState(() {
      _isUnauthorized = true;
      _isLoading = false;
    });
  }

  Future<void> _processCartItems(List<CartItem> items) async {
    final List<CartItemWithPot> availableItems = [];
    final List<CartItemWithPot> outOfStockItems = [];

    for (final item in items) {
      final itemWithPot = CartItemWithPot.fromCartItem(item);
      final isRemovedFromSale =
          !item.plant.isActive || item.plant.deletedAt != null;

      if (isRemovedFromSale) {
        outOfStockItems.add(itemWithPot);
      } else {
        availableItems.add(itemWithPot);
      }
    }

    // Загружаем сохраненные выбранные товары
    final savedSelectedIds = await SelectedItemsService.getSelectedItems();
    final selectedIds = savedSelectedIds.toSet();

    final availableSummary = _calculateSummary(availableItems, selectedIds);

    safeSetState(() {
      _cartItems = availableItems;
      _outOfStockItems = outOfStockItems;
      _selectedItemIds = selectedIds;
      _totalPrice = availableSummary['totalPrice'];
      _totalItems = availableSummary['totalItems'];
      _isLoading = false;
      _isUnauthorized = false;
    });
  }

  void _handleLoadError(dynamic e) {
    if (isForbiddenAccountError(e)) {
      safeSetState(() {
        _error = AppErrors.accountBlockedMessage;
        _isLoading = false;
        _isUnauthorized = false;
      });
      return;
    }

    if (isUnauthorizedError(e)) {
      _handleUnauthorized();
      return;
    }

    safeSetState(() {
      _error = 'Не удалось загрузить корзину';
      _isLoading = false;
    });
  }

  Map<String, dynamic> _calculateSummary(
    List<CartItemWithPot> items, [
    Set<int>? selectedIds,
  ]) {
    double totalPrice = 0;
    int totalItems = 0;
    final idsToCheck = selectedIds ?? _selectedItemIds;

    for (final item in items) {
      if (idsToCheck.contains(item.id)) {
        totalPrice += item.totalPrice;
        totalItems += item.quantity;
      }
    }

    return {'totalPrice': totalPrice, 'totalItems': totalItems};
  }

  void _onItemRemoved(CartItemWithPot removedItem) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == removedItem.id);
      if (_selectedItemIds.contains(removedItem.id)) {
        _selectedItemIds.remove(removedItem.id);
        _totalPrice -= removedItem.totalPrice;
        _totalItems -= removedItem.quantity;
      }
    });
  }

  void _onQuantityChanged(CartItemWithPot item, int newQuantity) {
    setState(() {
      final difference = newQuantity - item.quantity;
      _totalPrice += item.itemTotal * difference;
      _totalItems += difference;

      final index = _cartItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        final updatedItem = CartItemWithPot(
          id: item.id,
          userId: item.userId,
          plantId: item.plantId,
          quantity: newQuantity,
          potColor: item.potColor,
          potSize: item.potSize,
          potMaterial: item.potMaterial,
          plantUnitPrice: item.plantUnitPrice,
          potUnitPrice: item.potUnitPrice,
          totalPrice: item.itemTotal * newQuantity,
          plant: item.plant,
        );
        _cartItems[index] = updatedItem;
      }
    });
  }

  void _onSelectionChanged(CartItemWithPot item, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedItemIds.add(item.id);
        _totalPrice += item.totalPrice;
        _totalItems += item.quantity;
      } else {
        _selectedItemIds.remove(item.id);
        _totalPrice -= item.totalPrice;
        _totalItems -= item.quantity;
      }
    });
  }

  void _removeOutOfStockItem(CartItemWithPot item) async {
    try {
      if (!hasValidSession) {
        _handleUnauthorized();
        return;
      }

      await CartService.removeFromCart(item.id);
      safeSetState(() {
        _outOfStockItems.removeWhere((i) => i.id == item.id);
      });

      _showSnackBar('Товар удален из корзины', isError: false);
    } catch (e) {
      debugPrint('Ошибка удаления недоступного товара: $e');
      _showSnackBar('Не удалось удалить товар', isError: true);
    }
  }

  Future<void> _clearCart() async {
    try {
      if (!hasValidSession) {
        _handleUnauthorized();
        return;
      }

      await CartService.clearCart();
      await SelectedItemsService.clearSelectedItems();

      safeSetState(() {
        _cartItems.clear();
        _outOfStockItems.clear();
        _selectedItemIds.clear();
        _totalPrice = 0;
        _totalItems = 0;
      });

      _showSnackBar('Корзина очищена', isError: false);
    } catch (e) {
      debugPrint('Ошибка очистки корзины: $e');
      _showSnackBar('Не удалось очистить корзину', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.white,
        content: Text(
          message,
          style: AppText.medium_14.copyWith(
            color: isError ? AppColors.error : AppColors.black,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    final selectedItems = _cartItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList();

    if (selectedItems.isEmpty) {
      _showSnackBar('Выберите товары для оформления заказа', isError: true);
      return;
    }

    try {
      if (!context.mounted) return;

      final selectedItemIds = _selectedItemIds.toList();
      final paymentItems = selectedItems
          .map(
            (item) => PaymentItemArgs(
              cartItemId: item.id,
              plantName: item.plant.name,
              quantity: item.quantity,
              plantPrice: item.plantUnitPrice,
              potPrice: item.potUnitPrice,
              itemTotal: item.totalPrice,
            ),
          )
          .toList();

      context.pushNamed(
        'payment',
        extra: PaymentRouteArgs(
          totalPrice: _totalPrice,
          address: null,
          paymentMethod: 'card',
          selectedItemIds: selectedItemIds,
          items: paymentItems,
        ),
      );
    } catch (e, stack) {
      debugPrint('_proceedToCheckout error: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        final errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException(status: 0, message: ', '')
            .replaceAll(')', '');
        _showSnackBar(errorMessage, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CartHeader(
        itemCount: _totalItems,
        onClearCart: _cartItems.isNotEmpty ? _clearCart : null,
      ),
      bottomNavigationBar: const AppFooter(items: userFooterItems),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_isUnauthorized) {
      return CartlistUnauthorized();
    }

    if (_error.isNotEmpty) {
      if (_error == AppErrors.accountBlockedMessage) {
        return const AccountBlockedNotice();
      }
      return GenericErrorWidget(onRetry: _loadCart);
    }

    if (_cartItems.isEmpty && _outOfStockItems.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCart,
            child: _buildCartItemsList(),
          ),
        ),
        _buildCheckoutSection(),
      ],
    );
  }

  Widget _buildCartItemsList() {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      children: [
        ..._cartItems.map(
          (item) => CartCard(
            key: Key('cart_${item.id}'),
            item: item,
            onItemRemoved: _onItemRemoved,
            onQuantityChanged: _onQuantityChanged,
            onSelectionChanged: _onSelectionChanged,
          ),
        ),

        if (_outOfStockItems.isNotEmpty) ...[
          _buildOutOfStockSection(),
          ..._outOfStockItems.map(
            (item) =>
                OutOfStockCard(item: item, onRemove: _removeOutOfStockItem),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/cart.png',
            fit: BoxFit.contain,
            width: 230,
          ),
          const SizedBox(height: 30),
          Text(
            'Корзина пуста',
            style: AppText.bold_20.copyWith(color: AppColors.black),
          ),
          const SizedBox(height: 12),
          Text(
            'Добавляйте товары в корзину,\nчтобы сделать заказ',
            style: AppText.medium_16.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.goNamed('home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brown,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'На главную',
              style: AppText.medium_16.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.grey_light),
          const SizedBox(height: 16),
          Text(
            'Нет в наличии',
            style: AppText.bold_18.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Эти товары временно недоступны и не будут включены в заказ',
            style: AppText.medium_14.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection() {
    final hasSelectedItems = _selectedItemIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey_light)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Итого',
                style: AppText.medium_16.copyWith(color: AppColors.black),
              ),
              Text(
                '$_totalPrice ₽',
                style: AppText.bold_20.copyWith(color: AppColors.black),
              ),
            ],
          ),
          if (!hasSelectedItems && _cartItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Выберите товары для оформления',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ],
          if (_outOfStockItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_outOfStockItems.length} ${_getItemText(_outOfStockItems.length)} недоступно',
              style: AppText.medium_14.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasSelectedItems ? _proceedToCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedItems
                    ? AppColors.brown
                    : AppColors.grey_light,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Перейти к оформлению',
                style: AppText.medium_16.copyWith(
                  color: hasSelectedItems ? AppColors.white : AppColors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getItemText(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'товар';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'товара';
    }
    return 'товаров';
  }
}
