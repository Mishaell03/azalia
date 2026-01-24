import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/employeesAdmin.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/employeesAdmin.dart';
import 'package:azalia/pages/profile/widgets/image.dart';

class UserCardData {
  final int id;
  final int telegramId;
  final String name;
  final bool isEmployee;
  final bool isActive;
  final String? avatarBase64;

  const UserCardData({
    required this.id,
    required this.telegramId,
    required this.name,
    required this.isEmployee,
    required this.isActive,
    this.avatarBase64,
  });
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  State<AdminUsersPage> createState() => _AdminSettingsPage();
}

enum _UserTab { user, employees }

class _AdminSettingsPage extends State<AdminUsersPage> {
  _UserTab _currentTab = _UserTab.user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [
            _currentTab == _UserTab.user,
            _currentTab == _UserTab.employees,
          ],
          onPressed: (index) {
            setState(() {
              _currentTab = index == 0 ? _UserTab.user : _UserTab.employees;
            });
          },
          borderRadius: BorderRadius.circular(20),
          children: const [
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
              child: Text('Пользователи'),
            ),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
              child: Text('Сотрудники'),
            ),
          ],
        ),
        SizedBox(height: 20),
        Expanded(
          child: _currentTab == _UserTab.user ? _UsersList() : _EmployeesList(),
        ),
      ],
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: EmployeesService(ApiClient()).getUsers(),
      builder: (context, snapshot) {
        // Загрузка
        if (snapshot.connectionState == ConnectionState.waiting) {
          // добавить UI
          return const Center(child: Text("Подождите!!"));
        }
        // ERROR
        if (snapshot.hasError) {
          // добавить UI
          return const Center(child: Text("Error"));
        }
        // SUCCESS
        final users = snapshot.data!;
        if (users.isEmpty) {
          // добавить UI
          return const Center(child: Text("Список товаров пуст :("));
        }
        // UI
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _UserCard(
              data: UserCardData(
                id: user.id,
                telegramId: user.telegramId,
                name: user.name,
                isEmployee: false,
                isActive: false,
                avatarBase64: user.avatar,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmployeesList extends StatelessWidget {
  const _EmployeesList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Employee>>(
      future: EmployeesService(ApiClient()).getEmployees(),
      builder: (context, snapshot) {
        // Загрузка
        if (snapshot.connectionState == ConnectionState.waiting) {
          // добавить UI
          return const Center(child: Text("Подождите!!"));
        }
        // ERROR
        if (snapshot.hasError) {
          // добавить UI
          return const Center(child: Text("Error"));
        }
        // SUCCESS
        final employees = snapshot.data!;
        if (employees.isEmpty) {
          // добавить UI
          return const Center(child: Text("Список товаров пуст :("));
        }
        // UI
        return ListView.builder(
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employ = employees[index];
            return _UserCard(
              data: UserCardData(
                id: employ.id,
                telegramId: employ.telegramId,
                name: employ.userInfo.name,
                isEmployee: true,
                isActive: employ.isActive,
                avatarBase64: employ.userInfo.avatar,
              ),
            );
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserCardData data;

  const _UserCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          AppProfileImage(
            avatarBase64: data.avatarBase64,
            onTap: () {},
            size: 48,
            showCameraIcon: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bold_18.copyWith(color: AppColors.black),
                ),

                const SizedBox(height: 4),

                Text(
                  'ID: ${data.id} • TG: ${data.telegramId}',
                  style: AppText.medium_14.copyWith(color: AppColors.grey),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    _roleBadge(),
                    if (data.isEmployee) ...[
                      const SizedBox(width: 8),
                      _statusBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),

          IconButton.outlined(
            onPressed: () {},
            icon: const Icon(Icons.edit),
            iconSize: 18,
            padding: const EdgeInsets.all(7),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge() {
    return Text(
      data.isEmployee ? 'Сотрудник' : 'Пользователь',
      style: AppText.medium_14.copyWith(
        color: data.isEmployee ? AppColors.brown : AppColors.grey,
      ),
    );
  }

  Widget _statusBadge() {
    return Text(
      data.isActive ? 'Активен' : 'Неактивен',
      style: AppText.medium_14.copyWith(
        color: data.isActive ? AppColors.grey : AppColors.error,
      ),
    );
  }
}
