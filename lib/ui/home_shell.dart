import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'list_screen.dart';
import 'rates_screen.dart';

/// 下部タブ（一覧 / 履歴 / 為替レート）。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ListScreen(onOpenRates: () => _select(2)),
          const HistoryScreen(),
          const RatesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.format_list_bulleted), label: '一覧'),
          NavigationDestination(icon: Icon(Icons.schedule), label: '履歴'),
          NavigationDestination(icon: Icon(Icons.swap_vert), label: '為替レート'),
        ],
      ),
    );
  }
}
