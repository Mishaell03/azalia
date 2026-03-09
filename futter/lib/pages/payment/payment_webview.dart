import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewPage({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPage();
}

class _PaymentWebViewPage extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String _error = '';
  bool _paymentCompleted = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    debugPrint('PaymentWebViewPage: инициализация с URL: ${widget.paymentUrl}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('PaymentWebViewPage: onPageStarted: $url');
            setState(() {
              _loading = true;
              _error = '';
            });
          },
          onPageFinished: (String url) {
            debugPrint('PaymentWebViewPage: onPageFinished: $url');
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'PaymentWebViewPage: WebResourceError: ${error.description}',
            );
            setState(() {
              _error = 'Ошибка загрузки: ${error.description}';
              _loading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint(
              'PaymentWebViewPage: onNavigationRequest: ${request.url}',
            );
            // Разрешаем все навигации внутри Yookassa
            return NavigationDecision.navigate;
          },
        ),
      );

    try {
      debugPrint('PaymentWebViewPage: загружаем URL...');
      _controller.loadRequest(Uri.parse(widget.paymentUrl));
      debugPrint('PaymentWebViewPage: loadRequest выполнен');
    } catch (e) {
      debugPrint('PaymentWebViewPage: ошибка при loadRequest: $e');
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      debugPrint('PaymentWebViewPage: проверяем статус платежа...');

      // orderId из URL
      final Uri uri = Uri.parse(widget.paymentUrl);
      final String? orderId = uri.queryParameters['orderId'];

      if (orderId == null) {
        setState(() {
          _error = 'Не удалось определить ID платежа';
          _isCheckingStatus = false;
        });
        return;
      }

      final response = await http
          .get(Uri.parse('${ApiConfig.baseURL}/payments/status/$orderId'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      debugPrint('PaymentWebViewPage: статус ответ: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']?['status'] ?? data['status'];

        debugPrint('PaymentWebViewPage: статус платежа: $status');

        if (status == 'paid' || status == 'succeeded') {
          debugPrint('PaymentWebViewPage: оплата подтверждена! закрываем');
          setState(() {
            _paymentCompleted = true;
            _isCheckingStatus = false;
          });

          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _error = 'Платёж не завершён. Статус: $status';
            _isCheckingStatus = false;
          });
        }
      } else {
        setState(() {
          _error = 'Ошибка при проверке статуса (код ${response.statusCode})';
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      debugPrint('PaymentWebViewPage: ошибка при проверке статуса: $e');
      setState(() {
        _error = 'Ошибка: $e';
        _isCheckingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
        leading: IconButton(
          onPressed: () {
            debugPrint('PaymentWebViewPage: пользователь нажал закрыть');
            Navigator.pop(context, false);
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 500,
                    child: Image.asset('assets/images/error.png'),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: AppText.medium_16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsetsGeometry.symmetric(horizontal: 30),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _error = '';
                            _loading = true;
                          });
                          _controller.loadRequest(Uri.parse(widget.paymentUrl));
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: BorderSide(color: AppColors.brown, width: 1.5),
                        ),
                        child: Text(
                          'Повторить попытку',
                          style: AppText.semibold_18.copyWith(
                            color: AppColors.brown,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Загрузка платёжной страницы...',
                          style: AppText.medium_16,
                        ),
                      ],
                    ),
                  ),
                // Кнопка проверки статуса в низу
                if (!_loading && !_paymentCompleted)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCheckingStatus
                                ? null
                                : _checkPaymentStatus,
                            icon: _isCheckingStatus
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_sharp, size: 25,),
                            label: Text(
                              _isCheckingStatus
                                  ? 'Проверка...'
                                  : 'Проверить статус платежа',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brown,
                              foregroundColor: AppColors.white,
                              textStyle: AppText.medium_16,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
