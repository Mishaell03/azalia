import 'package:azalia/backend/services/subscriptions.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
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
  State<SubscriptionCheckoutPage> createState() => _SubscriptionCheckoutPageState();
}

class _SubscriptionCheckoutPageState extends State<SubscriptionCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _checking = false;
  String? _error;

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
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.args.paymentUrl));
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final status = await SubscriptionService.getCheckoutStatus(widget.args.checkoutId);
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
        title: Text('Оформление ${widget.args.planName}', style: AppText.bold_18.copyWith(color: AppColors.black)),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          if (_loading) const LinearProgressIndicator(color: AppColors.brown),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: AppText.medium_14.copyWith(color: AppColors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkStatus,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brown),
                child: Text(
                  _checking ? 'Проверка...' : 'Я оплатил, проверить',
                  style: AppText.medium_14.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
