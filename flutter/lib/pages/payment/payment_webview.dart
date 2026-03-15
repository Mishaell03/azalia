import 'dart:async';

import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final int paymentLinkId;

  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.paymentLinkId,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPage();
}

class _PaymentWebViewPage extends State<PaymentWebViewPage>
    with WidgetsBindingObserver {
  static const Duration _webViewFallbackTimeout = Duration(seconds: 8);

  final ApiClient _api = ApiClient();
  late final WebViewController _controller;

  Timer? _fallbackTimer;
  bool _loading = true;
  String _error = '';
  bool _paymentCompleted = false;
  bool _isCheckingStatus = false;
  bool _isLaunchingExternal = false;
  bool _externalBrowserOpened = false;

  bool _isPaidStatus(String? rawStatus) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    return status == 'paid' ||
        status == 'succeeded' ||
        status == 'оплачен' ||
        status == 'оплачено';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('PaymentWebViewPage: инициализация с URL: ${widget.paymentUrl}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('PaymentWebViewPage: onPageStarted: $url');
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = '';
            });
            _scheduleFallbackTimer();
          },
          onPageFinished: (String url) {
            debugPrint('PaymentWebViewPage: onPageFinished: $url');
            _fallbackTimer?.cancel();

            final uri = Uri.tryParse(url);
            final status =
                uri?.queryParameters['payment_status'] ??
                uri?.queryParameters['status'];
            if (_isPaidStatus(status) && mounted) {
              Navigator.pop(context, true);
              return;
            }

            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'PaymentWebViewPage: WebResourceError: ${error.description}',
            );
            _showWebViewError(
              'Не удалось открыть оплату',
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint(
              'PaymentWebViewPage: onNavigationRequest: ${request.url}',
            );
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadPaymentUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _externalBrowserOpened &&
        !_paymentCompleted) {
      _checkPaymentStatus(silent: true);
    }
  }

  void _loadPaymentUrl() {
    try {
      debugPrint('PaymentWebViewPage: загружаем URL...');
      _scheduleFallbackTimer();
      _controller.loadRequest(Uri.parse(widget.paymentUrl));
      debugPrint('PaymentWebViewPage: loadRequest выполнен');
    } catch (e) {
      debugPrint('PaymentWebViewPage: ошибка при loadRequest: $e');
      _showWebViewError(
        'Не удалось подготовить страницу оплаты',
      );
    }
  }

  void _scheduleFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_webViewFallbackTimeout, () {
      if (!_loading || _paymentCompleted || _externalBrowserOpened) {
        return;
      }
      _showWebViewError(
        'Страница оплаты не открылась',
      );
    });
  }

  void _showWebViewError(String message) {
    _fallbackTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = '$message\n\nПопробуйте оплатить через браузер';
    });
  }

  Future<void> _openInBrowser({bool showErrorSnackBar = true}) async {
    if (_isLaunchingExternal) return;

    final uri = Uri.tryParse(widget.paymentUrl);
    if (uri == null) {
      if (showErrorSnackBar) {
        _showSnackBar('Ссылка на оплату некорректна', isError: true);
      }
      return;
    }

    setState(() {
      _isLaunchingExternal = true;
    });

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (launched) {
        _externalBrowserOpened = true;
        _showSnackBar('Оплата открыта в браузере');
      } else if (showErrorSnackBar) {
        _showSnackBar('Не удалось открыть браузер', isError: true);
      }
    } catch (e) {
      if (mounted && showErrorSnackBar) {
        _showSnackBar('Не удалось открыть браузер', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingExternal = false;
        });
      }
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
            color: isError ? AppColors.error : AppColors.brown,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      debugPrint('PaymentWebViewPage: проверяем статус платежа...');
      final response = await _api.get(
        ApiConfig.paymentLinkStatus(widget.paymentLinkId),
      );

      if (!mounted) return;

      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final status = data['status']?.toString();
      final statusCode = data['status_code']?.toString();
      debugPrint('PaymentWebViewPage: статус платежа: $status, код: $statusCode');

      if (_isPaidStatus(statusCode) || _isPaidStatus(status)) {
        setState(() {
          _paymentCompleted = true;
          _isCheckingStatus = false;
        });
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _isCheckingStatus = false;
        if (!silent) {
          _error = 'Платёж не завершён. Статус: ${status ?? statusCode ?? 'unknown'}';
        }
      });
    } catch (e) {
      debugPrint('PaymentWebViewPage: ошибка при проверке статуса: $e');
      if (!mounted) return;
      setState(() {
        _isCheckingStatus = false;
        if (!silent) {
          _error = 'Ошибка: $e';
        }
      });
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            SizedBox(
              height: 320,
              child: Image.asset('assets/images/error.png'),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: AppText.medium_16.copyWith(color: AppColors.black),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLaunchingExternal ? null : _openInBrowser,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: AppColors.brown,
                ),
                child: _isLaunchingExternal
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Открыть в браузере',
                        style: AppText.semibold_18.copyWith(
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isCheckingStatus ? null : () => _checkPaymentStatus(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.brown,
                  side: const BorderSide(
                    color: AppColors.brown,
                    width: 1.5,
                  ),
                ),
                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brown,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isCheckingStatus ? 'Проверка...' : 'Проверить оплату',
                  style: AppText.semibold_18.copyWith(
                    color: AppColors.brown,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _error = '';
                    _loading = true;
                  });
                  _loadPaymentUrl();
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
                  'Повторить попытку',
                  style: AppText.semibold_18.copyWith(
                    color: AppColors.brown,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
        leading: IconButton(
          onPressed: () {
            debugPrint('PaymentWebViewPage: закрыть');
            Navigator.pop(context, false);
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: _error.isNotEmpty
          ? _buildErrorView()
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brown,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Загрузка платёжной страницы...',
                          style: AppText.medium_16,
                        ),
                      ],
                    ),
                  ),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_externalBrowserOpened) ...[
                              Text(
                                'Если оплата открыта в браузере, после возврата статус проверится автоматически.',
                                textAlign: TextAlign.center,
                                style: AppText.medium_12.copyWith(
                                  color: AppColors.grey,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isCheckingStatus
                                    ? null
                                    : () => _checkPaymentStatus(),
                                icon: _isCheckingStatus
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_sharp,
                                        size: 25,
                                      ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
