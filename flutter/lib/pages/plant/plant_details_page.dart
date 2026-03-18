import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/backend/services/wishlist.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PlantDetailsRouteArgs {
  final int plantId;
  final String? initialPotSize;
  final String? initialPotMaterial;
  final String? initialPotColor;
  final int initialQuantity;

  const PlantDetailsRouteArgs({
    required this.plantId,
    this.initialPotSize,
    this.initialPotMaterial,
    this.initialPotColor,
    this.initialQuantity = 1,
  });
}

class PlantDetailsPage extends StatefulWidget {
  final PlantDetailsRouteArgs args;

  const PlantDetailsPage({super.key, required this.args});

  @override
  State<PlantDetailsPage> createState() => _PlantDetailsPageState();
}

class _PlantDetailsPageState extends State<PlantDetailsPage> {
  Plant? _plant;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;

  List<PotSize> _sizes = const [];
  List<PotMaterial> _materials = const [];
  List<PotColor> _colors = const [];
  Set<int> _availableSizeIds = const {};
  Set<int> _availableMaterialIds = const {};
  Set<int> _availableColorIds = const {};

  String? _selectedSize;
  String? _selectedMaterial;
  String? _selectedColor;
  int _quantity = 1;
  double _potPrice = 0;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.args.initialQuantity < 1 ? 1 : widget.args.initialQuantity;
    _selectedSize = widget.args.initialPotSize;
    _selectedMaterial = widget.args.initialPotMaterial;
    _selectedColor = widget.args.initialPotColor;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait<dynamic>([
        PlantService.getPlantById(widget.args.plantId),
        PotService.getSizes(),
        PotService.getMaterials(),
        PotService.getColors(),
      ]);

      final plant = futures[0] as Plant;
      final sizes = futures[1] as List<PotSize>;
      final materials = futures[2] as List<PotMaterial>;
      final colors = futures[3] as List<PotColor>;

      if (!mounted) return;
      setState(() {
        _plant = plant;
        _sizes = sizes;
        _materials = materials;
        _colors = colors;
        if (_selectedSize != null &&
            !_sizes.any((e) => e.name.toLowerCase() == _selectedSize!.toLowerCase())) {
          _selectedSize = null;
        }
        if (_selectedMaterial != null &&
            !_materials.any((e) => e.name.toLowerCase() == _selectedMaterial!.toLowerCase())) {
          _selectedMaterial = null;
        }
        if (_selectedColor != null &&
            !_colors.any((e) => e.name.toLowerCase() == _selectedColor!.toLowerCase())) {
          _selectedColor = null;
        }
      });
      await _reloadOptionsAvailability();
      await _recalculatePotPrice();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить товар: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recalculatePotPrice() async {
    if (_selectedMaterial == null || _selectedSize == null) {
      setState(() {
        _potPrice = 0;
      });
      return;
    }
    final price = await PotService.getPotPrice(
      _selectedMaterial!,
      _selectedSize!,
      color: _selectedColor,
    );
    if (!mounted) return;
    setState(() {
      _potPrice = price;
    });
  }

  int? _sizeIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    for (final size in _sizes) {
      if (size.name.toLowerCase() == name.toLowerCase()) return size.id;
    }
    return null;
  }

  int? _materialIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    for (final material in _materials) {
      if (material.name.toLowerCase() == name.toLowerCase()) return material.id;
    }
    return null;
  }

  int? _colorIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    for (final color in _colors) {
      if (color.name.toLowerCase() == name.toLowerCase()) return color.id;
    }
    return null;
  }

  Future<void> _reloadOptionsAvailability() async {
    try {
      final data = await PotService.getOptions(
        material: _selectedMaterial,
        size: _selectedSize,
        color: _selectedColor,
      );
      final sizes = (data['sizes'] as List? ?? const []);
      final materials = (data['materials'] as List? ?? const []);
      final colors = (data['colors'] as List? ?? const []);

      Set<int> availableSizeIds = sizes
          .whereType<Map<String, dynamic>>()
          .where((e) => e['is_available'] == true)
          .map((e) => (e['id'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      Set<int> availableMaterialIds = materials
          .whereType<Map<String, dynamic>>()
          .where((e) => e['is_available'] == true)
          .map((e) => (e['id'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      Set<int> availableColorIds = colors
          .whereType<Map<String, dynamic>>()
          .where((e) => e['is_available'] == true)
          .map((e) => (e['id'] as num?)?.toInt())
          .whereType<int>()
          .toSet();

      if (!mounted) return;
      setState(() {
        _availableSizeIds = availableSizeIds;
        _availableMaterialIds = availableMaterialIds;
        _availableColorIds = availableColorIds;

        if (_selectedSize != null) {
          final id = _sizeIdByName(_selectedSize);
          if (id != null && !_availableSizeIds.contains(id)) {
            _selectedSize = null;
          }
        }
        if (_selectedMaterial != null) {
          final id = _materialIdByName(_selectedMaterial);
          if (id != null && !_availableMaterialIds.contains(id)) {
            _selectedMaterial = null;
          }
        }
        if (_selectedColor != null) {
          final id = _colorIdByName(_selectedColor);
          if (id != null && !_availableColorIds.contains(id)) {
            _selectedColor = null;
          }
        }
      });
    } catch (_) {
      // Keep previous state if options endpoint is temporarily unavailable.
    }
  }

  List<String> _galleryUrls() {
    final plant = _plant;
    if (plant == null) return const [];
    return plant.productImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _price(double value) {
    return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ₽';
  }

  Future<void> _addToCart() async {
    final plant = _plant;
    if (plant == null || _isActionLoading) return;
    setState(() {
      _isActionLoading = true;
    });
    try {
      await CartService.addToCart(
        AddToCartRequest(
          plantId: plant.id,
          quantity: _quantity,
          potSize: _selectedSize,
          potMaterial: _selectedMaterial,
          potColor: _selectedColor,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Добавлено в корзину',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось добавить в корзину: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _addToWishlist() async {
    final plant = _plant;
    if (plant == null || _isActionLoading) return;
    setState(() {
      _isActionLoading = true;
    });
    try {
      await WishlistService.addToWishlist(
        plant.id,
        potSize: _selectedSize,
        potMaterial: _selectedMaterial,
        potColor: _selectedColor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Сохранено в избранном',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Не удалось добавить в избранное: $e',
            style: AppText.medium_14.copyWith(color: AppColors.error),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Widget _selector({
    required String title,
    required List<String> items,
    required String? selected,
    required bool Function(String item) isEnabled,
    required ValueChanged<String?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.medium_14.copyWith(color: AppColors.black)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Не выбрано'),
              selected: selected == null || selected.isEmpty,
              onSelected: (_) => onSelected(null),
            ),
            ...items.map(
              (item) {
                final enabled = isEnabled(item);
                return ChoiceChip(
                  label: Text(item),
                  selected: (selected ?? '') == item,
                  onSelected: enabled ? (_) => onSelected(item) : null,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _galleryUrls();
    final plant = _plant;
    final totalPerItem = (plant?.basePrice ?? 0) + _potPrice;
    final total = totalPerItem * _quantity;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text('Товар', style: AppText.bold_18.copyWith(color: AppColors.black)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: AppText.medium_14.copyWith(color: AppColors.error)),
                  ),
                )
              : plant == null
                  ? Center(child: Text('Товар не найден', style: AppText.medium_14))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (gallery.isEmpty)
                          Container(height: 240, color: AppColors.grey_light)
                        else ...[
                          SizedBox(
                            height: 260,
                            child: PageView.builder(
                              itemCount: gallery.length,
                              onPageChanged: (i) {
                                setState(() {
                                  _currentImageIndex = i;
                                });
                              },
                              itemBuilder: (context, i) {
                                final url = gallery[i];
                                final resolved = ApiConfig.imageUrl(url).trim();
                                if (resolved.isEmpty) {
                                  return Container(color: AppColors.grey_light);
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: resolved,
                                    fit: BoxFit.contain,
                                    placeholder: (context, imageUrl) =>
                                        Container(color: AppColors.grey_light),
                                    errorWidget: (context, imageUrl, error) =>
                                        Container(color: AppColors.grey_light),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              gallery.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _currentImageIndex ? AppColors.brown : AppColors.grey_light,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(plant.name, style: AppText.bold_20.copyWith(color: AppColors.black)),
                        if (plant.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            plant.description,
                            style: AppText.medium_14.copyWith(color: AppColors.black_transparent),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text('Цена растения: ${_price(plant.basePrice)}', style: AppText.medium_14.copyWith(color: AppColors.black)),
                        const SizedBox(height: 6),
                        Text(
                          'Текущий выбор: ${_selectedMaterial ?? ''}, ${_selectedSize ?? ''}, ${_selectedColor ?? ''}',
                          style: AppText.medium_12.copyWith(color: AppColors.grey),
                        ),
                        const SizedBox(height: 12),
                        _selector(
                          title: 'Размер горшка',
                          items: _sizes.map((e) => e.name).toList(),
                          selected: _selectedSize,
                          isEnabled: (item) {
                            final id = _sizeIdByName(item);
                            return id == null || _availableSizeIds.contains(id);
                          },
                          onSelected: (value) async {
                            setState(() {
                              _selectedSize = value;
                            });
                            await _reloadOptionsAvailability();
                            await _recalculatePotPrice();
                          },
                        ),
                        const SizedBox(height: 12),
                        _selector(
                          title: 'Материал горшка',
                          items: _materials.map((e) => e.name).toList(),
                          selected: _selectedMaterial,
                          isEnabled: (item) {
                            final id = _materialIdByName(item);
                            return id == null || _availableMaterialIds.contains(id);
                          },
                          onSelected: (value) async {
                            setState(() {
                              _selectedMaterial = value;
                            });
                            await _reloadOptionsAvailability();
                            await _recalculatePotPrice();
                          },
                        ),
                        const SizedBox(height: 12),
                        _selector(
                          title: 'Цвет горшка',
                          items: _colors.map((e) => e.name).toList(),
                          selected: _selectedColor,
                          isEnabled: (item) {
                            final id = _colorIdByName(item);
                            return id == null || _availableColorIds.contains(id);
                          },
                          onSelected: (value) async {
                            setState(() {
                              _selectedColor = value;
                            });
                            await _reloadOptionsAvailability();
                            await _recalculatePotPrice();
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Количество', style: AppText.medium_14.copyWith(color: AppColors.black)),
                            const Spacer(),
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () {
                                      setState(() {
                                        _quantity -= 1;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$_quantity', style: AppText.medium_16.copyWith(color: AppColors.black)),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _quantity += 1;
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Цена горшка: ${_price(_potPrice)}', style: AppText.medium_14.copyWith(color: AppColors.grey)),
                        const SizedBox(height: 6),
                        Text('Итого: ${_price(total)}', style: AppText.bold_18.copyWith(color: AppColors.brown)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isActionLoading ? null : _addToWishlist,
                                child: Text('В избранное', style: AppText.medium_14.copyWith(color: AppColors.brown)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brown),
                                onPressed: _isActionLoading ? null : _addToCart,
                                child: Text('В корзину', style: AppText.medium_14.copyWith(color: AppColors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }
}
