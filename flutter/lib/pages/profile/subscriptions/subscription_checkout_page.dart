import 'dart:async';

import 'package:azalia/backend/services/subscriptions.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubscriptionCheckoutPageArgs {
  final int checkoutId;
  final String paymentUrl;
  final String planName;

  SubscriptionCheckoutPageArgs({
    required this.checkoutId,
    required this.paymentUrl,
    required this.planName,
  });
}

class SubscriptionCheckoutPage extends StatefulWidget {
  final SubscriptionCheckoutPageArgs args;

  const SubscriptionCheckoutPage({super.key, required this.args});

  @override
  State<SubscriptionCheckoutPage> createState() =>
      _SubscriptionCheckoutPageState();
}

class _SubscriptionCheckoutPageState extends State<SubscriptionCheckoutPage> {
  static const Duration _webViewFallbackTimeout = Duration(seconds: 8);

  late final WebViewController _controller;
  Timer? _fallbackTimer;
  bool _loading = true;
  bool _checking = false;
  String _error = '';
  bool _isLaunchingExternal = false;
  bool _isErrorDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = '';
            });
            _scheduleFallbackTimer();
          },
          onPageFinished: (_) {
            _fallbackTimer?.cancel();
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (_) {
            _showWebViewError('Не удалось открыть страницу оплаты');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.args.paymentUrl));
    _scheduleFallbackTimer();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _scheduleFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_webViewFallbackTimeout, () {
      if (!_loading) return;
      _showWebViewError('Страница оплаты не открылась');
    });
  }

  void _showWebViewError(String message) {
    _fallbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = '$message\n\nПопробуйте оплатить через браузер';
    });
    _showBrowserFallbackDialog();
  }

  Future<void> _openInBrowser() async {
    if (_isLaunchingExternal) return;
    final uri = Uri.tryParse(widget.args.paymentUrl);
    if (uri == null) {
      _showSnackBar('Ссылка на оплату некорректна', isError: true);
      return;
    }

    setState(() => _isLaunchingExternal = true);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      _showSnackBar(
        ok ? 'Оплата открыта в браузере' : 'Не удалось открыть браузер',
        isError: !ok,
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunchingExternal = false);
      }
    }
  }

  Future<void> _showBrowserFallbackDialog() async {
    if (!mounted || _isErrorDialogVisible) return;
    _isErrorDialogVisible = true;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, size: 25, color: AppColors.brown),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Страница недоступна',
                maxLines: 2,
                style: AppText.medium_20.copyWith(color: AppColors.black),
              ),
            ),
          ],
        ),
        content: Text(
          'Не удалось открыть страницу оплаты внутри приложения.\n\nОткрыть оплату во внешнем браузере?',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: const BorderSide(color: AppColors.brown, width: 1.5),
                backgroundColor: AppColors.brown,
              ),
              child: Text(
                'Открыть в браузере',
                style: AppText.semibold_18.copyWith(color: AppColors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
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
    _isErrorDialogVisible = false;
    if (open == true) {
      await _openInBrowser();
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
      ),
    );
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    try {
      final status = await SubscriptionService.getCheckoutStatus(
        widget.args.checkoutId,
      );
      if (!mounted) return;
      if (status.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              'Подписка активирована. Автоплатеж включен.',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = 'Статус оплаты: ${status.status}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось проверить статус: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text(
          'Оформление ${widget.args.planName}',
          style: AppText.bold_18.copyWith(color: AppColors.black),
        ),
      ),
      body: _error.isNotEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
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
                        onPressed: _checking ? null : _checkStatus,
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
                        icon: _checking
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
                          _checking ? 'Проверка...' : 'Проверить оплату',
                          style: AppText.semibold_18.copyWith(
                            color: AppColors.brown,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                if (!_loading)
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
                            onPressed: _checking ? null : _checkStatus,
                            icon: _checking
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
                                : const Icon(
                                    Icons.check_circle_sharp,
                                    size: 25,
                                  ),
                            label: Text(
                              _checking
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
