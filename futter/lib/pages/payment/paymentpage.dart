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

  @override
  void initState() {
    super.initState();
    _savedAddress = (widget.args.address ?? '').trim();
    _addressController = TextEditingController(text: _savedAddress);
    _paymentService = PaymentService(ApiClient());
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String _formatPaymentMethod(String method) {
    return method == 'card' ? 'Карта' : 'Наличные';
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

  Future<bool> _showPaymentWarning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber,
              size: 25,
              color: AppColors.brown,
            ),
            const SizedBox(width: 10),
            Text(
              'Предупреждение',
              style: AppText.medium_20.copyWith(color: AppColors.black),
            ),
          ],
        ),
        content: Text(
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

    if (!_validateAddress()) {
      _showSnackBar('Укажите корректный адрес доставки', isError: true);
      return;
    }

    final confirmed = await _showPaymentWarning();
    if (!confirmed || !context.mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    PaymentGenerateResponse? paymentResponse;
    try {
      paymentResponse = await _paymentService.generatePaymentLink(
        address: _addressController.text.trim(),
        paymentMethod: widget.args.paymentMethod,
        selectedItemIds: widget.args.selectedItemIds,
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
        context.go('/');
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
      _showSnackBar(_normalizeError(e), isError: true);
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
                      _buildItemsBlock(),
                      const SizedBox(height: 12),
                      const Divider(
                        color: AppColors.brown,
                        height: 1,
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Адрес доставки',
                        style: AppText.bold_15.copyWith(color: AppColors.grey),
                      ),
                      Text(
                        'Область, город, улица, дом, квартира',
                        style: AppText.medium_12.copyWith(color: AppColors.grey),
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Метод оплаты',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
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
                              _formatPaymentMethod(widget.args.paymentMethod),
                              style: AppText.medium_12.copyWith(
                                color: AppColors.black_transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                            'Оплатить',
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
