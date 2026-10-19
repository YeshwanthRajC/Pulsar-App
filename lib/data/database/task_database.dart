import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../../models/task_model.dart';

class TaskDatabase {
  static final TaskDatabase instance = TaskDatabase._init();
  static Database? _database;

  TaskDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pulsar_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        filePath,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    }

    // If running on desktop platforms (Windows/Linux/macOS), initialize FFI
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT,
        due_time TEXT,
        has_reminder INTEGER NOT NULL DEFAULT 1,
        has_alarm INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        accent_color TEXT DEFAULT 'cyan'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN has_alarm INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> _onOpen(Database db) async {
    // Failsafe column check for previously created databases
    try {
      await db.execute('ALTER TABLE tasks ADD COLUMN has_alarm INTEGER NOT NULL DEFAULT 0');
    } catch (_) {
      // Column already exists
    }
  }

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    return await db.insert('tasks', task.toMap());
  }

  Future<Task?> getTaskById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'due_date ASC, due_time ASC, id DESC');
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final db = await instance.database;
    final datePrefix = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final result = await db.rawQuery('''
      SELECT * FROM tasks 
      WHERE due_date LIKE ? 
      ORDER BY is_completed ASC, due_time ASC, id DESC
    ''', ['$datePrefix%']);

    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksBetweenDates(DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}T23:59:59.999';

    final result = await db.rawQuery('''
      SELECT * FROM tasks 
      WHERE due_date >= ? AND due_date <= ?
      ORDER BY is_completed ASC, due_date ASC, due_time ASC, id DESC
    ''', [startStr, endStr]);

    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> searchTasks(String query) async {
    final db = await instance.database;
    final pattern = '%$query%';
    final result = await db.rawQuery('''
      SELECT * FROM tasks
      WHERE title LIKE ? OR description LIKE ?
      ORDER BY is_completed ASC, due_date ASC, due_time ASC, id DESC
    ''', [pattern, pattern]);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllTasks() async {
    final db = await instance.database;
    return await db.delete('tasks');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
