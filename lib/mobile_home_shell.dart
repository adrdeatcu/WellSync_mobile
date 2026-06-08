// lib/mobile_home_shell.dart
import 'package:flutter/material.dart';

import 'mobile_dashboard_page.dart';
import 'mobile_profile_page.dart';

class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  int _currentIndex = 0;

  // Dashboard is real, History/AI Coach/Community are placeholders,
  // Profile is now the real MobileProfilePage.
  final _pages = const [
    MobileDashboardPage(),        // 0 - Dashboard / Home
    _HistoryPlaceholderPage(),    // 1 - History
    _AiCoachPlaceholderPage(),    // 2 - AI Coach
    _CommunityPlaceholderPage(),  // 3 - Community
    MobileProfilePage(),          // 4 - Profile
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

class _HistoryPlaceholderPage extends StatelessWidget {
  const _HistoryPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('History page (mobile) – to be implemented'),
    );
  }
}

class _AiCoachPlaceholderPage extends StatelessWidget {
  const _AiCoachPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('AI Coach page (mobile) – to be implemented'),
    );
  }
}

class _CommunityPlaceholderPage extends StatelessWidget {
  const _CommunityPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Community page (mobile) – to be implemented'),
    );
  }
}