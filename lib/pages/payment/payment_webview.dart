import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewPage({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPage();
}

class _PaymentWebViewPage extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _loading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _loading = false;
            });
            if (url.contains('payment-success')) {
              Navigator.pop(context, true);
            }
            if (url.contains('payment-cancel')) {
              Navigator.pop(context, false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
