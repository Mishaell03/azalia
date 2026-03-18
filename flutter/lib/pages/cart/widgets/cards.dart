import 'package:flutter/material.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/components/widgets/love.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/selected_items_service.dart';
import 'package:azalia/pages/plant/plant_details_page.dart';
import 'package:go_router/go_router.dart';

class CartCard extends StatefulWidget {
  final CartItemWithPot item;
  final Function(CartItemWithPot)? onItemRemoved;
  final Function(CartItemWithPot, int)? onQuantityChanged;
  final Function(CartItemWithPot, bool)? onSelectionChanged;

  const CartCard({
    super.key,
    required this.item,
    this.onItemRemoved,
    this.onQuantityChanged,
    this.onSelectionChanged,
  });

  @override
  State<CartCard> createState() => _CartCardState();
}

class _CartCardState extends State<CartCard> {
  bool _hasImageError = false;
  bool _showCard = true;
  bool _isRemoving = false;
  bool _isUpdatingQuantity = false;
  bool _isSelected = false;

  @override
  void initState() {
    super.initState();
    _loadSelectionState();
  }

  void _loadSelectionState() async {
    final isSelected = await SelectedItemsService.isItemSelected(widget.item.id);
    if (mounted) {
      setState(() {
        _isSelected = isSelected;
      });
    }
  }

  void _toggleSelection() async {
    final newState = !_isSelected;
    setState(() {
      _isSelected = newState;
    });
    
    if (newState) {
      await SelectedItemsService.addSelectedItem(widget.item.id);
    } else {
      await SelectedItemsService.removeSelectedItem(widget.item.id);
    }
    
    widget.onSelectionChanged?.call(widget.item, newState);
  }

  void _retryLoadImage() {
    setState(() {
      _hasImageError = false;
    });
  }

  void _removeFromCart() async {
    if (_isRemoving) return;

    setState(() {
      _isRemoving = true;
    });

    try {
      await CartService.removeFromCart(widget.item.id);
      _handleRemoveSuccess();
    } catch (e) {
      _handleRemoveError(e);
    } finally {
      _resetRemoveState();
    }
  }

  void _handleRemoveSuccess() {
    setState(() {
      _showCard = false;
    });
    widget.onItemRemoved?.call(widget.item);
  }

  void _handleRemoveError(dynamic e) {
    debugPrint('Ошибка удаления из корзины: $e');
    _showErrorSnackBar('Не удалось удалить товар');
  }

  void _resetRemoveState() {
    if (mounted) {
      setState(() {
        _isRemoving = false;
      });
    }
  }

  void _updateQuantity(int newQuantity) async {
    if (_isUpdatingQuantity) return;

    if (newQuantity == 0) {
      _removeFromCart();
      return;
    }

    setState(() {
      _isUpdatingQuantity = true;
    });

    try {
      await CartService.updateCartItem(widget.item.id, newQuantity);
      widget.onQuantityChanged?.call(widget.item, newQuantity);
    } catch (e) {
      _handleQuantityUpdateError(e);
    } finally {
      _resetQuantityUpdateState();
    }
  }

  void _handleQuantityUpdateError(dynamic e) {
    debugPrint('Ошибка обновления количества: $e');
    _showErrorSnackBar('Не удалось обновить количество');
  }

  void _resetQuantityUpdateState() {
    if (mounted) {
      setState(() {
        _isUpdatingQuantity = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.white,
        content: Text(
          message,
          style: AppText.medium_14.copyWith(color: AppColors.error),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCard) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24, left: 24, top: 16),
      child: GestureDetector(
        onTap: () => _openDetails(context),
        child: Row(
          children: [
            _buildPlantImage(),
            const SizedBox(width: 20),
            _buildItemInfo(),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    context.pushNamed(
      'plantDetails',
      pathParameters: {'plantId': '${widget.item.plant.id}'},
      extra: PlantDetailsRouteArgs(
        plantId: widget.item.plant.id,
        initialPotSize: widget.item.potSize,
        initialPotMaterial: widget.item.potMaterial,
        initialPotColor: widget.item.potColor,
        initialQuantity: widget.item.quantity,
      ),
    );
  }

  Widget _buildPlantImage() {
    return SizedBox(
      width: 113,
      height: 88,
      child: Stack(
        children: [
          _hasImageError ? _buildErrorPlaceholder() : _buildCachedImage(),
          Positioned(
            bottom: 4,
            right: 4,
            child: FavoriteButton(
              plant: widget.item.plant,
              size: 24,
              showSnackbar: true,
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: _buildCheckboxOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxOverlay() {
    return GestureDetector(
      onTap: _toggleSelection,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isSelected ? AppColors.brown : AppColors.grey_light,
            width: 2,
          ),
        ),
        child: _isSelected
            ? Center(
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: AppColors.brown,
                ),
              )
            : const SizedBox.expand(),
      ),
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
    final imageUrl = widget.item.plant.fullImageUrl.trim();
    if (imageUrl.isEmpty) {
      return _buildEmptyPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
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
        cacheKey: imageUrl,
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
      child: const LoadingWidget(size: 20, strokeWidth: 2),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
    );
  }

  Widget _buildItemInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemHeader(),
          _buildHeightInfo(),
          const SizedBox(height: 8),
          _buildPriceAndQuantity(),
        ],
      ),
    );
  }

  Widget _buildItemHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.plant.name,
                style: AppText.bold_18.copyWith(color: AppColors.black),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (widget.item.potDescription.isNotEmpty)
                Text(
                  widget.item.potDescription,
                  style: AppText.medium_14.copyWith(
                    color: AppColors.black_transparent,
                  ),
                ),
            ],
          ),
        ),
        _buildRemoveButton(),
      ],
    );
  }

  Widget _buildHeightInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Высота до ${widget.item.plant.heightCm} см',
        style: AppText.medium_14.copyWith(
          color: AppColors.black_transparent,
        ),
      ),
    );
  }

  Widget _buildPriceAndQuantity() {
    return Row(
      children: [
        _buildPriceInfo(),
        const Spacer(),
        if (_isSelected) _buildQuantitySelector(),
      ],
    );
  }

  Widget _buildPriceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.item.totalPrice} ₽',
          style: AppText.medium_16.copyWith(color: AppColors.black),
        ),
        if (widget.item.quantity > 1)
          Text(
            '${widget.item.itemTotal} ₽ × ${widget.item.quantity}',
            style: AppText.medium_12.copyWith(color: AppColors.grey),
          ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return GestureDetector(
      onTap: _removeFromCart,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.white_dark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _isRemoving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brown,
                  ),
                )
              : Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.brown,
                ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey_light),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildDecrementButton(),
          _buildQuantityDisplay(),
          _buildIncrementButton(),
        ],
      ),
    );
  }

  Widget _buildDecrementButton() {
    return IconButton(
      onPressed: () => _updateQuantity(widget.item.quantity - 1),
      icon: Icon(
        Icons.remove,
        size: 18,
        color: AppColors.brown,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildQuantityDisplay() {
    return _isUpdatingQuantity
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            '${widget.item.quantity}',
            style: AppText.medium_16.copyWith(color: AppColors.black),
          );
  }

  Widget _buildIncrementButton() {
    return IconButton(
      onPressed: () => _updateQuantity(widget.item.quantity + 1),
      icon: Icon(
        Icons.add,
        size: 18,
        color: AppColors.brown,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
