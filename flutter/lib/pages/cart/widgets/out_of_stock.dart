import 'package:flutter/material.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/backend/models/cart.dart';

class OutOfStockCard extends StatelessWidget {
  final CartItemWithPot item;
  final Function(CartItemWithPot) onRemove;

  const OutOfStockCard({
    super.key,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24, left: 24, top: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.grey_light.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey_light),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildPlantImage(),
              const SizedBox(width: 16),
              _buildItemInfo(),
              _buildRemoveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantImage() {
    final imageUrl = item.plant.fullImageUrl.trim();
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
        // изображение
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isEmpty
                ? Container(
                    width: 80,
                    height: 60,
                    color: AppColors.grey_light,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 60,
                      color: AppColors.grey_light,
                    ),
                  ),
          ),
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.plant.name,
            style: AppText.bold_20.copyWith(
              color: AppColors.grey,
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (item.potDescription.isNotEmpty)
            Text(
              item.potDescription,
              style: AppText.medium_12.copyWith(
                color: AppColors.grey,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${item.quantity} шт × ${item.itemTotal} ₽',
            style: AppText.medium_14.copyWith(
              color: AppColors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Нет в наличии',
              style: AppText.medium_12.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton() {
    return IconButton(
      onPressed: () => onRemove(item),
      icon: Icon(
        Icons.close,
        color: AppColors.grey,
        size: 20,
      ),
    );
  }
}
