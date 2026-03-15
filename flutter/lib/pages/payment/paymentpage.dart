import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/models/payment/generate_response.dart';
import 'package:azalia/backend/services/payment.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentPage extends StatefulWidget {
  final PaymentRouteArgs args;

  const PaymentPage({super.key, required this.args});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final TextEditingController _addressController;
  late final PaymentService _paymentService;

  String? _addressError;
  String _savedAddress = '';
  int? _createdOrderId;
  int? _pendingPaymentLinkId;
  bool _paymentCompleted = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;
  bool _allowPop = false;
  String _paymentTiming = 'online';
  String _onDeliveryMethod = 'cash';
  String _orderType = 'delivery';
  bool _isLoadingStores = false;
  bool _isCheckingAvailability = false;
  int? _selectedPickupStoreId;
  List<_PickupStore> _pickupStores = const [];
  Map<int, _ItemAvailability> _availabilityByCartItem = const {};

  @override
  void initState() {
    super.initState();
    _savedAddress = (widget.args.address ?? '').trim();
    _addressController = TextEditingController(text: _savedAddress);
    _paymentService = PaymentService(ApiClient());
    _paymentTiming = widget.args.paymentTiming;
    _onDeliveryMethod =
        widget.args.onDeliveryMethod ?? widget.args.paymentMethod;
    if (_onDeliveryMethod != 'cash' && _onDeliveryMethod != 'card') {
      _onDeliveryMethod = 'cash';
    }
    _loadPickupStores();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'card':
        return 'Карта';
      case 'cash':
        return 'Наличные';
      case 'sbp':
        return 'СБП';
      default:
        return method;
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _normalizeError(Object error) {
    var message = error.toString().replaceAll('Exception: ', '');
    message = message.replaceAll('ApiException(status: 0, message: ', '');
    message = message.replaceAll(RegExp(r'\)$'), '');

    if (message.contains('Не удалось подключиться') ||
        message.contains('Timeout') ||
        message.contains('connection') ||
        message.contains('Ошибка сети')) {
      return '$message\n\nПроверьте интернет и отключите VPN.';
    }

    return message;
  }

  Map<int, _ItemAvailability> _buildAvailabilityMap(
    Map<String, dynamic> availability,
  ) {
    final availabilityItems = (availability['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final availabilityMap = <int, _ItemAvailability>{};
    for (final item in availabilityItems) {
      final cartItemId = (item['cart_item_id'] as num?)?.toInt();
      final requestedQty = (item['requested_quantity'] as num?)?.toInt() ?? 0;
      final availableQty = (item['available_quantity'] as num?)?.toInt() ?? 0;
      final missingQty =
          (item['missing_quantity'] as num?)?.toInt() ??
          (requestedQty > availableQty ? (requestedQty - availableQty) : 0);
      if (cartItemId != null && requestedQty > availableQty) {
        availabilityMap[cartItemId] = _ItemAvailability(
          availableQuantity: availableQty,
          missingQuantity: missingQty,
        );
      }
    }
    return availabilityMap;
  }

  Future<void> _loadPickupStores() async {
    setState(() {
      _isLoadingStores = true;
    });
    try {
      final rows = await _paymentService.getStores();
      final stores = rows
          .map(_PickupStore.fromJson)
          .where((s) => s.isActivePickupCandidate)
          .toList();
      if (!mounted) return;
      setState(() {
        _pickupStores = stores;
        _selectedPickupStoreId = stores.isNotEmpty ? stores.first.id : null;
      });
      await _refreshAvailabilityPreview();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupStores = const [];
        _selectedPickupStoreId = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
        });
      }
    }
  }

  Future<void> _refreshAvailabilityPreview() async {
    if (_orderType == 'pickup' && _selectedPickupStoreId == null) {
      if (!mounted) return;
      setState(() {
        _isCheckingAvailability = false;
        _availabilityByCartItem = const {};
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingAvailability = true;
      });
    }

    try {
      final availability = await _paymentService.checkAvailability(
        selectedItemIds: widget.args.selectedItemIds,
        orderType: _orderType,
        storeId: _orderType == 'pickup' ? _selectedPickupStoreId : null,
      );
      final availabilityMap = _buildAvailabilityMap(availability);
      if (!mounted) return;
      setState(() {
        _isCheckingAvailability = false;
        _availabilityByCartItem = availabilityMap;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingAvailability = false;
        _availabilityByCartItem = const {};
      });
    }
  }

  Future<bool> _confirmProceedWithoutMissing(
    List<Map<String, dynamic>> missingItems,
  ) async {
    final lines = <String>[];
    var hasRemovedItems = false;

    for (final item in missingItems) {
      final name = item['name']?.toString() ?? 'Товар';
      final available = (item['available_quantity'] as num?)?.toInt() ?? 0;
      final miss = (item['missing_quantity'] as num?)?.toInt() ?? 0;
      if (available <= 0) {
        hasRemovedItems = true;
        lines.add(
          '• $name — товара нет в наличии. Доступно: 0 шт. Товар будет исключен.',
        );
      } else {
        lines.add('• $name — доступно: $available шт., не хватает: $miss шт.');
      }
    }
    final message = lines.join('\n');
    final hint = hasRemovedItems
        ? 'Оформить заказ с доступным количеством? Недоступные товары будут исключены.'
        : 'Оформить заказ с доступным количеством?';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Не всё в наличии'),
        content: SingleChildScrollView(child: Text('$message\n\n$hint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
                side: BorderSide(
                    color: AppColors.brown
                )
            ),
            child: Text('Отмена', style: AppText.medium_14.copyWith(color: AppColors.brown),),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brown
            ),
            child: Text('Оформить с доступным', style: AppText.medium_14.copyWith(color: AppColors.white_transparent)),
          ),
        ],
      ),
    );
    return result == true;
  }

  String? _buildQuantityChangedNote(List<Map<String, dynamic>> missingItems) {
    if (missingItems.isEmpty) return null;

    final lines = <String>[];
    for (final item in missingItems) {
      final name = item['name']?.toString() ?? 'Товар';
      final requested = (item['requested_quantity'] as num?)?.toInt() ?? 0;
      final available = (item['available_quantity'] as num?)?.toInt() ?? 0;

      if (available <= 0) {
        lines.add('• $name: было $requested шт., станет 0 шт. (нет в наличии)');
      } else if (available < requested) {
        lines.add('• $name: было $requested шт., станет $available шт.');
      }
    }

    if (lines.isEmpty) return null;

    return 'Количество товаров будет изменено по остаткам:\n${lines.join('\n')}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.white,
        content: Text(
          message,
          style: AppText.medium_14.copyWith(
            color: isError ? AppColors.error : AppColors.brown,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _validateAddress() {
    final address = _addressController.text.trim();
    if (address.length < 5) {
      setState(() {
        _addressError = 'Введите корректный адрес доставки';
      });
      return false;
    }

    setState(() {
      _addressError = null;
    });
    return true;
  }

  Future<bool> _showPaymentWarning({String? quantityChangedNote}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, size: 25, color: AppColors.brown),
            const SizedBox(width: 10),
            Text(
              'Предупреждение',
              style: AppText.medium_20.copyWith(color: AppColors.black),
            ),
          ],
        ),
        content: Text(
          '${quantityChangedNote != null && quantityChangedNote.isNotEmpty ? '$quantityChangedNote\n\n' : ''}'
          'Если вы используете VPN, оплата может работать некорректно.\n\n'
          'Рекомендуем временно отключить VPN для успешного завершения платежа.',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: const BorderSide(color: AppColors.brown, width: 1.5),
                backgroundColor: AppColors.brown,
              ),
              child: Text(
                'Продолжить',
                style: AppText.semibold_18.copyWith(color: AppColors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: const BorderSide(color: AppColors.brown, width: 1.5),
              ),
              child: Text(
                'Отмена',
                style: AppText.semibold_18.copyWith(color: AppColors.brown),
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _cancelPendingPayment({bool showMessage = false}) async {
    final linkId = _pendingPaymentLinkId;
    if (linkId == null || _paymentCompleted || _isCancelling) {
      return;
    }

    _isCancelling = true;
    try {
      await _paymentService.cancelPaymentLink(linkId);
      _pendingPaymentLinkId = null;
      _createdOrderId = null;

      if (showMessage) {
        _showSnackBar('Платёж отменён');
      }
    } catch (e) {
      debugPrint('PaymentPage: ошибка отмены платежа $e');
      if (showMessage) {
        _showSnackBar('Не удалось отменить платёж', isError: true);
      }
    } finally {
      _isCancelling = false;
    }
  }

  Future<bool> _handlePageLeave() async {
    if (_isSubmitting) {
      return false;
    }

    await _cancelPendingPayment();
    return true;
  }

  Future<void> _requestPop() async {
    if (_allowPop) return;

    final canLeave = await _handlePageLeave();
    if (!mounted || !canLeave) return;

    setState(() {
      _allowPop = true;
    });
    Navigator.of(context).pop();
  }

  Future<void> _startPayment() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    if (_orderType == 'delivery') {
      if (!_validateAddress()) {
        _showSnackBar('Укажите корректный адрес доставки', isError: true);
        return;
      }
    } else {
      if (_selectedPickupStoreId == null) {
        _showSnackBar('Выберите точку самовывоза', isError: true);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    PaymentGenerateResponse? paymentResponse;
    try {
      var selectedIds = widget.args.selectedItemIds;
      var acceptQuantityChanges = false;
      String? quantityChangedNote;
      final availability = await _paymentService.checkAvailability(
        selectedItemIds: selectedIds,
        orderType: _orderType,
        storeId: _orderType == 'pickup' ? _selectedPickupStoreId : null,
      );
      if (mounted) {
        setState(() {
          _availabilityByCartItem = _buildAvailabilityMap(availability);
        });
      }

      final canProceed = availability['can_proceed'] == true;
      final availableItemIds =
          (availability['available_item_ids'] as List? ?? const [])
              .whereType<num>()
              .map((x) => x.toInt())
              .toList();
      final missingItems =
          (availability['missing_items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final hasUnavailableItems = missingItems.any(
        (item) => ((item['available_quantity'] as num?)?.toInt() ?? 0) <= 0,
      );

      if (!canProceed || availableItemIds.isEmpty) {
        _showSnackBar(
          _orderType == 'pickup'
              ? 'На выбранной точке нет товаров в наличии. Оформление невозможно.'
              : 'Нет товаров в наличии для доставки. Оформление невозможно.',
          isError: true,
        );
        return;
      }

      if (missingItems.isNotEmpty) {
        final confirmed = await _confirmProceedWithoutMissing(missingItems);
        if (!confirmed) {
          return;
        }
        selectedIds = availableItemIds;
        acceptQuantityChanges = true;
        quantityChangedNote = _buildQuantityChangedNote(missingItems);
        if (quantityChangedNote == null) {
          quantityChangedNote = hasUnavailableItems
              ? (_orderType == 'pickup'
                    ? 'Количество товаров изменено по остаткам выбранной точки самовывоза. Часть недоступных товаров будет исключена из заказа.'
                    : 'Количество товаров изменено по остаткам доступных магазинов. Часть недоступных товаров будет исключена из заказа.')
              : (_orderType == 'pickup'
                    ? 'Количество товаров изменено по остаткам выбранной точки самовывоза. Заказ будет оформлен с доступным количеством.'
                    : 'Количество товаров изменено по остаткам доступных магазинов. Заказ будет оформлен с доступным количеством.');
        }
      }

      if (_paymentTiming == 'online') {
        final confirmed = await _showPaymentWarning(
          quantityChangedNote: quantityChangedNote,
        );
        if (!confirmed || !context.mounted) return;
      }

      paymentResponse = await _paymentService.generatePaymentLink(
        address: _orderType == 'delivery' ? _addressController.text.trim() : null,
        paymentMethod: _paymentTiming == 'on_delivery'
            ? _onDeliveryMethod
            : 'card',
        paymentTiming: _paymentTiming,
        onDeliveryMethod: _paymentTiming == 'on_delivery'
            ? _onDeliveryMethod
            : null,
        orderType: _orderType,
        storeId: _orderType == 'pickup' ? _selectedPickupStoreId : null,
        selectedItemIds: selectedIds,
        acceptQuantityChanges: acceptQuantityChanges,
      );

      _savedAddress =
          (paymentResponse.address ?? _addressController.text.trim()).trim();
      _addressController.value = _addressController.value.copyWith(
        text: _savedAddress,
        selection: TextSelection.collapsed(offset: _savedAddress.length),
      );

      _createdOrderId = paymentResponse.orderId;
      _pendingPaymentLinkId = paymentResponse.paymentLinkId;

      if (!mounted) return;

      if (_paymentTiming == 'on_delivery') {
        _paymentCompleted = true;
        _pendingPaymentLinkId = null;
        _showSnackBar('✓ Заказ оформлен. Оплата при получении');
        context.goNamed('profileOrders');
        return;
      }

      final result = await context.pushNamed<bool>(
        'payment_webview',
        extra: PaymentWebViewArgs(
          paymentLinkId: paymentResponse.paymentLinkId,
          paymentUrl: paymentResponse.paymentUrl,
        ),
      );

      if (!mounted) return;

      if (result == true) {
        _paymentCompleted = true;
        _pendingPaymentLinkId = null;
        _showSnackBar('✓ Оплата прошла успешно!');
        context.goNamed('profileOrders');
        return;
      }

      if (result == false) {
        await _cancelPendingPayment(showMessage: true);
      }
    } catch (e) {
      if (paymentResponse != null) {
        await _cancelPendingPayment();
      }
      if (!mounted) return;
      final normalized = _normalizeError(e);
      if (normalized.toLowerCase().contains('timeout')) {
        try {
          final availability = await _paymentService.checkAvailability(
            selectedItemIds: widget.args.selectedItemIds,
            orderType: _orderType,
            storeId: _orderType == 'pickup' ? _selectedPickupStoreId : null,
          );
          if (!mounted) return;
          setState(() {
            _availabilityByCartItem = _buildAvailabilityMap(availability);
          });
          final canProceed = availability['can_proceed'] == true;
          final availableItemIds =
              (availability['available_item_ids'] as List? ?? const [])
                  .whereType<num>()
                  .map((x) => x.toInt())
                  .toList();
          if (!canProceed || availableItemIds.isEmpty) {
            _showSnackBar(
              _orderType == 'pickup'
                  ? 'На выбранной точке нет товаров в наличии. Оформление невозможно.'
                  : 'Нет товаров в наличии для доставки. Оформление невозможно.',
              isError: true,
            );
            return;
          }
        } catch (_) {}
      }
      _showSnackBar(normalized, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildItemsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Товары в заказе',
          style: AppText.bold_15.copyWith(color: AppColors.grey),
        ),
        const SizedBox(height: 12),
        ...widget.args.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.plantName,
                            style: AppText.semibold_18.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Кол-во: ${item.quantity} шт.',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                          if (_availabilityByCartItem[item.cartItemId] !=
                              null) ...[
                            const SizedBox(height: 4),
                            Builder(
                              builder: (_) {
                                final availability =
                                    _availabilityByCartItem[item.cartItemId]!;
                                if (availability.availableQuantity <= 0) {
                                  return Text(
                                    'Товара нет в наличии. Доступно: 0 шт.',
                                    style: AppText.medium_12.copyWith(
                                      color: AppColors.error,
                                    ),
                                  );
                                }
                                return Text(
                                  'Доступно: ${availability.availableQuantity} шт. вместо ${item.quantity} шт.',
                                  style: AppText.medium_12.copyWith(
                                    color: AppColors.error,
                                  ),
                                );
                              },
                            ),
                          ],
                          if (item.potPrice > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'С горшком: ${_formatCurrency(item.potPrice)} ₽',
                              style: AppText.medium_14.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatCurrency(item.itemTotal)} ₽',
                          style: AppText.medium_16.copyWith(
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatCurrency(item.plantPrice)} ₽/шт.',
                          style: AppText.medium_8.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (index < widget.args.items.length - 1)
                const Divider(
                  color: AppColors.grey_light,
                  height: 1,
                  thickness: 1,
                ),
            ],
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _createdOrderId != null
        ? 'Заказ №$_createdOrderId'
        : 'Оформление заказа';

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          iconTheme: const IconThemeData(color: AppColors.black),
          titleTextStyle: AppText.bold_18.copyWith(color: AppColors.black),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title,
                    style: AppText.bold_23.copyWith(color: AppColors.black),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white_transparent,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.brown, width: 1),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Способ получения',
                        style: AppText.bold_15.copyWith(color: AppColors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.grey_light),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Самовывоз',
                                style: AppText.medium_14.copyWith(
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            Switch(
                              value: _orderType == 'pickup',
                              activeThumbColor: AppColors.brown,
                              onChanged: _isSubmitting
                                  ? null
                                  : (enabled) async {
                                      setState(() {
                                        _orderType = enabled
                                            ? 'pickup'
                                            : 'delivery';
                                        if (!enabled) {
                                          _addressError = null;
                                        }
                                      });
                                      if (enabled &&
                                          _selectedPickupStoreId == null &&
                                          _pickupStores.isNotEmpty) {
                                        setState(() {
                                          _selectedPickupStoreId =
                                              _pickupStores.first.id;
                                        });
                                      }
                                      await _refreshAvailabilityPreview();
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_orderType == 'delivery') ...[
                        Text(
                          'Адрес доставки',
                          style: AppText.bold_15.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        Text(
                          'Область, город, улица, дом, квартира',
                          style: AppText.medium_12.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          minLines: 1,
                          onChanged: (value) {
                            if (_addressError != null &&
                                value.trim().length >= 5) {
                              setState(() {
                                _addressError = null;
                              });
                            }
                          },
                          style: AppText.medium_16.copyWith(
                            color: AppColors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Введите адрес доставки',
                            hintStyle: AppText.medium_14.copyWith(
                              color: AppColors.black_transparent,
                            ),
                            errorText: _addressError,
                            errorStyle: AppText.medium_12.copyWith(
                              color: AppColors.error,
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.grey_light,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.brown,
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.error,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Точка самовывоза',
                          style: AppText.bold_15.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingStores)
                          const LinearProgressIndicator()
                        else if (_pickupStores.isEmpty)
                          Text(
                            'Нет доступных точек самовывоза',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.error,
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _selectedPickupStoreId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Выберите точку',
                            ),
                            items: _pickupStores
                                .map(
                                  (store) => DropdownMenuItem<int>(
                                    value: store.id,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        '${store.name} • ${store.address}',
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) async {
                                    setState(() {
                                      _selectedPickupStoreId = value;
                                    });
                                    await _refreshAvailabilityPreview();
                                  },
                          ),
                      ],
                      if (_isCheckingAvailability) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _orderType == 'pickup'
                                    ? 'Проверяем наличие на выбранной точке...'
                                    : 'Проверяем наличие для доставки...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.medium_12.copyWith(
                                  color: AppColors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(
                        color: AppColors.brown,
                        height: 1,
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      _buildItemsBlock(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Метод оплаты',
                              style: AppText.medium_14.copyWith(
                                color: AppColors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brown.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatPaymentMethod(
                                _paymentTiming == 'on_delivery'
                                    ? _onDeliveryMethod
                                    : 'card',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.medium_12.copyWith(
                                color: AppColors.black_transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.grey_light),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Оплатить при получении',
                                style: AppText.medium_14.copyWith(
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            Switch(
                              value: _paymentTiming == 'on_delivery',
                              activeThumbColor: AppColors.brown,
                              onChanged: _isSubmitting
                                  ? null
                                  : (enabled) {
                                      setState(() {
                                        _paymentTiming = enabled
                                            ? 'on_delivery'
                                            : 'online';
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      if (_paymentTiming == 'on_delivery') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Наличные'),
                                selected: _onDeliveryMethod == 'cash',
                                onSelected: _isSubmitting
                                    ? null
                                    : (selected) {
                                        if (!selected) return;
                                        setState(() {
                                          _onDeliveryMethod = 'cash';
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Картой'),
                                selected: _onDeliveryMethod == 'card',
                                onSelected: _isSubmitting
                                    ? null
                                    : (selected) {
                                        if (!selected) return;
                                        setState(() {
                                          _onDeliveryMethod = 'card';
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.brown),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Итого к оплате',
                              style: AppText.medium_16.copyWith(
                                color: AppColors.black_transparent,
                              ),
                            ),
                            Text(
                              '${_formatCurrency(widget.args.totalPrice)} ₽',
                              style: AppText.bold_18.copyWith(
                                color: AppColors.black_transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brown,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : Text(
                            _paymentTiming == 'on_delivery'
                                ? 'Оформить заказ'
                                : 'Оплатить',
                            style: AppText.semibold_18.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _requestPop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: const BorderSide(
                        color: AppColors.brown,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Отмена',
                      style: AppText.semibold_18.copyWith(
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupStore {
  final int id;
  final String name;
  final String address;
  final String storeType;

  const _PickupStore({
    required this.id,
    required this.name,
    required this.address,
    required this.storeType,
  });

  bool get isActivePickupCandidate =>
      storeType == 'pickup_point' ||
      storeType == 'shop' ||
      storeType == 'warehouse';

  factory _PickupStore.fromJson(Map<String, dynamic> json) {
    return _PickupStore(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      storeType: json['store_type']?.toString() ?? '',
    );
  }
}

class _ItemAvailability {
  final int availableQuantity;
  final int missingQuantity;

  const _ItemAvailability({
    required this.availableQuantity,
    required this.missingQuantity,
  });
}
