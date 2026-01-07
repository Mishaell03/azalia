import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool necessarily;
  final bool isDouble;

  const AppTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.necessarily = true,
    this.isDouble = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isDouble? TextInputType.number : TextInputType.text,
      inputFormatters: isDouble
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: AppText.medium_14.copyWith(color: AppColors.grey),
      decoration: InputDecoration(

        labelText: necessarily? '$labelText *' : labelText,
        errorStyle: AppText.medium_14.copyWith(color: AppColors.error),
        floatingLabelStyle: AppText.medium_14.copyWith(color: AppColors.grey),
        labelStyle: AppText.medium_14.copyWith(color: AppColors.black_transparent),
        border: OutlineInputBorder(),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.grey_light,
            width: 1.5,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: AppColors.brown,
            width: 2,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}
