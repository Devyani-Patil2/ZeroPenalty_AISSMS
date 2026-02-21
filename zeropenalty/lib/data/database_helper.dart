import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip.dart';

/// SQLite database helper for local trip storage
class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'zeropenalty.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            driver_id INTEGER,
            start_time TEXT,
            end_time TEXT,
            duration_seconds INTEGER,
            distance_km REAL,
            local_score REAL,
            ml_score REAL,
            avg_speed REAL,
            max_speed REAL,
            overspeed_count INTEGER,
            harsh_brake_count INTEGER,
            sharp_turn_count INTEGER,
            rash_accel_count INTEGER,
            high_risk_events INTEGER,
            medium_risk_events INTEGER,
            low_risk_events INTEGER,
            points_earned INTEGER,
            is_anomaly INTEGER DEFAULT 0,
            feedback TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE coupons (
            id TEXT PRIMARY KEY,
            code TEXT,
            title TEXT,
            offer TEXT,
            location TEXT,
            unlocked_at TEXT,
            expires_at TEXT,
            status TEXT,
            badge_id TEXT,
            emoji TEXT
          )
        ''');
      },
    );
  }

  // --- Trips ---

  /// Insert a trip
  static Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return db.insert('trips', trip.toMap());
  }

  /// Get all trips for a driver, ordered by most recent
  static Future<List<Trip>> getTrips(int driverId) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'driver_id = ?',
      whereArgs: [driverId],
      orderBy: 'start_time DESC',
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  /// Get last N trips
  static Future<List<Trip>> getLastTrips(int driverId, int count) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'driver_id = ?',
      whereArgs: [driverId],
      orderBy: 'start_time DESC',
      limit: count,
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  /// Get trip by ID
  static Future<Trip?> getTripById(int id) async {
    final db = await database;
    final maps = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Trip.fromMap(maps.first);
  }

  /// Update trip with ML data
  static Future<void> updateTripML(
      int id, double mlScore, List<String> feedback) async {
    final db = await database;
    await db.update(
      'trips',
      {'ml_score': mlScore, 'feedback': feedback.join('|||')},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total trip count
  static Future<int> getTripCount(int driverId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM trips WHERE driver_id = ?',
      [driverId],
    );
    return result.first['count'] as int;
  }

  /// Get lifetime average score
  static Future<double> getAverageScore(int driverId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(COALESCE(ml_score, local_score)) as avg FROM trips WHERE driver_id = ?',
      [driverId],
    );
    return (result.first['avg'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total points
  static Future<int> getTotalPoints(int driverId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(points_earned) as total FROM trips WHERE driver_id = ?',
      [driverId],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // --- Coupons ---

  static Future<int> insertCoupon(Map<String, dynamic> couponMap) async {
    final db = await database;
    return db.insert('coupons', couponMap);
  }

  static Future<List<Map<String, dynamic>>> getCoupons() async {
    final db = await database;
    return db.query('coupons', orderBy: 'unlocked_at DESC');
  }

  static Future<void> updateCouponStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'coupons',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
