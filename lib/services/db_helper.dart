import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';
import '../models/transaction.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static sql.Database? _database;
  DbHelper._init();

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance.db');
    return _database!;
  }

  Future<sql.Database> _initDB(String filePath) async {
    final dbPath = await sql.getDatabasesPath();
    final path = join(dbPath, filePath);
    return await sql.openDatabase(
      path, 
      version: 4, 
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE transactions ADD COLUMN color INTEGER DEFAULT 4279543167');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budget_settings (
              id INTEGER PRIMARY KEY,
              monthly_budget REAL DEFAULT 0,
              warning_percentage INTEGER DEFAULT 80,
              payment_cycle_day INTEGER DEFAULT 1
            )
          ''');
          await db.insert('budget_settings', {'id': 1, 'monthly_budget': 0, 'warning_percentage': 80, 'payment_cycle_day': 1});
        }
        if (oldVersion == 3) {
          await db.execute('ALTER TABLE budget_settings ADD COLUMN payment_cycle_day INTEGER DEFAULT 1');
        }
      },
    );
  }

  Future _createDB(sql.Database db, int version) async {
    await db.execute('CREATE TABLE transactions (id TEXT PRIMARY KEY, title TEXT, amount REAL, date TEXT, color INTEGER DEFAULT 4279543167)');
    await db.execute('''
      CREATE TABLE budget_settings (
        id INTEGER PRIMARY KEY,
        monthly_budget REAL DEFAULT 0,
        warning_percentage INTEGER DEFAULT 80,
        payment_cycle_day INTEGER DEFAULT 1
      )
    ''');
    await db.insert('budget_settings', {'id': 1, 'monthly_budget': 0, 'warning_percentage': 80, 'payment_cycle_day': 1});
  }

  Future<void> insertTransaction(Transaction t) async {
    final db = await instance.database;
    await db.insert('transactions', t.toMap());
  }

  // Mevcut haftanın günlerini getirir (sadece bu ay içindekiler)
  Future<List<Map<String, dynamic>>> getWeeklySummary() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query('transactions');

    // İşlemleri grupla
    Map<String, List<Transaction>> grouped = {};
    for (var row in result) {
      String date = row['date'];
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(Transaction.fromMap(row));
    }

    // Mevcut haftanın Pazartesi gününü bul
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    List<Map<String, dynamic>> summary = [];
    for (int i = 0; i < 7; i++) {
      DateTime date = monday.add(Duration(days: i));
      
      // Sadece bu aydaki günleri ekle
      if (date.month != now.month || date.year != now.year) {
        continue;
      }
      
      String dateStr = date.toIso8601String().split('T')[0];
      
      List<Transaction> items = grouped[dateStr] ?? [];
      double total = items.fold(0, (sum, item) => sum + item.amount);
      
      summary.add({
        'date': dateStr,
        'total': total,
        'items': items,
      });
    }

    return summary;
  }

  // Belirli bir ayın tüm harcamalarını getirir (Heatmap için)
  Future<Map<int, double>> getMonthlySummary(int year, int month) async {
    final db = await instance.database;
    String monthStr = month < 10 ? '0$month' : '$month';
    String start = '$year-$monthStr-01';
    String end = '$year-$monthStr-31';

    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
    );

    Map<int, double> dayTotals = {};
    for (var row in result) {
      DateTime date = DateTime.parse(row['date']);
      int day = date.day;
      double amount = (row['amount'] as num).toDouble();
      dayTotals[day] = (dayTotals[day] ?? 0) + amount;
    }
    return dayTotals;
  }

  // Tıklanan günün harcamalarını getiren fonksiyon
  Future<List<Transaction>> getTransactionsByDate(String dateStr) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', where: 'date = ?', whereArgs: [dateStr]);
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<int> updateTransaction(Transaction t) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getBudgetSettings() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query('budget_settings', where: 'id = ?', whereArgs: [1]);
    if (result.isEmpty) {
      return {'monthly_budget': 0.0, 'warning_percentage': 80};
    }
    return {
      'monthly_budget': (result[0]['monthly_budget'] as num).toDouble(),
      'warning_percentage': result[0]['warning_percentage'] as int,
    };
  }

  Future<void> updateBudgetSettings(double monthlyBudget, int warningPercentage) async {
    final db = await instance.database;
    await db.update(
      'budget_settings',
      {
        'monthly_budget': monthlyBudget, 
        'warning_percentage': warningPercentage,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  Map<String, DateTime> getCurrentWeekInMonth() {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    DateTime sunday = monday.add(const Duration(days: 6));
    
    DateTime monthStart = DateTime(now.year, now.month, 1);
    DateTime monthEnd = DateTime(now.year, now.month + 1, 0);
    
    DateTime weekStart = monday.isBefore(monthStart) ? monthStart : monday;
    DateTime weekEnd = sunday.isAfter(monthEnd) ? monthEnd : sunday;
    
    return {'start': weekStart, 'end': weekEnd};
  }

  int getDaysInCurrentWeek() {
    final week = getCurrentWeekInMonth();
    return week['end']!.difference(week['start']!).inDays + 1;
  }

  Future<double> getWeeklyTotal() async {
    final db = await instance.database;
    final week = getCurrentWeekInMonth();
    
    String startDate = week['start']!.toIso8601String().split('T')[0];
    String endDate = week['end']!.toIso8601String().split('T')[0];
    
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );
    
    if (result.isNotEmpty && result[0]['total'] != null) {
      return (result[0]['total'] as num).toDouble();
    }
    return 0.0;
  }

  double calculateWeeklyBudget(double monthlyBudget) {
    DateTime now = DateTime.now();
    int daysInMonth = getDaysInMonth(now.year, now.month);
    int daysInWeek = getDaysInCurrentWeek();
    double dailyBudget = monthlyBudget / daysInMonth;
    return dailyBudget * daysInWeek;
  }

  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await instance.database;
    String monthStr = month < 10 ? '0$month' : '$month';
    String start = '$year-$monthStr-01';
    String end = '$year-$monthStr-31';
    
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE date >= ? AND date <= ?',
      [start, end],
    );
    
    if (result.isNotEmpty && result[0]['total'] != null) {
      return (result[0]['total'] as num).toDouble();
    }
    return 0.0;
  }
}