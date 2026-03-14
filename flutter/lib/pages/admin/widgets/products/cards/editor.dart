import 'dart:io';

import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/pages/admin/widgets/products/cards/widget/category.dart';
import 'package:azalia/pages/admin/widgets/products/cards/widget/icon.dart';
import 'package:azalia/pages/admin/widgets/products/cards/widget/imageEdit.dart';
import 'package:azalia/pages/admin/widgets/products/cards/widget/textField.dart';
import 'package:flutter/material.dart';

class AdminProductsCartEditor extends StatefulWidget {
  const AdminProductsCartEditor({super.key});

  @override
  State<AdminProductsCartEditor> createState() =>
      _AdminProductsCartEditorState();
}

class _AdminProductsCartEditorState extends State<AdminProductsCartEditor> {
  bool _isLoading = true;
  String? _error;
  List<Plant> _plants = <Plant>[];

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await PlantService.getPlants(
        perPage: 100,
        includeInactive: true,
        sortBy: 'name',
      );
      if (!mounted) return;
      setState(() {
        _plants = response.data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки товаров: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyUpdatedPlant(Plant updatedPlant) {
    final index = _plants.indexWhere((p) => p.id == updatedPlant.id);
    if (index < 0) return;

    setState(() {
      _plants[index] = updatedPlant;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: Builder(
        builder: (_) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(child: Text(_error!));
          }
          if (_plants.isEmpty) {
            return const Center(child: Text('Список товаров пуст'));
          }

          return RefreshIndicator(
            onRefresh: _loadPlants,
            child: ListView.builder(
              itemCount: _plants.length,
              itemBuilder: (context, index) {
                final plant = _plants[index];
                return _PlantCard(plant: plant, onSaved: _applyUpdatedPlant);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final Plant plant;
  final ValueChanged<Plant> onSaved;

  const _PlantCard({required this.plant, required this.onSaved});

  bool get _isRemovedFromSale => !plant.isActive || plant.deletedAt != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.network(
            plant.fullImageUrl,
            width: 113,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              width: 113,
              height: 88,
              color: AppColors.grey_light,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bold_18.copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 5),
                Text(
                  '${plant.basePrice.toStringAsFixed(plant.basePrice % 1 == 0 ? 0 : 2)} ₽',
                  style: AppText.medium_16.copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRemovedFromSale ? 'Снят с продажи' : 'В продаже',
                  style: AppText.medium_16.copyWith(
                    color: _isRemovedFromSale
                        ? AppColors.error
                        : AppColors.brown,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.outlined(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) =>
                            _EditPlantDialog(plant: plant, onSaved: onSaved),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.brown, width: 1),
                    ),
                    icon: const Icon(Icons.edit),
                    color: AppColors.brown,
                    iconSize: 18,
                    padding: const EdgeInsets.all(7),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPlantDialog extends StatefulWidget {
  final Plant plant;
  final ValueChanged<Plant> onSaved;

  const _EditPlantDialog({required this.plant, required this.onSaved});

  @override
  State<_EditPlantDialog> createState() => _EditPlantDialogState();
}

class _EditPlantDialogState extends State<_EditPlantDialog> {
  static const Map<String, int> _potSizeToId = {
    'S': 1,
    'M': 2,
    'L': 3,
    'XL': 4,
  };

  int? selectedCategoryId;
  late String selectedPotSize;
  late Future<List<Category>> categoriesFuture;
  late String lightValue;
  late bool isActive;
  bool _isSaving = false;
  File? _selectedImageFile;

  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late TextEditingController careInstructionsController;
  late TextEditingController wateringFrequencyController;
  late TextEditingController heightCmController;
  late TextEditingController ratingController;

  @override
  void initState() {
    super.initState();
    final plant = widget.plant;

    nameController = TextEditingController(text: plant.name);
    priceController = TextEditingController(text: plant.basePrice.toString());
    descriptionController = TextEditingController(text: plant.description);
    careInstructionsController = TextEditingController(
      text: plant.careInstructions,
    );
    wateringFrequencyController = TextEditingController(
      text: plant.wateringFrequency,
    );
    heightCmController = TextEditingController(text: plant.heightCm.toString());
    ratingController = TextEditingController(
      text: (plant.rating ?? 0).toString(),
    );

    lightValue = plant.lightRequirements.isNotEmpty
        ? plant.lightRequirements
        : lightItems.first.value;

    categoriesFuture = PlantService.getCategories();
    selectedCategoryId = plant.categoryId;
    selectedPotSize = plant.recommendedPotSize ?? 'M';
    isActive = plant.isActive && plant.deletedAt == null;
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    careInstructionsController.dispose();
    wateringFrequencyController.dispose();
    heightCmController.dispose();
    ratingController.dispose();
    super.dispose();
  }

  String _norm(String value) => value.trim();

  String _short(String value) {
    final text = _norm(value);
    if (text.length <= 60) return text;
    return '${text.substring(0, 57)}...';
  }

  double _parseDouble(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ??
        fallback;
  }

  int _parseInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  List<String> _buildChanges({
    required String newName,
    required double newPrice,
    required String newDescription,
    required String newCareInstructions,
    required String newWatering,
    required int newHeight,
    required double newRating,
    required int? newCategoryId,
    required String newLight,
    required bool newIsActive,
    required bool imageChanged,
  }) {
    final old = widget.plant;
    final changes = <String>[];

    if (_norm(old.name) != _norm(newName)) {
      changes.add('Название: "${old.name}" -> "$newName"');
    }
    if ((old.basePrice - newPrice).abs() > 0.0001) {
      changes.add('Цена: ${old.basePrice} -> $newPrice');
    }
    if (_norm(old.description) != _norm(newDescription)) {
      changes.add(
        'Описание: "${_short(old.description)}" -> "${_short(newDescription)}"',
      );
    }
    if (_norm(old.careInstructions) != _norm(newCareInstructions)) {
      changes.add(
        'Инструкция: "${_short(old.careInstructions)}" -> "${_short(newCareInstructions)}"',
      );
    }
    if (_norm(old.wateringFrequency) != _norm(newWatering)) {
      changes.add('Полив: "${old.wateringFrequency}" -> "$newWatering"');
    }
    if (old.heightCm != newHeight) {
      changes.add('Высота: ${old.heightCm} -> $newHeight');
    }
    if (((old.rating ?? 0) - newRating).abs() > 0.0001) {
      changes.add('Рейтинг: ${old.rating ?? 0} -> $newRating');
    }
    if (old.categoryId != newCategoryId) {
      changes.add(
        'Категория: ${old.categoryId ?? '-'} -> ${newCategoryId ?? '-'}',
      );
    }
    if (_norm(old.lightRequirements) != _norm(newLight)) {
      changes.add('Освещение: "${old.lightRequirements}" -> "$newLight"');
    }
    if ((old.recommendedPotSize ?? '').trim() != selectedPotSize.trim()) {
      changes.add(
        'Размер горшка: "${old.recommendedPotSize ?? '-'}" -> "$selectedPotSize"',
      );
    }

    final oldStatus = (old.isActive && old.deletedAt == null)
        ? 'В продаже'
        : 'Снят с продажи';
    final newStatus = newIsActive ? 'В продаже' : 'Снят с продажи';
    if (oldStatus != newStatus) {
      changes.add('Статус: $oldStatus -> $newStatus');
    }

    if (imageChanged) {
      changes.add('Изображение: текущее -> новое');
    }

    return changes;
  }

  List<String> _getCurrentChanges() {
    final newName = _norm(nameController.text);
    final newPrice = _parseDouble(priceController, widget.plant.basePrice);
    final newDescription = _norm(descriptionController.text);
    final newCareInstructions = _norm(careInstructionsController.text);
    final newWatering = _norm(wateringFrequencyController.text);
    final newHeight = _parseInt(heightCmController, widget.plant.heightCm);
    final newRating = _parseDouble(ratingController, widget.plant.rating ?? 0);
    final newCategoryId = selectedCategoryId;
    final newLight = lightValue;
    final imageChanged = _selectedImageFile != null;

    return _buildChanges(
      newName: newName,
      newPrice: newPrice,
      newDescription: newDescription,
      newCareInstructions: newCareInstructions,
      newWatering: newWatering,
      newHeight: newHeight,
      newRating: newRating,
      newCategoryId: newCategoryId,
      newLight: newLight,
      newIsActive: isActive,
      imageChanged: imageChanged,
    );
  }

  Future<bool> _confirmSave(List<String> changes) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите изменения'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Будут применены изменения:'),
                const SizedBox(height: 10),
                ...changes.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $line'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              side: BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Отмена',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brown,
              side: BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Сохранить',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final newName = _norm(nameController.text);
    final newPrice = _parseDouble(priceController, widget.plant.basePrice);
    final newDescription = _norm(descriptionController.text);
    final newCareInstructions = _norm(careInstructionsController.text);
    final newWatering = _norm(wateringFrequencyController.text);
    final newHeight = _parseInt(heightCmController, widget.plant.heightCm);
    final newRating = _parseDouble(ratingController, widget.plant.rating ?? 0);
    final newCategoryId = selectedCategoryId;
    final newLight = lightValue;
    final changes = _getCurrentChanges();

    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await _confirmSave(changes);
    if (!confirmed || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = <String, dynamic>{};
      final old = widget.plant;

      if (_norm(old.name) != newName) {
        payload['name'] = newName;
      }
      if ((old.basePrice - newPrice).abs() > 0.0001) {
        payload['base_price'] = newPrice;
      }
      if (_norm(old.description) != newDescription) {
        payload['description'] = newDescription;
      }
      if (_norm(old.careInstructions) != newCareInstructions) {
        payload['care_instructions'] = newCareInstructions;
      }
      if (_norm(old.lightRequirements) != newLight) {
        payload['light_requirements'] = newLight;
      }
      final selectedPotSizeId = _potSizeToId[selectedPotSize];
      if (old.recommendedPotSizeId != selectedPotSizeId &&
          selectedPotSizeId != null) {
        payload['recommended_pot_size_id'] = selectedPotSizeId;
      }
      if (_norm(old.wateringFrequency) != newWatering) {
        payload['watering_notes'] = newWatering;
      }
      if (old.heightCm != newHeight) {
        payload['height_cm'] = newHeight;
      }
      if (((old.rating ?? 0) - newRating).abs() > 0.0001) {
        payload['rating'] = newRating;
      }
      if (old.categoryId != newCategoryId) {
        payload['category_id'] = newCategoryId;
      }

      final oldIsActive = old.isActive && old.deletedAt == null;
      if (oldIsActive != isActive) {
        payload['is_active'] = isActive;
      }

      if (payload.isNotEmpty) {
        await PlantService.updatePlant(widget.plant.id, payload: payload);
      }

      String? uploadedImagePath;
      if (_selectedImageFile != null) {
        uploadedImagePath = await PlantService.uploadPlantImage(
          widget.plant.id,
          _selectedImageFile!,
        );
      }

      if (!mounted) return;

      final updatedPlant = widget.plant.copyWith(
        name: newName,
        basePrice: newPrice,
        description: newDescription,
        careInstructions: newCareInstructions,
        lightRequirements: newLight,
        recommendedPotSize: selectedPotSize,
        recommendedPotSizeId: _potSizeToId[selectedPotSize],
        wateringFrequency: newWatering,
        heightCm: newHeight,
        rating: newRating,
        categoryId: newCategoryId,
        isActive: isActive,
        deletedAt: isActive
            ? null
            : (widget.plant.deletedAt ?? DateTime.now().toIso8601String()),
        imageUrl: uploadedImagePath ?? widget.plant.imageUrl,
      );

      widget.onSaved(updatedPlant);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: Text(
            'Изменения сохранены',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: Text(
            'Не удалось сохранить: $e',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleCancel() async {
    if (_isSaving) return;

    final changes = _getCurrentChanges();
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить все изменения?'),
        content: const Text('Все несохраненные изменения будут потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Продолжить',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              side: BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Сбросить',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text('Редактирование товара'),
              const SizedBox(height: 20),
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          ImageEdit(
                            fullImageUrl: widget.plant.fullImageUrl,
                            imageFile: _selectedImageFile,
                            onImageSelected: (file) {
                              setState(() {
                                _selectedImageFile = file;
                              });
                            },
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'id: ${widget.plant.id}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            AppTextField(
                              controller: nameController,
                              labelText: 'Название товара',
                            ),
                            AppTextField(
                              controller: priceController,
                              labelText: 'Цена рубли',
                              isDouble: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'Товар в продаже',
                      style: AppText.medium_14.copyWith(color: AppColors.black),
                    ),
                    subtitle: Text(
                      isActive ? 'В продаже' : 'Снят с продажи',
                      style: AppText.medium_12.copyWith(
                        color: isActive ? AppColors.brown : AppColors.error,
                      ),
                    ),
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: descriptionController,
                    labelText: 'Описание товара',
                    necessarily: false,
                  ),
                  AppTextField(
                    controller: careInstructionsController,
                    labelText: 'Инструкция использования',
                    necessarily: false,
                  ),
                  FutureBuilder<List<Category>>(
                    future: categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Ошибка получения категорий: ${snapshot.error}',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: Text('Нет данных'));
                      }

                      final categories = snapshot.data!;
                      if (categories.isEmpty) {
                        return const Center(
                          child: Text('Список категорий пуст'),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((category) {
                          return AdminCategory(
                            name: category.name,
                            isActive: selectedCategoryId == category.id,
                            onTap: () {
                              setState(() {
                                selectedCategoryId = category.id;
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Требуемое освещение:',
                    style: AppText.medium_12.copyWith(
                      color: AppColors.black_transparent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IconValueSelector(
                    items: lightItems,
                    selectedValue: lightValue,
                    onSelected: (value) {
                      setState(() {
                        lightValue = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Рекомендуемый размер горшка:',
                    style: AppText.medium_12.copyWith(
                      color: AppColors.black_transparent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IconValueSelector(
                    items: potSizeItems,
                    selectedValue: selectedPotSize,
                    onSelected: (value) {
                      setState(() {
                        selectedPotSize = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  AppTextField(
                    controller: wateringFrequencyController,
                    labelText: 'Требования к поливу',
                    necessarily: false,
                  ),
                  AppTextField(
                    controller: heightCmController,
                    labelText: 'Высота см',
                    necessarily: false,
                    isDouble: true,
                  ),
                  AppTextField(
                    controller: ratingController,
                    labelText: 'Рейтинг',
                    isDouble: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _handleCancel,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.brown),
                          ),
                          child: Text(
                            'Отмена',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.brown,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _save,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.brown,
                            side: BorderSide(color: AppColors.white),
                          ),
                          child: Text(
                            _isSaving ? 'Сохранение...' : 'Сохранить',
                            style: AppText.medium_14.copyWith(
                              color: AppColors.white_transparent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
