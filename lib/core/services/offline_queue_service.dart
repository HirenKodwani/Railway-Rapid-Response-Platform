import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:workmanager/workmanager.dart';

import 'sync_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_queue.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE attendance_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            incident_id TEXT,
            operator_id TEXT,
            latitude REAL,
            longitude REAL,
            timestamp TEXT,
            geofenceCheckRequired INTEGER,
            status TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE media_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            incident_id TEXT,
            operator_id TEXT,
            proof_type TEXT,
            file_path TEXT,
            text_content TEXT,
            latitude REAL,
            longitude REAL,
            timestamp TEXT,
            device_model TEXT,
            device_os TEXT,
            status TEXT,
            upload_id TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE media_queue ADD COLUMN upload_id TEXT');
        }
      },
    );
  }

  // --- Attendance ---

  Future<int> insertAttendance(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('attendance_queue', data, conflictAlgorithm: ConflictAlgorithm.replace);
    _registerSyncTask();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingAttendanceAndMarkProcessing() async {
    final db = await database;
    final rows = await db.query('attendance_queue', where: 'status = ?', whereArgs: ['pending']);
    if (rows.isNotEmpty) {
      final ids = rows.map((r) => r['id']).toList();
      await db.update('attendance_queue', {'status': 'processing'}, where: 'id IN (${ids.join(',')})');
    }
    return rows;
  }

  Future<void> revertAttendanceToPending(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update('attendance_queue', {'status': 'pending'}, where: 'id IN (${ids.join(',')})');
  }

  Future<void> deleteAttendance(int id) async {
    final db = await database;
    await db.delete('attendance_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- Media ---

  Future<int> insertMedia(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('media_queue', data, conflictAlgorithm: ConflictAlgorithm.replace);
    _registerSyncTask();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingMediaAndMarkProcessing() async {
    final db = await database;
    final rows = await db.query('media_queue', where: 'status = ?', whereArgs: ['pending']);
    if (rows.isNotEmpty) {
      final ids = rows.map((r) => r['id']).toList();
      await db.update('media_queue', {'status': 'processing'}, where: 'id IN (${ids.join(',')})');
    }
    return rows;
  }

  Future<void> revertMediaToPending(int id) async {
    final db = await database;
    await db.update('media_queue', {'status': 'pending'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMedia(int id) async {
    final db = await database;
    await db.delete('media_queue', where: 'id = ?', whereArgs: [id]);
  }

  void _registerSyncTask() {
    Workmanager().registerOneOffTask(
      DateTime.now().millisecondsSinceEpoch.toString(),
      syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
