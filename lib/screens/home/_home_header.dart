import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pcic_mobile_app/screens/profile/_profile_view.dart';
import 'package:pcic_mobile_app/screens/settings/_settings.dart';
import 'package:pcic_mobile_app/theme/_theme.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onLogout;

  const HomeHeader({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<CustomThemeExtension>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                  fontSize: t.caption,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              'Agent 007 👋',
              style: TextStyle(
                fontSize: t.title,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
        PopupMenuButton<String>(
          splashRadius: 0.0,
          color: Colors.white,
          offset: const Offset(-8, 55),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          padding: EdgeInsets.zero,
          child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0F7D40)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.transparent,
                child: Image.asset(
                  'assets/storage/images/cool.png',
                  fit: BoxFit.cover,
                  height: 30,
                ),
              )),
          onSelected: (value) {
            if (value == 'Logout') {
              onLogout();
            } else {
              // Handle other menu item selections
              switch (value) {
                case 'Profile':
                  Navigator.push(
                    // Navigate to the SettingsScreen
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfilePage()),
                  );
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
