import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';

class IconItem {
  final IconData ico;
  final String value;
  final String label;

  const IconItem({required this.ico, required this.label, required this.value});
}

class IconValueSelector extends StatelessWidget {
  final List<IconItem> items;
  final String selectedValue;
  final Function(String) onSelected;

  const IconValueSelector({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final bool isActive = item.value == selectedValue;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item.value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.all(isActive ? 12 : 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.white_dark : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.ico,
                    size: isActive ? 28 : 24,
                    color: isActive
                        ? AppColors.brown
                        : AppColors.black_transparent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    textAlign: TextAlign.center,
                    item.label,
                    style: (isActive ? AppText.medium_14 : AppText.medium_12).copyWith(
                      color: isActive
                          ? AppColors.brown
                          : AppColors.black_transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// иконки требуемого овещения
final lightItems = [
  IconItem(value: 'full_sun', ico: Icons.wb_sunny, label: 'Солнце'),
  IconItem(value: 'partial_shade', ico: Icons.wb_twilight, label: 'Полутень'),
  IconItem(value: 'shade', ico: Icons.nights_stay, label: 'Тень'),
];

final potSizeItems = [
  IconItem(value: 'S', ico: Icons.crop_square, label: 'S'),
  IconItem(value: 'M', ico: Icons.crop_5_4, label: 'M'),
  IconItem(value: 'L', ico: Icons.check_box_outline_blank, label: 'L'),
  IconItem(value: 'XL', ico: Icons.crop_din, label: 'XL'),
];