import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pcic_mobile_app/screens/settings/_settings.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onLogout;

  const HomeHeader({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              'Agent 007',
              style: TextStyle(
                  fontSize: 19.2,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
        PopupMenuButton<String>(
          color: Colors.white,
          offset: const Offset(-8, 45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          padding: EdgeInsets.zero,
          icon: SvgPicture.asset(
            'assets/storage/images/menu.svg',
            height: 35,
            width: 35,
          ),
          onSelected: (value) {
            if (value == 'Logout') {
              onLogout();
            } else {
              // Handle other menu item selections
              switch (value) {
                case 'Profile':
                  // Navigate to the profile screen
                  break;
                case 'Settings':
                  Navigator.push(
                    // Navigate to the SettingsScreen
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                  break;
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'Profile',
              child: ListTile(
                leading: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/storage/images/person.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                title: const Text('Profile'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'Settings',
              child: ListTile(
                leading: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/storage/images/settings.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                title: const Text('Settings'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'Logout',
              child: ListTile(
                leading: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/storage/images/logout.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                title: const Text('Logout'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
