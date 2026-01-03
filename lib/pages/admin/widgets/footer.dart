import 'package:azalia/components/colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminFooter extends StatefulWidget {
  const AdminFooter({super.key});

  @override
  State<AdminFooter> createState() => _AdminFooter();
}

class _AdminFooter extends State<AdminFooter> {
  final Map<int, Map<String, Object>> _footer = {
    0: {'icon': Icons.analytics_outlined, 'route': '/admin'},
    1: {'icon': Icons.local_shipping_outlined, 'route': '/admin'},
    2: {'icon': Icons.home_filled, 'route': '/'},
    3: {'icon': Icons.supervised_user_circle_outlined, 'route': '/admin'},
    4: {'icon': Icons.settings, 'route': '/admin'},
  };
  int _Active = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _footer.entries.map((entry) {
            int index = entry.key;
            IconData ico = entry.value['icon'] as IconData;
            String route = entry.value['route'] as String;

            return IconButton(
              onPressed: () {
                setState(() {
                  _Active = index;
                });
                context.go(route);
              },
              icon: Icon(
                ico,
                color: _Active == entry.key ? AppColors.brown : AppColors.grey,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
