import 'package:flutter/material.dart';
import 'package:azalia/components/text_styles.dart';

class ErrorPage extends StatelessWidget{
  const ErrorPage ({super.key});
// временная заглушка
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ERROR',style: AppText.semibold_15,)
          ],
        ),
      ),
    );
  }
}