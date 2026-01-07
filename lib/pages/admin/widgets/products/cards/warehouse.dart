import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/pages/admin/widgets/products/cards/widget/textField.dart';
import 'package:flutter/material.dart';

class AdminProductsCartWarehouse extends StatelessWidget {
  const AdminProductsCartWarehouse({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: FutureBuilder<PlantResponse>(
        future: PlantService().getPlants(),
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
          // UI`
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

  const _Crad({super.key, required this.plant});

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
    nameController = TextEditingController(text: widget.plant.name);
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
                  Image.network(widget.plant.fullImageUrl),
                  Text('id: ${widget.plant.id}'),
                  AppTextField(
                    controller: nameController,
                    labelText: 'Название товара',
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: priceController,
                    labelText: 'Ценв рубли',
                    isDouble: true,
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: descriptionController,
                    labelText: 'Описание товара',
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: careInstructionsController,
                    labelText: 'Инструкция использования',
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: lightRequirementsController,
                    labelText: 'Требованию к освещению',//отдельная кнопка
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: wateringFrequencyController,
                    labelText: 'Требованию к поливу',//отдельная кнопка
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: heightCmController,
                    labelText: 'Высота',
                    isDouble: true,
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: plantTypeController,
                    labelText: 'Тип растения',//отдельная кнопка
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: recommendedPotSizeController,
                    labelText: 'Рекомендуемый размер горшка',
                  ),
                  SizedBox(height: 20),
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
