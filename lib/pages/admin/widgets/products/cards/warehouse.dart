import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
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
                SizedBox(height: 5,),
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
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.brown, width: 1)
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
