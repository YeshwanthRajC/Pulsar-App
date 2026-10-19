import '../database/task_database.dart';
import '../../models/task_model.dart';

class TaskRepository {
  final TaskDatabase _db = TaskDatabase.instance;

  Future<List<Task>> getAllTasks() async {
    return await _db.getAllTasks();
  }

  Future<List<Task>> getTasksForDate(DateTime date) async {
    return await _db.getTasksForDate(date);
  }

  Future<List<Task>> getPendingTasks() async {
    final all = await _db.getAllTasks();
    return all.where((t) => !t.isCompleted).toList();
  }

  Future<List<Task>> getCompletedTasks() async {
    final all = await _db.getAllTasks();
    return all.where((t) => t.isCompleted).toList();
  }

  Future<List<Task>> getOverdueTasks() async {
    final all = await _db.getAllTasks();
    return all.where((t) => t.isOverdue).toList();
  }

  Future<List<Task>> getTasksBetweenDates(DateTime start, DateTime end) async {
    return await _db.getTasksBetweenDates(start, end);
  }

  Future<List<Task>> searchTasks(String query) async {
    return await _db.searchTasks(query);
  }

  /// Retrieves tasks across any specified period of time (e.g. today, tomorrow,
  /// yesterday, this_week, next_week, this_month, overdue, upcoming, etc.),
  /// with optional status filtering and keyword matching.
  Future<List<Task>> getTasksForPeriod(
    String period, {
    String? status,
    String? keyword,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normPeriod = period.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '_');

    // Handle relative day spans (e.g. "last_3_days", "past_7_days")
    final pastDaysMatch = RegExp(r'^(?:last|past)_(\d+)_days?$').firstMatch(normPeriod);
    final nextDaysMatch = RegExp(r'^next_(\d+)_days?$').firstMatch(normPeriod);
    final pastWeeksMatch = RegExp(r'^(?:last|past)_(\d+)_weeks?$').firstMatch(normPeriod);

    List<Task> tasks;

    if (pastDaysMatch != null) {
      final days = int.parse(pastDaysMatch.group(1)!);
      final start = today.subtract(Duration(days: days));
      final all = await getAllTasks();
      final startBoundary = DateTime(start.year, start.month, start.day);
      final endBoundary = DateTime(today.year, today.month, today.day, 23, 59, 59);

      tasks = all.where((t) {
        if (t.dueDate != null) {
          final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          if (!d.isBefore(startBoundary) && !d.isAfter(endBoundary)) return true;
        }
        if (t.completedAt != null) {
          if (!t.completedAt!.isBefore(startBoundary) && !t.completedAt!.isAfter(endBoundary)) {
            return true;
          }
        }
        return false;
      }).toList();
    } else if (nextDaysMatch != null) {
      final days = int.parse(nextDaysMatch.group(1)!);
      final end = today.add(Duration(days: days));
      tasks = await getTasksBetweenDates(today, end);
    } else if (pastWeeksMatch != null) {
      final weeks = int.parse(pastWeeksMatch.group(1)!);
      final start = today.subtract(Duration(days: weeks * 7));
      tasks = await getTasksBetweenDates(start, today);
    } else {
      switch (normPeriod) {
        case 'today':
          tasks = await getTasksForDate(today);
          break;

      case 'tomorrow':
        tasks = await getTasksForDate(today.add(const Duration(days: 1)));
        break;

      case 'yesterday':
        tasks = await getTasksForDate(today.subtract(const Duration(days: 1)));
        break;

      case 'this_week':
      case 'week':
      case 'current_week':
        // Monday (1) to Sunday (7)
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        tasks = await getTasksBetweenDates(monday, sunday);
        break;

      case 'next_week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final nextMonday = monday.add(const Duration(days: 7));
        final nextSunday = nextMonday.add(const Duration(days: 6));
        tasks = await getTasksBetweenDates(nextMonday, nextSunday);
        break;

      case 'last_week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final lastMonday = monday.subtract(const Duration(days: 7));
        final lastSunday = monday.subtract(const Duration(days: 1));
        tasks = await getTasksBetweenDates(lastMonday, lastSunday);
        break;

      case 'this_month':
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        tasks = await getTasksBetweenDates(startOfMonth, endOfMonth);
        break;

      case 'next_month':
        final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
        final endOfNextMonth = DateTime(now.year, now.month + 2, 0);
        tasks = await getTasksBetweenDates(startOfNextMonth, endOfNextMonth);
        break;

      case 'weekend':
      case 'this_weekend':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final saturday = monday.add(const Duration(days: 5));
        final sunday = monday.add(const Duration(days: 6));
        tasks = await getTasksBetweenDates(saturday, sunday);
        break;

      case 'upcoming':
      case 'future':
        final all = await getAllTasks();
        tasks = all.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return true;
          final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return !d.isBefore(today);
        }).toList();
        break;

      case 'overdue':
        tasks = await getOverdueTasks();
        break;

      case 'pending':
        tasks = await getPendingTasks();
        break;

      case 'completed':
        tasks = await getCompletedTasks();
        break;

      // Weekdays
      case 'monday':
      case 'tuesday':
      case 'wednesday':
      case 'thursday':
      case 'friday':
      case 'saturday':
      case 'sunday':
        final dayMap = {
          'monday': 1,
          'tuesday': 2,
          'wednesday': 3,
          'thursday': 4,
          'friday': 5,
          'saturday': 6,
          'sunday': 7,
        };
        final targetDay = dayMap[normPeriod]!;
        int daysAhead = targetDay - today.weekday;
        if (daysAhead < 0) daysAhead += 7;
        final targetDate = today.add(Duration(days: daysAhead));
        tasks = await getTasksForDate(targetDate);
        break;

      case 'all':
      default:
        tasks = await getAllTasks();
        break;
      }
    }

    // Apply status filter if specified
    if (status != null && status.isNotEmpty) {
      final s = status.toLowerCase();
      if (s == 'pending') {
        tasks = tasks.where((t) => !t.isCompleted).toList();
      } else if (s == 'completed') {
        tasks = tasks.where((t) => t.isCompleted).toList();
      } else if (s == 'overdue') {
        tasks = tasks.where((t) => t.isOverdue).toList();
      }
    }

    // Apply keyword search if specified
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim().toLowerCase();
      tasks = tasks.where((t) {
        final titleMatch = t.title.toLowerCase().contains(k);
        final descMatch = t.description?.toLowerCase().contains(k) ?? false;
        return titleMatch || descMatch;
      }).toList();
    }

    return tasks;
  }

  /// Calculates quick stats for tasks in a given period.
  Future<Map<String, dynamic>> getTaskStatsOverPeriod(String period) async {
    final tasks = await getTasksForPeriod(period);
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => !t.isCompleted).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final rate = total > 0 ? ((completed / total) * 100).round() : 0;

    return {
      'period': period,
      'total': total,
      'completed': completed,
      'pending': pending,
      'overdue': overdue,
      'completionRate': rate,
    };
  }

  Future<Task> createTask(Task task) async {
    final id = await _db.insertTask(task);
    return task.copyWith(id: id);
  }

  Future<Task?> getTaskById(int id) async {
    return await _db.getTaskById(id);
  }

  Future<bool> updateTask(Task task) async {
    final count = await _db.updateTask(task);
    return count > 0;
  }

  Future<bool> deleteTask(int id) async {
    final count = await _db.deleteTask(id);
    return count > 0;
  }

  Future<Task?> toggleTask(int id) async {
    final task = await _db.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await _db.updateTask(updated);
    return updated;
  }

  Future<void> clearAll() async {
    await _db.deleteAllTasks();
  }

  /// Removes any previously seeded predefined sample tasks if present in the database.
  Future<void> removePredefinedTasksIfPresent() async {
    final all = await _db.getAllTasks();
    for (final task in all) {
      final isPredefined = (task.title == 'Complete Java assignment' &&
              (task.description == null || task.description == 'Finish all questions and push to GitHub.')) ||
          (task.title == 'Prepare project presentation' &&
              (task.description == null || task.description == 'Prepare slides and demo script.')) ||
          (task.title == 'Review DSA concepts' &&
              (task.description == null || task.description == 'Review trees, graphs, and dynamic programming.'));
      if (isPredefined && task.id != null) {
        await _db.deleteTask(task.id!);
      }
    }
  }
}

