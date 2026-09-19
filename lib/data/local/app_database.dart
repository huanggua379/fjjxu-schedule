import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/entities.dart';

/// 本地 SQLite 数据库（离线缓存 + 用户本地设置）。
/// 服务器原始数据（课表/成绩）与用户本地设置（隐藏/提醒）分表存储，
/// 同步时只覆盖服务器数据表，绝不动用户设置表 —— 保证隐藏状态不被恢复。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'keben.db';
  static const _version = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        final b = db.batch();
        b.execute('''
          CREATE TABLE schedule_entry(
            entryId TEXT PRIMARY KEY,
            courseId TEXT NOT NULL,
            courseName TEXT NOT NULL,
            teacher TEXT,
            weekday INTEGER,
            startSection INTEGER,
            endSection INTEGER,
            weeks TEXT,
            location TEXT,
            campus TEXT,
            rawJc TEXT,
            rawWeeks TEXT,
            credit TEXT,
            assessType TEXT,
            xnm INTEGER,
            xqm INTEGER
          )''');
        b.execute('''
          CREATE TABLE grade(
            gradeId TEXT PRIMARY KEY,
            courseName TEXT,
            teacher TEXT,
            xnm INTEGER,
            xqm INTEGER,
            termName TEXT,
            credit TEXT,
            score TEXT,
            gpa TEXT,
            hundredScore TEXT,
            nature TEXT,
            category TEXT,
            assessType TEXT,
            examType TEXT,
            usualScore TEXT,
            midScore TEXT,
            expScore TEXT,
            finalScore TEXT
          )''');
        // 用户本地设置（同步不覆盖）
        b.execute('CREATE TABLE hidden_course(courseId TEXT PRIMARY KEY, hiddenAt INTEGER)');
        b.execute('''
          CREATE TABLE hidden_occurrence(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entryId TEXT NOT NULL,
            week INTEGER NOT NULL,
            UNIQUE(entryId, week)
          )''');
        b.execute('''
          CREATE TABLE course_reminder(
            courseId TEXT PRIMARY KEY,
            enabled INTEGER,
            mode TEXT,
            minutesBefore INTEGER
          )''');
        b.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
        await b.commit(noResult: true);
      },
    );
  }

  // ---------------- 课表 ----------------
  /// 用服务器数据整体替换某学期的课表（不影响隐藏表）。
  Future<void> replaceSchedule(Semester sem, List<ScheduleEntry> entries) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('schedule_entry',
          where: 'xnm=? AND xqm=?', whereArgs: [sem.xnm, sem.xqm]);
      final b = txn.batch();
      for (final e in entries) {
        b.insert('schedule_entry', e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await b.commit(noResult: true);
    });
  }

  Future<List<ScheduleEntry>> scheduleOf(Semester sem) async {
    final db = await database;
    final rows = await db.query('schedule_entry',
        where: 'xnm=? AND xqm=?', whereArgs: [sem.xnm, sem.xqm]);
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<List<ScheduleEntry>> allSchedule() async {
    final db = await database;
    final rows = await db.query('schedule_entry');
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  // ---------------- 成绩 ----------------
  Future<void> replaceGrades(List<Grade> grades) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grade');
      final b = txn.batch();
      for (final g in grades) {
        b.insert('grade', g.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await b.commit(noResult: true);
    });
  }

  Future<List<Grade>> allGrades() async {
    final db = await database;
    final rows = await db.query('grade');
    return rows.map(Grade.fromMap).toList();
  }

  // ---------------- 隐藏课程（用户设置，同步保留）----------------
  Future<Set<String>> hiddenCourseIds() async {
    final db = await database;
    final rows = await db.query('hidden_course', columns: ['courseId']);
    return rows.map((r) => r['courseId'] as String).toSet();
  }

  Future<void> hideCourse(String courseId) async {
    final db = await database;
    await db.insert('hidden_course',
        {'courseId': courseId, 'hiddenAt': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unhideCourse(String courseId) async {
    final db = await database;
    await db.delete('hidden_course', where: 'courseId=?', whereArgs: [courseId]);
  }

  Future<void> unhideAllCourses() async {
    final db = await database;
    await db.delete('hidden_course');
  }

  // ---------------- 隐藏单次课程 ----------------
  Future<Set<String>> hiddenOccurrenceKeys() async {
    final db = await database;
    final rows = await db.query('hidden_occurrence');
    return rows.map((r) => '${r['entryId']}#${r['week']}').toSet();
  }

  Future<void> hideOccurrence(String entryId, int week) async {
    final db = await database;
    await db.insert('hidden_occurrence', {'entryId': entryId, 'week': week},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> unhideOccurrence(String entryId, int week) async {
    final db = await database;
    await db.delete('hidden_occurrence',
        where: 'entryId=? AND week=?', whereArgs: [entryId, week]);
  }

  Future<List<Map<String, dynamic>>> hiddenOccurrences() async {
    final db = await database;
    return db.query('hidden_occurrence');
  }

  // ---------------- 单课程提醒设置 ----------------
  Future<Map<String, CourseReminderSetting>> reminderSettings() async {
    final db = await database;
    final rows = await db.query('course_reminder');
    final map = <String, CourseReminderSetting>{};
    for (final r in rows) {
      final s = CourseReminderSetting.fromMap(r);
      map[s.courseId] = s;
    }
    return map;
  }

  Future<void> saveReminderSetting(CourseReminderSetting s) async {
    final db = await database;
    await db.insert('course_reminder', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteReminderSetting(String courseId) async {
    final db = await database;
    await db.delete('course_reminder', where: 'courseId=?', whereArgs: [courseId]);
  }

  // ---------------- meta ----------------
  Future<void> setMeta(String k, String v) async {
    final db = await database;
    await db.insert('meta', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String k) async {
    final db = await database;
    final rows = await db.query('meta', where: 'k=?', whereArgs: [k]);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  /// 清除所有本地数据（设置页“清除本地数据”）。
  Future<void> clearAll() async {
    final db = await database;
    final b = db.batch();
    for (final t in [
      'schedule_entry',
      'grade',
      'hidden_course',
      'hidden_occurrence',
      'course_reminder',
      'meta'
    ]) {
      b.delete(t);
    }
    await b.commit(noResult: true);
  }
}
