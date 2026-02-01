import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/controllers/payment_flow.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/pages/cart/widgets/unauthorized.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/pages/cart/widgets/cards.dart';
import 'package:azalia/pages/cart/widgets/out_of_stock.dart';
import 'package:azalia/pages/cart/widgets/header.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:go_router/go_router.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItemWithPot> _cartItems = [];
  List<CartItemWithPot> _outOfStockItems = [];
  bool _isLoading = true;
  bool _isUnauthorized = false;
  String _error = '';
  double _totalPrice = 0;
  int _totalItems = 0;
  final SessionService _sessionService = SessionService();
  late final PaymentFlowController _paymentFlow;

  @override
  void initState() {
    super.initState();
    _paymentFlow = PaymentFlowController(ApiClient());
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _isUnauthorized = false;
    });
    try {
      final cartResponse = await CartService.getCart();
      _processCartItems(cartResponse.items);
    } catch (e) {
      _handleLoadError(e);
    }
  }

  void _handleUnauthorized() {
    setState(() {
      _isUnauthorized = true;
      _isLoading = false;
    });
  }

  void _processCartItems(List<CartItem> items) async {
    final List<CartItemWithPot> availableItems = [];
    final List<CartItemWithPot> outOfStockItems = [];

    for (final item in items) {
      final itemWithPot = CartItemWithPot.fromCartItem(item);

      if (item.plant.inStock && item.plant.stockQuantity > 0) {
        if (item.quantity > item.plant.stockQuantity) {
          await _autoReduceQuantity(item.id, item.plant.stockQuantity);
          availableItems.add(
            _createUpdatedItem(item, item.plant.stockQuantity),
          );
        } else {
          availableItems.add(itemWithPot);
        }
      } else {
        outOfStockItems.add(itemWithPot);
      }
    }

    final availableSummary = _calculateSummary(availableItems);

    setState(() {
      _cartItems = availableItems;
      _outOfStockItems = outOfStockItems;
      _totalPrice = availableSummary['totalPrice'];
      _totalItems = availableSummary['totalItems'];
      _isLoading = false;
      _isUnauthorized = false;
    });
  }

  CartItemWithPot _createUpdatedItem(CartItem item, int newQuantity) {
    return CartItemWithPot(
      id: item.id,
      userId: item.userId,
      plantId: item.plantId,
      quantity: newQuantity,
      potColor: item.potColor,
      potSize: item.potSize,
      potMaterial: item.potMaterial,
      plantUnitPrice: item.plantUnitPrice,
      potUnitPrice: item.potUnitPrice,
      totalPrice: (item.plantUnitPrice + item.potUnitPrice) * newQuantity,
      plant: item.plant,
    );
  }

  void _handleLoadError(dynamic e) {
    if (e.toString().contains('401') ||
        e.toString().contains('authorized') ||
        e.toString().contains('session') ||
        e.toString().contains('token')) {
      _handleUnauthorized();
      return;
    }

    setState(() {
      _error = 'Не удалось загрузить корзину';
      _isLoading = false;
    });
  }

  Future<void> _autoReduceQuantity(
    int itemId,
    int availableQuantity,
  ) async {
    try {
      await CartService.updateCartItem(itemId, availableQuantity);
    } catch (e) {
      debugPrint('Ошибка автоматического обновления количества: $e');
    }
  }

  Map<String, dynamic> _calculateSummary(List<CartItemWithPot> items) {
    double totalPrice = 0;
    int totalItems = 0;

    for (final item in items) {
      totalPrice += item.totalPrice;
      totalItems += item.quantity;
    }

    return {'totalPrice': totalPrice, 'totalItems': totalItems};
  }

  void _onItemRemoved(CartItemWithPot removedItem) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == removedItem.id);
      _totalPrice -= removedItem.totalPrice;
      _totalItems -= removedItem.quantity;
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

  void _removeOutOfStockItem(CartItemWithPot item) async {
    try {
      if (!_sessionService.isLoggedIn || !_sessionService.isTokenValid) {
        _handleUnauthorized();
        return;
      }
      
      await CartService.removeFromCart(item.id);
      setState(() {
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
      if (!_sessionService.isLoggedIn || !_sessionService.isTokenValid) {
        _handleUnauthorized();
        return;
      }

      await CartService.clearCart();

      setState(() {
        _cartItems.clear();
        _outOfStockItems.clear();
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
    if (_cartItems.isEmpty) {
      _showSnackBar(
        'Добавьте товары в корзину для оформления заказа',
        isError: true,
      );
      return;
    }

    try {
      // создаём оплату (заказ + ссылка)
      final payment = await _paymentFlow.startPayment(
        address: 'Гарабурды 16 дом 8', // позже экран ввода
        paymentMethod: 'card',
      );

      // открываем WebView оплаты
      final result = await context.pushNamed<bool>(
        'payment_webview',
        extra: payment.paymentUrl,
      );

      // обработка результата
      if (result == true) {
        _showSnackBar('Оплата прошла успешно', isError: false);

        // await CartService.clearCart();
        await _loadCart();
      } else {
        _showSnackBar('Оплата отменена', isError: true);
      }
    } catch (e, stack) {
      debugPrint('Checkout error: $e');
      debugPrint('ApiClient POST ERROR: $e');
      debugPrint('$stack');
      _showSnackBar(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
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
        ..._cartItems
            .map(
              (item) => CartCard(
                key: Key('cart_${item.id}'),
                item: item,
                onItemRemoved: _onItemRemoved,
                onQuantityChanged: _onQuantityChanged,
              ),
            )
            .toList(),

        if (_outOfStockItems.isNotEmpty) ...[
          _buildOutOfStockSection(),
          ..._outOfStockItems
              .map(
                (item) =>
                    OutOfStockCard(item: item, onRemove: _removeOutOfStockItem),
              )
              .toList(),
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
              onPressed: _cartItems.isNotEmpty ? _proceedToCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cartItems.isNotEmpty
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
                  color: _cartItems.isNotEmpty
                      ? AppColors.white
                      : AppColors.grey,
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