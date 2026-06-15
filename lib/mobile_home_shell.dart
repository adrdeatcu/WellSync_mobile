// lib/mobile_home_shell.dart
import 'package:flutter/material.dart';

import 'mobile_dashboard_page.dart';
import 'mobile_profile_page.dart';
import 'mobile_history_page.dart';
import 'mobile_coach_page.dart';
import 'mobile_community_page.dart';
import 'widgets/mobile_coach_fab.dart'; // NEW

class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  int _currentIndex = 0;

  // Keep pages in fields so we can replace the coach page with a new initialQuestion
  late MobileDashboardPage _dashboardPage;
  late MobileHistoryPage _historyPage;
  late MobileCoachPage _coachPage;
  late MobileCommunityPage _communityPage;
  late MobileProfilePage _profilePage;

  @override
  void initState() {
    super.initState();
    _dashboardPage = const MobileDashboardPage();
    _historyPage = const MobileHistoryPage();
    _coachPage = const MobileCoachPage();
    _communityPage = const MobileCommunityPage();
    _profilePage = const MobileProfilePage();
  }

  void _openCoach(String? initialQuestion) {
    setState(() {
      _coachPage = MobileCoachPage(initialQuestion: initialQuestion);
      _currentIndex = 2; // AI Coach tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboardPage,
      _historyPage,
      _coachPage,
      _communityPage,
      _profilePage,
    ];

    return Scaffold(
      body: Stack(
        children: [
          pages[_currentIndex],
          if (_currentIndex == 0)
            MobileCoachFab(
              onOpenCoach: _openCoach,
            ),
        ],
      ),
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