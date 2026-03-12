import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/employeesAdmin.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/widgets/account_blocked_notice.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/admin/widgets/user/widget/users.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/employeesAdmin.dart';
import 'package:azalia/pages/error/app_errors.dart';
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

  @override
  State<AdminUsersPage> createState() => _AdminSettingsPage();
}

enum _UserTab { user, employees }

class _AdminSettingsPage extends State<AdminUsersPage> {
  _UserTab _currentTab = _UserTab.user;
  bool _isAdmin = false;
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
  }

  Future<void> _loadCurrentRole() async {
    try {
      final whoAmI = await EmployeesService(ApiClient()).whoAmI();
      if (!mounted) return;
      setState(() => _isAdmin = whoAmI.isAdmin);
    } catch (_) {}
  }

  void _refreshAfterChanges() {
    setState(() {
      _reloadKey++;
    });
  }

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
          child: _currentTab == _UserTab.user
              ? _UsersList(
                  canManage: _isAdmin,
                  reloadKey: _reloadKey,
                  onDataChanged: _refreshAfterChanges,
                )
              : _EmployeesList(
                  canManage: _isAdmin,
                  reloadKey: _reloadKey,
                  onDataChanged: _refreshAfterChanges,
                ),
        ),
      ],
    );
  }
}

class _UsersList extends StatefulWidget {
  final bool canManage;
  final int reloadKey;
  final VoidCallback onDataChanged;

  const _UsersList({
    required this.canManage,
    required this.reloadKey,
    required this.onDataChanged,
  });

  @override
  State<_UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<_UsersList> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeesService(ApiClient()).getUsers();
  }

  @override
  void didUpdateWidget(covariant _UsersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _future = EmployeesService(ApiClient()).getUsers();
    }
  }

  Future<void> _refresh() async {
    final future = EmployeesService(ApiClient()).getUsers();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: _future,
      builder: (context, snapshot) {
        // Загрузка
        if (snapshot.connectionState == ConnectionState.waiting) {
          // добавить UI
          return const Center(child: Text("Подождите!!"));
        }
        // ERROR
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          if (AppErrors.isForbiddenAccountError(err)) {
            return const AccountBlockedNotice();
          }
          return const Center(child: Text("Error"));
        }
        // SUCCESS
        final users = snapshot.data!;
        if (users.isEmpty) {
          // добавить UI
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text("Список товаров пуст :(")),
              ],
            ),
          );
        }
        // UI
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  avatarBase64: user.avatarUrl,
                ),
                viewData: AdminUserViewData(
                  userId: user.id,
                  name: user.name,
                  canManage: widget.canManage,
                ),
                onChanged: widget.onDataChanged,
              );
            },
          ),
        );
      },
    );
  }
}

class _EmployeesList extends StatefulWidget {
  final bool canManage;
  final int reloadKey;
  final VoidCallback onDataChanged;

  const _EmployeesList({
    required this.canManage,
    required this.reloadKey,
    required this.onDataChanged,
  });

  @override
  State<_EmployeesList> createState() => _EmployeesListState();
}

class _EmployeesListState extends State<_EmployeesList> {
  late Future<List<Employee>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeesService(ApiClient()).getEmployees();
  }

  @override
  void didUpdateWidget(covariant _EmployeesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _future = EmployeesService(ApiClient()).getEmployees();
    }
  }

  Future<void> _refresh() async {
    final future = EmployeesService(ApiClient()).getEmployees();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Employee>>(
      future: _future,
      builder: (context, snapshot) {
        // Загрузка
        if (snapshot.connectionState == ConnectionState.waiting) {
          // добавить UI
          return const Center(child: Text("Подождите!!"));
        }
        // ERROR
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          if (AppErrors.isForbiddenAccountError(err)) {
            return const AccountBlockedNotice();
          }
          return const Center(child: Text("Error"));
        }
        // SUCCESS
        final employees = snapshot.data!;
        if (employees.isEmpty) {
          // добавить UI
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text("Список товаров пуст :(")),
              ],
            ),
          );
        }
        // UI
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employ = employees[index];
              return _UserCard(
                data: UserCardData(
                  id: employ.userId,
                  telegramId: employ.telegramId,
                  name: employ.fullName,
                  isEmployee: true,
                  isActive: employ.isActive,
                  avatarBase64: employ.avatarUrl,
                ),
                viewData: AdminUserViewData(
                  userId: employ.userId,
                  name: employ.fullName,
                  canManage: widget.canManage,
                ),
                onChanged: widget.onDataChanged,
              );
            },
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserCardData data;
  final AdminUserViewData viewData;
  final VoidCallback onChanged;

  const _UserCard({
    required this.data,
    required this.viewData,
    required this.onChanged,
  });

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
            onPressed: () async {
              final changed = await showAdminUserViewDialog(context, user: viewData);
              if (changed) {
                onChanged();
              }
            },
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
