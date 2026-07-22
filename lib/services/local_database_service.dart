import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'local_food_items.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            expiryDate TEXT NOT NULL,
            barcode TEXT,
            price REAL,
            invoiceNum TEXT,
            reminderDays INTEGER,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  Future<int> addFoodItem(Map<String, dynamic> itemData) async {
    final db = await _db;
    return db.insert('local_items', itemData);
  }

  Future<void> updateFoodItem(String itemId, Map<String, dynamic> itemData) async {
    final db = await _db;
    await db.update(
      'local_items',
      itemData,
      where: 'id = ?',
      whereArgs: [int.parse(itemId)],
    );
  }

  Future<List<Map<String, dynamic>>> getFoodItems() async {
    final db = await _db;
    final rows = await db.query('local_items', orderBy: 'expiryDate ASC');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM local_items');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteItem(String itemId) async {
    final db = await _db;
    await db.delete(
      'local_items',
      where: 'id = ?',
      whereArgs: [int.parse(itemId)],
    );
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('local_items');
  }

  Future<void> deleteItems(List<int> itemIds) async {
    if (itemIds.isEmpty) return;

    final db = await _db;
    final batch = db.batch();
    for (final itemId in itemIds) {
      batch.delete('local_items', where: 'id = ?', whereArgs: [itemId]);
    }
    await batch.commit(noResult: true);
  }
}
