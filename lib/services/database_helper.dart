import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/client.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'fund_manager.db');
      print('Database path: $path');
      
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDb,
        onOpen: (db) async {
          print('Database opened successfully');
          // Verify tables exist
          var tables = await db.query('sqlite_master', columns: ['name']);
          print('Available tables: ${tables.map((e) => e['name']).toList()}');
        },
      );
    } catch (e, stackTrace) {
      print('Error initializing database: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _createDb(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE clients(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          initialInvestment REAL NOT NULL,
          startingDate TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE transactions(
          id TEXT PRIMARY KEY,
          clientId TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          FOREIGN KEY (clientId) REFERENCES clients (id)
        )
      ''');
      
      print('Database tables created successfully');
    } catch (e, stackTrace) {
      print('Error creating database tables: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Client operations
  Future<int> insertClient(Client client) async {
    try {
      Database db = await database;
      final result = await db.insert(
        'clients',
        client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Client inserted successfully: ${client.toMap()}');
      return result;
    } catch (e, stackTrace) {
      print('Error inserting client: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Client>> getClients() async {
    try {
      Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query('clients');
      print('Retrieved ${maps.length} clients from database');
      return List.generate(maps.length, (i) {
        try {
          return Client.fromMap(maps[i]);
        } catch (e) {
          print('Error parsing client data: ${maps[i]}');
          rethrow;
        }
      });
    } catch (e, stackTrace) {
      print('Error getting clients: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Client?> getClient(String id) async {
    try {
      Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return Client.fromMap(maps.first);
    } catch (e, stackTrace) {
      print('Error getting client: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> updateClient(Client client) async {
    try {
      Database db = await database;
      return await db.update(
        'clients',
        client.toMap(),
        where: 'id = ?',
        whereArgs: [client.id],
      );
    } catch (e, stackTrace) {
      print('Error updating client: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> deleteClient(String id) async {
    try {
      Database db = await database;
      return await db.delete(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      print('Error deleting client: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
} 