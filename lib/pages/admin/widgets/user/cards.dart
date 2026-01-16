import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/employeesAdmin.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/employeesAdmin.dart';

class AdminSettingsPage extends StatefulWidget {
  final ApiClient api;
  const AdminSettingsPage({super.key, required this.api});

  State<AdminSettingsPage> createState() => _AdminSettingsPage();
}

class _AdminSettingsPage extends State<AdminSettingsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 8),
          // ToggleButtons(isSelected: [], children: [], ) позже добавится обработчик кнопок
          // Expanded(child: ) здесь будут вызываться _UsersList и _EmployeesList
        ],
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final ApiClient api;

  const _UsersList({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: EmployeesService(api).getUsers(),
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
            return Text(user.name);
          },
        );
      },
    );
  }
}

class _EmployeesList extends StatelessWidget {
  final ApiClient api;

  const _EmployeesList({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Employee>>(
      future: EmployeesService(api).getEmployees(),
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
            return Text(employ.userInfo.toString());
          },
        );
      },
    );
  }
}
