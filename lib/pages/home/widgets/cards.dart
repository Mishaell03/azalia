import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';

class PlantCard extends StatefulWidget {
  final Plant plant;

  const PlantCard({super.key, required this.plant});

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> {
  bool _hasImageError = false;

  void _retryLoadImage() {
    setState(() {
      _hasImageError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.plant.inStock) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24, left: 24, top: 16),
      child: Row(
        children: [
          _buildPlantImage(),
          const SizedBox(width: 20),
          _buildPlantInfo(),
        ],
      ),
    );
  }

  Widget _buildPlantImage() {
    return Container(
      width: 113,
      height: 88,
      decoration: BoxDecoration(),
      child: _hasImageError
          ? _buildErrorPlaceholder()
          : _buildCachedImage(),
    );
  }

  Widget _buildErrorPlaceholder() {
    return GestureDetector(
      onTap: _retryLoadImage,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.grey_light,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 30, color: AppColors.grey),
            const SizedBox(height: 4),
            Text(
              'Повторить',
              style: AppText.medium_14.copyWith(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: widget.plant.fullImageUrl,
        width: 113,
        height: 88,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildLoadingIndicator(),
        errorWidget: (context, url, error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasImageError = true;
              });
            }
          });
          return _buildErrorPlaceholder();
        },
        cacheKey: widget.plant.fullImageUrl,
        maxWidthDiskCache: 300,
        maxHeightDiskCache: 300,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildPlantInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.plant.name,
                  style: AppText.bold_18.copyWith(color: AppColors.black),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.plant.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/icons/Star.svg'),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.plant.rating}',
                      style: AppText.semibold_13.copyWith(
                        color: AppColors.star,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (widget.plant.heightCm != null)
            Text(
              'Высота до ${widget.plant.heightCm} см',
              style: AppText.medium_14.copyWith(
                color: AppColors.black_transparent,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${widget.plant.basePrice} ₽',
            style: AppText.medium_16.copyWith(color: AppColors.black),
          ),
        ],
      ),
    );
  }
}