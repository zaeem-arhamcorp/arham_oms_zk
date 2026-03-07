import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    String path = join(await getDatabasesPath(), 'arham_offline.db');

    return await openDatabase(
      path,
      version: 11,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 had broken schema (trailing comma in offline_orders, wrong cart_items columns)
      // Drop and recreate affected tables safely
      await db.execute('DROP TABLE IF EXISTS offline_order_items');
      await db.execute('DROP TABLE IF EXISTS offline_orders');
      await db.execute('DROP TABLE IF EXISTS cart_items');

      await _createCartItemsTable(db);
      await _createOfflineOrdersTable(db);
      await _createOfflineOrderItemsTable(db);
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_sync_status ON offline_orders(sync_status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cart_items_item ON cart_items(item_cd, party_cd)');
    }
    if (oldVersion < 3) {
      // v2 to v3: Add products_cache table for offline product availability
      await db.execute('''
      CREATE TABLE IF NOT EXISTS products_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_cd TEXT UNIQUE NOT NULL,
        product_json TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        department_code TEXT,
        item_name TEXT
      )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_cache_dept ON products_cache(department_code)');
    }
    if (oldVersion < 4) {
      // v3 to v4: Add acc_cd column to parties and provide caching helpers
      try {
        await db.execute('ALTER TABLE parties ADD COLUMN acc_cd TEXT');
      } catch (e) {
        // ignore if column already exists
      }
    }
    if (oldVersion < 5) {
      // v4 to v5: Add profile_cache, home_cache, orders_cache tables
      await db.execute('''
      CREATE TABLE IF NOT EXISTS profile_cache (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        profile_json TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS home_cache (
        key TEXT PRIMARY KEY,
        data_json TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS orders_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_order_id TEXT,
        order_json TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
      ''');
    }
    if (oldVersion < 6) {
      // v5 to v6: add item_name to offline_order_items so sync can match products
      try {
        await db.execute(
            "ALTER TABLE offline_order_items ADD COLUMN item_name TEXT DEFAULT ''");
      } catch (e) {
        // ignore if column already exists or alter not supported
      }
    }
    if (oldVersion < 7) {
      // v6 to v7: Add settings table
      await _createSettingsTable(db);
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_sync_var ON settings(SYNC_ID, VARIABLE)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_settings_variable ON settings(VARIABLE)');
    }
    if (oldVersion < 8) {
      // v7 to v8: Add departments cache table
      await _createDepartmentsTable(db);
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_departments_code ON departments(DEPT_CD)');
    }
    if (oldVersion < 9) {
      // v8 to v9: Add locations table for punch-in/punch-out and order tracking
      await _createLocationsTable(db);
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_locations_user_date ON locations(SYNC_ID, USER_CD, VOUCH_DT)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_locations_module ON locations(MODULE_NO)');
    }
    if (oldVersion < 10) {
      // v9 to v10: Add order_tracking table for offline start/end order
      await _createOrderTrackingTable(db);
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_order_tracking_sync_status ON order_tracking(sync_status)');
    }
    if (oldVersion < 11) {
      // v10 to v11: Add tracking_type column to distinguish START (1), ORDER PLACED (2), END (3)
      try {
        await db.execute(
            "ALTER TABLE order_tracking ADD COLUMN tracking_type TEXT DEFAULT 'unknown'");
        print(
            '[DATABASE] ✅ Added tracking_type column to order_tracking table');
      } catch (e) {
        print('[DATABASE] ⚠️ tracking_type column may already exist: $e');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // PRODUCTS CACHE - stores full product JSON for offline access
    await db.execute('''
    CREATE TABLE products_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_cd TEXT UNIQUE NOT NULL,
      product_json TEXT NOT NULL,
      cached_at INTEGER NOT NULL,
      department_code TEXT,
      item_name TEXT
    )
    ''');

    // PRODUCTS CACHE (legacy)
    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      name TEXT NOT NULL,
      price REAL,
      category TEXT,
      image_url TEXT,
      last_updated INTEGER,
      sync_status TEXT DEFAULT 'synced'
    )
    ''');

    // PARTIES CACHE
    await db.execute('''
    CREATE TABLE parties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      acc_cd TEXT,
      name TEXT NOT NULL,
      address TEXT,
      phone TEXT,
      last_updated INTEGER,
      sync_status TEXT DEFAULT 'synced'
    )
    ''');

    await _createCartItemsTable(db);
    await _createOfflineOrdersTable(db);
    await _createOfflineOrderItemsTable(db);
    await _createLocationsTable(db);

    // PROFILE & HOME & ORDERS CACHE
    await db.execute('''
    CREATE TABLE IF NOT EXISTS profile_cache (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      profile_json TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS home_cache (
      key TEXT PRIMARY KEY,
      data_json TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS orders_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_order_id TEXT,
      order_json TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
    ''');

    // SETTINGS CACHE - stores application settings for offline access\n    await _createSettingsTable(db);\n\n    // INDEXES FOR PERFORMANCE
    await db
        .execute('CREATE INDEX idx_products_server_id ON products(server_id)');
    await db
        .execute('CREATE INDEX idx_parties_server_id ON parties(server_id)');
    await db.execute(
        'CREATE INDEX idx_products_cache_dept ON products_cache(department_code)');
    await db.execute(
        'CREATE INDEX idx_orders_sync_status ON offline_orders(sync_status)');
    await db.execute(
        'CREATE INDEX idx_cart_items_item ON cart_items(item_cd, party_cd)');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_sync_var ON settings(SYNC_ID, VARIABLE)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_settings_variable ON settings(VARIABLE)');
  }

  // -------------------------------------------------------
  // Table creation helpers (used by both onCreate & onUpgrade)
  // -------------------------------------------------------

  Future<void> _createCartItemsTable(Database db) async {
    // Mirrors server `cart` table columns needed for offline usage
    await db.execute('''
    CREATE TABLE cart_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_cd TEXT,
      item_cd TEXT NOT NULL,
      quantity REAL DEFAULT 0,
      other_desc TEXT DEFAULT '',
      fld5 TEXT DEFAULT '',
      rate REAL DEFAULT 0,
      nrate REAL DEFAULT 0,
      lrate REAL DEFAULT 0,
      amount REAL DEFAULT 0,
      item_name TEXT DEFAULT '',
      last_updated INTEGER,
      sync_status TEXT DEFAULT 'pending'
    )
    ''');
  }

  Future<void> _createOfflineOrdersTable(Database db) async {
    // Mirrors server `ordr` table columns needed for offline usage
    await db.execute('''
    CREATE TABLE offline_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_order_id INTEGER,
      server_party_id TEXT NOT NULL,
      remarks TEXT,
      total_amount REAL,
      order_date INTEGER,
      latitude REAL,
      longitude REAL,
      sync_status TEXT DEFAULT 'pending',
      sync_attempts INTEGER DEFAULT 0,
      last_sync_attempt INTEGER,
      error_message TEXT
    )
    ''');
  }

  Future<void> _createOfflineOrderItemsTable(Database db) async {
    // Mirrors server `ordritm` table columns needed for offline usage
    await db.execute('''
    CREATE TABLE offline_order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER,
      item_cd TEXT NOT NULL,
      item_name TEXT DEFAULT '',
      quantity REAL DEFAULT 0,
      rate REAL DEFAULT 0,
      nrate REAL DEFAULT 0,
      lrate REAL DEFAULT 0,
      amount REAL DEFAULT 0,
      other_desc TEXT DEFAULT '',
      fld5 TEXT DEFAULT '',
      FOREIGN KEY (order_id) REFERENCES offline_orders(id)
    )
    ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    // Mirrors server `settings` table columns for offline access
    await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      sId INTEGER PRIMARY KEY AUTOINCREMENT,
      SETTING_NAME TEXT NOT NULL DEFAULT '',
      DESCRI TEXT NOT NULL DEFAULT '',
      VARIABLE TEXT NOT NULL DEFAULT '',
      MODULE_TYPE TEXT,
      VALUE TEXT NOT NULL,
      VALUE_AMT INTEGER DEFAULT 0,
      SHOW_USER INTEGER DEFAULT 0,
      SYNC_ID INTEGER NOT NULL,
      CREATED_BY TEXT NOT NULL DEFAULT '',
      CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UPDATED_BY TEXT NOT NULL DEFAULT '',
      UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      CREATED_APP_TYPE TEXT NOT NULL DEFAULT '',
      CATEGORY TEXT,
      UNIQUE(SYNC_ID, VARIABLE)
    )
    ''');
  }

  /*
  ==============================
  PRODUCT CACHE
  ==============================
  */

  Future<void> insertProducts(List<Map<String, dynamic>> products) async {
    final db = await database;

    Batch batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        product,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  /*
  ==============================
  PARTIES CACHE
  ==============================
  */

  Future<void> insertParties(List<Map<String, dynamic>> parties) async {
    final db = await database;

    Batch batch = db.batch();

    for (var party in parties) {
      batch.insert(
        'parties',
        party,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Cache parties fetched from API for offline use.
  /// Expects maps with keys: acc_cd, name, address, phone, last_updated
  Future<void> cachePartiesJson(List<Map<String, dynamic>> parties) async {
    final db = await database;
    Batch batch = db.batch();

    // Clear old cache
    batch.delete('parties');

    for (var party in parties) {
      batch.insert(
        'parties',
        party,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getParties() async {
    final db = await database;
    return await db.query('parties');
  }

  /// Get cached parties for offline mode (alias to getParties)
  Future<List<Map<String, dynamic>>> getCachedParties() async {
    return await getParties();
  }

  /*
  ==============================
  CART
  ==============================
  */

  Future<int> insertCartItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('cart_items', item);
  }

  /// Insert or update a cart item (upsert by item_cd + party_cd)
  Future<int> insertOrUpdateCartItem(Map<String, dynamic> item) async {
    final db = await database;
    final existing = await db.query(
      'cart_items',
      where: 'item_cd = ? AND party_cd = ?',
      whereArgs: [item['item_cd'], item['party_cd']],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'cart_items',
        item,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return existing.first['id'] as int;
    } else {
      return await db.insert('cart_items', item);
    }
  }

  /// Get cart items for a specific party
  /// If partyId is empty/null, returns all items (for backward compatibility)
  Future<List<Map<String, dynamic>>> getCartItems({String partyId = ''}) async {
    final db = await database;
    if (partyId.isEmpty) {
      // Fallback: return all items (shouldn't happen in normal flow)
      return await db.query('cart_items');
    }
    // Filter by party_cd
    return await db.query(
      'cart_items',
      where: 'party_cd = ?',
      whereArgs: [partyId],
    );
  }

  Future<void> deleteCartItemByItemCd(String itemCd, String partyCd) async {
    final db = await database;
    await db.delete(
      'cart_items',
      where: 'item_cd = ? AND party_cd = ?',
      whereArgs: [itemCd, partyCd],
    );
  }

  Future<void> clearCart() async {
    final db = await database;
    await db.delete('cart_items');
  }

  /*
  ==============================
  OFFLINE ORDERS
  ==============================
  */

  Future<int> insertOfflineOrder(Map<String, dynamic> order) async {
    final db = await database;
    return await db.insert('offline_orders', order);
  }

  Future<void> insertOrderItems(List<Map<String, dynamic>> items) async {
    final db = await database;

    Batch batch = db.batch();

    for (var item in items) {
      batch.insert('offline_order_items', item);
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;

    return await db.query(
      'offline_orders',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
  }

  /// Get all orders that are pending or failed (for UI display)
  Future<List<Map<String, dynamic>>> getPendingOrFailedOrders() async {
    final db = await database;
    return await db.query(
      'offline_orders',
      where: "sync_status IN ('pending', 'failed')",
    );
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await database;

    return await db.query(
      'offline_order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateOrderStatus(
      int orderId, String status, int? serverOrderId) async {
    final db = await database;

    await db.update(
      'offline_orders',
      {
        'sync_status': status,
        'server_order_id': serverOrderId,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateRetry(int orderId, String error) async {
    final db = await database;

    await db.rawUpdate('''
    UPDATE offline_orders
    SET sync_attempts = sync_attempts + 1,
        last_sync_attempt = ?,
        error_message = ?
    WHERE id = ?
    ''', [DateTime.now().millisecondsSinceEpoch, error, orderId]);
  }

  /// Delete an offline order and its items after successful sync
  Future<void> deleteOfflineOrder(int orderId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('offline_order_items',
          where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete('offline_orders', where: 'id = ?', whereArgs: [orderId]);
    });
  }

  /// Clear cart items for a specific party
  Future<void> clearCartForParty(String partyId) async {
    final db = await database;
    await db.delete(
      'cart_items',
      where: 'party_cd = ?',
      whereArgs: [partyId],
    );
  }

  /*
  ==============================
  PRODUCTS CACHE (for offline)
  ==============================
  */

  /// Cache products when fetched from API
  /// Stores full product JSON to reconstruct DatumProduct objects
  Future<void> cacheProductsJson(List<Map<String, dynamic>> products) async {
    final db = await database;
    Batch batch = db.batch();

    // Clear old cache
    batch.delete('products_cache');

    // Insert new products
    for (var product in products) {
      batch.insert(
        'products_cache',
        product,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Profile cache: store single profile JSON (id enforced = 1)
  Future<void> cacheProfileJson(String profileJson) async {
    final db = await database;
    await db.insert(
      'profile_cache',
      {
        'id': 1,
        'profile_json': profileJson,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCachedProfileJson() async {
    final db = await database;
    final rows =
        await db.query('profile_cache', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return rows.first['profile_json'] as String?;
  }

  /// Home cache: store named home data blobs
  Future<void> cacheHomeData(String key, String dataJson) async {
    final db = await database;
    await db.insert(
      'home_cache',
      {
        'key': key,
        'data_json': dataJson,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCachedHomeData(String key) async {
    final db = await database;
    final rows =
        await db.query('home_cache', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['data_json'] as String?;
  }

  /// Orders cache: store server order JSON for offline viewing
  Future<void> cacheOrders(List<Map<String, dynamic>> orders) async {
    final db = await database;
    Batch batch = db.batch();
    // Clear old cache
    batch.delete('orders_cache');
    for (var order in orders) {
      batch.insert('orders_cache', {
        'server_order_id': order['server_order_id']?.toString(),
        'order_json': order['order_json']?.toString() ?? order.toString(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedOrders() async {
    final db = await database;
    return await db.query('orders_cache', orderBy: 'cached_at DESC');
  }

  /// Get cached products (for offline mode)
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    final db = await database;
    return await db.query('products_cache');
  }

  /// One-time helper to backfill missing item_cd in offline_order_items
  /// Attempts to match by `item_name` against `products_cache` and updates rows.
  /// Returns a summary map: {scanned, updated, ambiguous}
  Future<Map<String, int>> backfillOfflineOrderItems({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'offline_order_items',
      where: "(item_cd = '' OR item_cd IS NULL)",
      limit: limit,
    );

    int scanned = rows.length;
    int updated = 0;
    int ambiguous = 0;

    for (var row in rows) {
      final id = row['id'];
      final itemName = (row['item_name'] ?? '').toString().trim();

      if (itemName.isEmpty) {
        ambiguous++;
        print('Backfill: item id $id has no item_name, skipping');
        continue;
      }

      // Try exact match on products_cache.item_name
      final candidates = await db.query(
        'products_cache',
        where: 'item_name = ?',
        whereArgs: [itemName],
      );

      if (candidates.length == 1) {
        final foundCd = candidates.first['item_cd']?.toString() ?? '';
        if (foundCd.isNotEmpty) {
          await db.update(
            'offline_order_items',
            {'item_cd': foundCd},
            where: 'id = ?',
            whereArgs: [id],
          );
          updated++;
          print('Backfill: updated id $id -> $foundCd (exact match)');
          continue;
        }
      }

      // If multiple candidates or none, try parsing product_json and matching ITEM_NAME case-insensitive
      final fuzzy = await db.query('products_cache');
      String matchedCd = '';
      int matchCount = 0;

      for (var p in fuzzy) {
        try {
          final prodJson = p['product_json']?.toString() ?? '';
          if (prodJson.isEmpty) continue;
          final parsed = jsonDecode(prodJson) as Map<String, dynamic>;
          final jsonName = (parsed['ITEM_NAME'] ?? parsed['itemName'] ?? '')
              .toString()
              .trim();
          if (jsonName.isNotEmpty &&
              jsonName.toLowerCase() == itemName.toLowerCase()) {
            matchCount++;
            matchedCd = (parsed['ITEM_CD'] ?? parsed['itemCd'] ?? p['item_cd'])
                    ?.toString() ??
                '';
          }
        } catch (_) {}
      }

      if (matchCount == 1 && matchedCd.isNotEmpty) {
        await db.update(
          'offline_order_items',
          {'item_cd': matchedCd},
          where: 'id = ?',
          whereArgs: [id],
        );
        updated++;
        print('Backfill: updated id $id -> $matchedCd (json match)');
        continue;
      }

      // Last resort: try LIKE match on item_name column
      final likeMatches = await db.rawQuery(
          "SELECT * FROM products_cache WHERE item_name LIKE ? LIMIT 20",
          ['%$itemName%']);
      if (likeMatches.length == 1) {
        final foundCd = likeMatches.first['item_cd']?.toString() ?? '';
        if (foundCd.isNotEmpty) {
          await db.update(
            'offline_order_items',
            {'item_cd': foundCd},
            where: 'id = ?',
            whereArgs: [id],
          );
          updated++;
          print('Backfill: updated id $id -> $foundCd (LIKE match)');
          continue;
        }
      }

      ambiguous++;
      print(
          'Backfill: could not confidently match item id $id (name="$itemName")');
    }

    return {'scanned': scanned, 'updated': updated, 'ambiguous': ambiguous};
  }

  /// Get cached products by department
  Future<List<Map<String, dynamic>>> getCachedProductsByDepartment(
      String departmentCode) async {
    final db = await database;
    if (departmentCode.isEmpty) {
      return await getCachedProducts();
    }
    return await db.query(
      'products_cache',
      where: 'department_code = ?',
      whereArgs: [departmentCode],
    );
  }

  /// Clear products cache
  Future<void> clearProductsCache() async {
    final db = await database;
    await db.delete('products_cache');
  }

  /*
  ==============================
  SETTINGS CACHE
  ==============================
  */

  /// Cache all settings from server
  Future<void> cacheSettings(List<Map<String, dynamic>> settings) async {
    final db = await database;
    // Clear old settings
    await db.delete('settings');

    Batch batch = db.batch();
    for (var setting in settings) {
      batch.insert('settings', setting,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('[DATABASE] Cached ${settings.length} settings');
  }

  /// Get all cached settings
  Future<List<Map<String, dynamic>>> getAllSettings() async {
    final db = await database;
    return await db.query('settings', orderBy: 'VARIABLE');
  }

  /// Get setting by variable name
  Future<Map<String, dynamic>?> getSetting(String variable) async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'VARIABLE = ?',
      whereArgs: [variable],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Get settings by module type
  Future<List<Map<String, dynamic>>> getSettingsByModule(
      String moduleType) async {
    final db = await database;
    return await db.query(
      'settings',
      where: 'MODULE_TYPE = ?',
      whereArgs: [moduleType],
      orderBy: 'VARIABLE',
    );
  }

  /// Get settings by SYNC_ID (firm)
  Future<List<Map<String, dynamic>>> getSettingsByFirm(int syncId) async {
    final db = await database;
    return await db.query(
      'settings',
      where: 'SYNC_ID = ?',
      whereArgs: [syncId],
      orderBy: 'VARIABLE',
    );
  }

  /// Update a single setting
  Future<int> updateSetting(int sId, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'settings',
      data,
      where: 'sId = ?',
      whereArgs: [sId],
    );
  }

  /// Clear all cached settings
  Future<void> clearSettingsCache() async {
    final db = await database;
    await db.delete('settings');
    print('[DATABASE] Cleared settings cache');
  }

  /// Create departments cache table
  Future<void> _createDepartmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS departments (
        DEPT_CD TEXT PRIMARY KEY,
        DEPT_NAME TEXT NOT NULL,
        SYNC_ID TEXT,
        cached_at INTEGER NOT NULL
      )
    ''');
  }

  /// Cache departments for offline use
  Future<void> cacheDepartments(List<Map<String, dynamic>> departments) async {
    final db = await database;
    // Clear old departments
    await db.delete('departments');

    Batch batch = db.batch();
    for (var dept in departments) {
      // Add cached_at timestamp if not present
      if (!dept.containsKey('cached_at')) {
        dept['cached_at'] = DateTime.now().millisecondsSinceEpoch;
      }
      batch.insert('departments', dept,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    print('[DATABASE] Cached ${departments.length} departments');
  }

  /// Get all cached departments
  Future<List<Map<String, dynamic>>> getAllDepartments() async {
    final db = await database;
    return await db.query('departments', orderBy: 'DEPT_NAME');
  }

  /// Get specific department by code
  Future<Map<String, dynamic>?> getDepartment(String deptCd) async {
    final db = await database;
    final result = await db.query(
      'departments',
      where: 'DEPT_CD = ?',
      whereArgs: [deptCd],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Clear departments cache
  Future<void> clearDepartmentsCache() async {
    final db = await database;
    await db.delete('departments');
    print('[DATABASE] Cleared departments cache');
  }

  /*
  ==============================
  LOCATIONS (Punch-in/out & tracking)
  ==============================
  */

  Future<void> _createLocationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS locations (
        locId INTEGER PRIMARY KEY AUTOINCREMENT,
        USER_CD TEXT,
        VOUCH_DT TEXT NOT NULL,
        VOUCH_TIME TEXT NOT NULL DEFAULT '00:00:00',
        LAT REAL NOT NULL DEFAULT 0.0,
        LONGI REAL NOT NULL DEFAULT 0.0,
        REMARK TEXT NOT NULL DEFAULT '',
        SYNC_ID INTEGER NOT NULL, 
        CREATED_BY TEXT NOT NULL DEFAULT '',
        CREATED_AT INTEGER NOT NULL,
        UPDATED_BY TEXT NOT NULL DEFAULT '',
        UPDATED_AT INTEGER NOT NULL,
        CREATED_APP_TYPE TEXT NOT NULL DEFAULT '',
        MODULE_NO TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createOrderTrackingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_tracking (
        locId INTEGER PRIMARY KEY AUTOINCREMENT,
        oId INTEGER DEFAULT NULL,
        USER_CD TEXT DEFAULT NULL,
        ACC_CD TEXT NOT NULL,
        VOUCH_DT TEXT NOT NULL,
        VOUCH_TIME TEXT NOT NULL DEFAULT '00:00:00',
        LAT REAL NOT NULL DEFAULT 0.0,
        LONGI REAL NOT NULL DEFAULT 0.0,
        REMARK TEXT NOT NULL DEFAULT '',
        SYNC_ID INTEGER NOT NULL,
        CREATED_BY TEXT NOT NULL DEFAULT '',
        CREATED_AT INTEGER NOT NULL,
        UPDATED_BY TEXT NOT NULL DEFAULT '',
        UPDATED_AT INTEGER NOT NULL,
        CREATED_APP_TYPE TEXT NOT NULL DEFAULT '',
        MODULE_NO TEXT NOT NULL DEFAULT '205',
        sync_status TEXT DEFAULT 'pending'
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tracking_order ON order_tracking(SYNC_ID, oId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ordertrack_account ON order_tracking(SYNC_ID, ACC_CD)');
  }

  /// Insert a new location record (punch-in/punch-out)
  Future<int> insertLocation(Map<String, dynamic> locationData) async {
    final db = await database;
    return await db.insert('locations', locationData);
  }

  /// Get all pending location records (not synced)
  Future<List<Map<String, dynamic>>> getPendingLocations() async {
    final db = await database;
    return await db.query('locations', where: "sync_status = 'pending'");
  }

  /// Get locations for a specific user and date
  Future<List<Map<String, dynamic>>> getLocationsByUserAndDate(
      String userCd, String vouchDt) async {
    final db = await database;
    return await db.query(
      'locations',
      where: 'USER_CD = ? AND VOUCH_DT = ?',
      whereArgs: [userCd, vouchDt],
      orderBy: 'VOUCH_TIME',
    );
  }

  /// Get all locations within a date range
  Future<List<Map<String, dynamic>>> getLocationsByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'locations',
      where: 'VOUCH_DT >= ? AND VOUCH_DT <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'VOUCH_DT DESC, VOUCH_TIME DESC',
    );
  }

  /// Update location sync status
  Future<void> updateLocationSyncStatus(
      int locId, String status, int? serverId) async {
    final db = await database;
    await db.update(
      'locations',
      {
        'sync_status': status,
        'UPDATED_AT': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'locId = ?',
      whereArgs: [locId],
    );
  }

  /// Clear all synced locations
  Future<void> clearSyncedLocations() async {
    final db = await database;
    await db.delete('locations', where: "sync_status = 'synced'");
    print('[DATABASE] Cleared synced locations');
  }

  /// Delete a specific location
  Future<void> deleteLocation(int locId) async {
    final db = await database;
    await db.delete('locations', where: 'locId = ?', whereArgs: [locId]);
  }

  /// Insert order tracking record (start/end order)
  Future<int> insertOrderTracking(Map<String, dynamic> trackingData) async {
    final db = await database;
    return await db.insert('order_tracking', trackingData);
  }

  /// Get all pending order tracking records (excluding type=2 order placement which are synced immediately)
  Future<List<Map<String, dynamic>>> getPendingOrderTrackings() async {
    final db = await database;
    return await db.query(
      'order_tracking',
      where:
          "sync_status = 'pending' AND (tracking_type IS NULL OR tracking_type NOT IN ('2', 'order_placed'))",
    );
  }

  /// Update order tracking sync status
  Future<void> updateOrderTrackingStatus(
      int trackingId, String status, String? error) async {
    final db = await database;
    await db.update(
      'order_tracking',
      {'sync_status': status},
      where: 'locId = ?',
      whereArgs: [trackingId],
    );
  }

  /// Delete order tracking record
  Future<void> deleteOrderTracking(int trackingId) async {
    final db = await database;
    await db
        .delete('order_tracking', where: 'locId = ?', whereArgs: [trackingId]);
  }
}
