// lib/mobile_home_shell.dart
import 'package:flutter/material.dart';

import 'mobile_dashboard_page.dart';
import 'mobile_profile_page.dart';
import 'mobile_history_page.dart';
import 'mobile_coach_page.dart';
import 'mobile_community_page.dart';

class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  int _currentIndex = 0;

  // Dashboard and Profile are real pages.
  // History is now the real MobileHistoryPage.
  // AI Coach / Community are placeholders for now.
  final _pages = const [
    MobileDashboardPage(),       // 0 - Dashboard / Home
    MobileHistoryPage(),         // 1 - History
    MobileCoachPage(),   // 2 - AI Coach
    MobileCommunityPage(), // 3 - Community
    MobileProfilePage(),         // 4 - Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'AI Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Placeholder pages – later replaced with real implementations
