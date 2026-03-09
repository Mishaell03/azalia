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

class AdminProductsCartWarehouse extends StatelessWidget {
  const AdminProductsCartWarehouse({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: FutureBuilder<PlantResponse>(
        future: PlantService.getPlants(),
        builder: (context, snapshot) {
          // загрузка
          if (snapshot.connectionState == ConnectionState.waiting) {
            // добавить UI
            return const Center(child: Text("Подождите!!"));
          }
          // Error
          if (snapshot.hasError) {
            // добавить UI
            return const Center(child: Text("Error"));
          }
          // Success
          final PlantResponse response = snapshot.data!;
          final List<Plant> plants = response.data;
          if (plants.isEmpty) {
            // добавить UI
            return const Center(child: Text("Список товаров пуст :("));
          }
          // UI
          return ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              final plant = plants[index];
              return _Crad(plant: plant);
            },
          );
        },
      ),
    );
  }
}

// сама карточка
class _Crad extends StatelessWidget {
  final Plant plant;

  const _Crad({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.network(plant.fullImageUrl, width: 113, height: 88),
          SizedBox(width: 10),
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
                SizedBox(height: 5),
                Text(
                  '${plant.basePrice} ₽',
                  style: AppText.medium_16.copyWith(color: AppColors.black),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plant.inStock ? 'В наличии' : 'Нет на складе',
                      style: AppText.medium_18.copyWith(
                        color: plant.inStock
                            ? AppColors.brown
                            : AppColors.error,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => OpenDialog(plant: plant),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.brown, width: 1),
                      ),
                      icon: const Icon(Icons.edit),
                      color: AppColors.brown,
                      iconSize: 18,
                      padding: EdgeInsets.all(7),
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// окно редактирования
class OpenDialog extends StatefulWidget {
  final Plant plant;

  const OpenDialog({super.key, required this.plant});

  @override
  State<OpenDialog> createState() => _OpenDialog();
}

class _OpenDialog extends State<OpenDialog> {
  int? selectedCategoryId;
  late String selectedPotSize;
  late Future<List<Category>> categoriesFuture;
  late String lightValue;
  late TextEditingController nameController,
      priceController,
      descriptionController,
      careInstructionsController,
      lightRequirementsController,
      wateringFrequencyController,
      heightCmController,
      plantTypeController,
      recommendedPotSizeController,
      ratingController;

  @override
  void initState() {
    super.initState();
    // все поля цветов
    priceController = TextEditingController(
      text: widget.plant.basePrice.toString(),
    );
    descriptionController = TextEditingController(
      text: widget.plant.description,
    );
    careInstructionsController = TextEditingController(
      text: widget.plant.careInstructions,
    );
    lightRequirementsController = TextEditingController(
      text: widget.plant.lightRequirements,
    );
    wateringFrequencyController = TextEditingController(
      text: widget.plant.wateringFrequency,
    );
    heightCmController = TextEditingController(
      text: widget.plant.heightCm.toString(),
    );
    plantTypeController = TextEditingController(text: widget.plant.plantType);
    recommendedPotSizeController = TextEditingController(
      text: widget.plant.recommendedPotSize,
    );
    ratingController = TextEditingController(
      text: widget.plant.rating.toString(),
    );
    // освещение для цветов
    lightValue = widget.plant.lightRequirements.isNotEmpty
        ? widget.plant.lightRequirements
        : lightItems.first.value;
    lightRequirementsController.text = lightValue;
    // категории цветов
    categoriesFuture = PlantService.getCategories();
    selectedCategoryId = widget.plant.categoryId;
    nameController = TextEditingController(text: widget.plant.name);

    selectedPotSize = widget.plant.recommendedPotSize ?? 'M';
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    careInstructionsController.dispose();
    lightRequirementsController.dispose();
    wateringFrequencyController.dispose();
    heightCmController.dispose();
    plantTypeController.dispose();
    recommendedPotSizeController.dispose();
    ratingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Редактирование товара'),
              SizedBox(height: 20),
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          ImageEdit(fullImageUrl: widget.plant.fullImageUrl),
                          SizedBox(height: 3),
                          Text(
                            'id: ${widget.plant.id}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ],
                      ),
                      SizedBox(width: 10),
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
                  Text(
                    widget.plant.inStock
                        ? 'В наличии ${widget.plant.stockQuantity} шт.'
                        : 'Нет на складе',
                    style: AppText.medium_16.copyWith(
                      color: widget.plant.inStock
                          ? AppColors.black_transparent
                          : AppColors.error,
                    ),
                  ),
                  SizedBox(height: 20),
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
                      // Загрузка
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // Ошибка
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Ошибка получения категорий: ${snapshot.error}',
                          ),
                        );
                      }
                      // Данные получены
                      if (!snapshot.hasData) {
                        return const Center(child: Text('Нет данных'));
                      }
                      final List<Category> categories = snapshot.data!;
                      // Проверка на пустой список
                      if (categories.isEmpty) {
                        return const Center(
                          child: Text('Список категорий пуст'),
                        );
                      }
                      // Отображение списка категорий
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
                  SizedBox(height: 15),
                  Text(
                    'Требуемое освещение:',
                    style: AppText.medium_12.copyWith(
                      color: AppColors.black_transparent,
                    ),
                  ),
                  SizedBox(height: 10),
                  IconValueSelector(
                    items: lightItems,
                    selectedValue: lightValue,
                    onSelected: (value) {
                      setState(() {
                        lightValue = value;
                        lightRequirementsController.text = value;
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Рекомендуемый размер горшка:',
                    style: AppText.medium_12.copyWith(
                      color: AppColors.black_transparent,
                    ),
                  ),
                  SizedBox(height: 10),
                  IconValueSelector(
                    items: potSizeItems,
                    selectedValue: selectedPotSize,
                    onSelected: (String value) {
                      setState(() {
                        selectedPotSize = value;
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  AppTextField(
                    controller: wateringFrequencyController,
                    labelText: 'Требованию к поливу',
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
