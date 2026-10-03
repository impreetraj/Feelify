import 'package:chat_ikokas/screen/Search_screen.dart';
import 'package:chat_ikokas/screen/chat_screen.dart';
import 'package:chat_ikokas/screen/home_screen.dart';
import 'package:chat_ikokas/screen/notify_screen.dart';
import 'package:chat_ikokas/screen/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int currentIndex = 0;
  bool isNavVisible = true;

  final List<Widget> screen = [
    const HomeScreen(),
    const ChatScreen(),
    const NotifyScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.forward) {
            if (!isNavVisible) setState(() => isNavVisible = true);
          } else if (notification.direction == ScrollDirection.reverse) {
            if (isNavVisible) setState(() => isNavVisible = false);
          }
          return false;
        },
        child: screen[currentIndex],
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isNavVisible
              ? BottomNavigationBar(
                  currentIndex: currentIndex,
                  type: BottomNavigationBarType.fixed,
                  onTap: (value) {
                    setState(() {
                      currentIndex = value;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.home), label: "Home"),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.chat), label: "Chat"),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.notification_add),
                        label: "Notification"),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.search), label: "Search"),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.person), label: "Profile"),
                  ],
                )
              : const SizedBox(height: 0, width: double.infinity),
        ),
      ),
    );
  }
}
