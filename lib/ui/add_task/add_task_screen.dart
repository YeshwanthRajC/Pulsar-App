import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'voice_input_tab.dart';
import 'manual_entry_tab.dart';

class AddTaskScreen extends StatefulWidget {
  final int initialTabIndex;

  const AddTaskScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Task',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
          indicatorWeight: 3,
          labelColor: isDark ? AppColors.pulsarCyan : AppColors.lightCyan,
          unselectedLabelColor: isDark
              ? AppColors.moonlightGrey
              : AppColors.lightTextSecondary,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome, size: 20),
              text: 'Through Speech',
            ),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Manual Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          VoiceInputTab(
            onSwitchToManual: () {
              _tabController.animateTo(1);
            },
          ),
          ManualEntryTab(
            onTaskSaved: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
