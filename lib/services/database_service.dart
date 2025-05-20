import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static sqflite.Database? _database;
  static SharedPreferences? _prefs;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<void> _initializeDefaultCategories() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('categories_initialized')) {
        // カテゴリにIDを設定してからJSONとして保存
        final expenseCategories = List<Map<String, dynamic>>.generate(
          DefaultCategories.expenses.length,
          (index) {
            final category = DefaultCategories.expenses[index];
            final map = category.toMap();
            map['id'] = index + 1; // IDを1から始まる連番で設定
            return map;
          }
        );
        
        final incomeCategories = List<Map<String, dynamic>>.generate(
          DefaultCategories.incomes.length,
          (index) {
            final category = DefaultCategories.incomes[index];
            final map = category.toMap();
            map['id'] = expenseCategories.length + index + 1; // 支出カテゴリの後に連番で設定
            return map;
          }
        );
        
        print('初期化された支出カテゴリ: ${expenseCategories.map((c) => '${c['id']}:${c['name']}').join(', ')}');
        print('初期化された収入カテゴリ: ${incomeCategories.map((c) => '${c['id']}:${c['name']}').join(', ')}');
        
        await prefs.setString('expense_categories', jsonEncode(expenseCategories));
        await prefs.setString('income_categories', jsonEncode(incomeCategories));
        await prefs.setBool('categories_initialized', true);
      }
    }
  }

  Future<dynamic> get database async {
    if (kIsWeb) {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
        await _initializeDefaultCategories();
      }
      return _prefs;
    } else {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    }
  }

  Future<sqflite.Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web platform');
    }
    
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'kakeibo.db');
    return await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    // カテゴリテーブルの作成
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        iconCodePoint INTEGER,
        colorValue INTEGER,
        isExpense INTEGER
      )
    ''');

    // トランザクションテーブルの作成
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT,
        categoryId INTEGER,
        note TEXT,
        isExpense INTEGER,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    // デフォルトのカテゴリを追加
    for (var category in DefaultCategories.expenses) {
      await db.insert('categories', category.toMap());
    }
    for (var category in DefaultCategories.incomes) {
      await db.insert('categories', category.toMap());
    }
  }

  // カテゴリの操作
  Future<List<KakeiboCategory>> getCategories({required bool isExpense}) async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final key = isExpense ? 'expense_categories' : 'income_categories';
      final categoriesJson = prefs.getString(key) ?? '[]';
      final List<dynamic> categoriesList = jsonDecode(categoriesJson);
      
      return categoriesList.map((map) => KakeiboCategory.fromMap(map)).toList();
    } else {
      final List<Map<String, dynamic>> maps = await (db as sqflite.Database).query(
        'categories',
        where: 'isExpense = ?',
        whereArgs: [isExpense ? 1 : 0],
      );
      return List.generate(maps.length, (i) {
        return KakeiboCategory.fromMap(maps[i]);
      });
    }
  }

  Future<KakeiboCategory> getCategoryById(int id) async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final expenseCategoriesJson = prefs.getString('expense_categories') ?? '[]';
      final incomeCategoriesJson = prefs.getString('income_categories') ?? '[]';
      
      final List<dynamic> expenseCategories = jsonDecode(expenseCategoriesJson);
      final List<dynamic> incomeCategories = jsonDecode(incomeCategoriesJson);
      
      final allCategories = [...expenseCategories, ...incomeCategories];
      final categoryMap = allCategories.firstWhere(
        (map) => map['id'] == id,
        orElse: () => throw Exception('Category not found'),
      );
      
      return KakeiboCategory.fromMap(categoryMap);
    } else {
      final List<Map<String, dynamic>> maps = await (db as sqflite.Database).query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      return KakeiboCategory.fromMap(maps.first);
    }
  }

  // トランザクションの操作
  Future<int> insertTransaction(KakeiboTransaction transaction) async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      final List<dynamic> transactions = jsonDecode(transactionsJson);
      
      // 新しいIDを生成
      int newId = 1;
      if (transactions.isNotEmpty) {
        newId = transactions.map<int>((t) => t['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
      }
      
      final newTransaction = transaction.copyWith(id: newId).toMap();
      transactions.add(newTransaction);
      
      await prefs.setString('transactions', jsonEncode(transactions));
      return newId;
    } else {
      return await (db as sqflite.Database).insert('transactions', transaction.toMap());
    }
  }

  Future<int> updateTransaction(KakeiboTransaction transaction) async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      List<dynamic> transactions = jsonDecode(transactionsJson);
      
      final index = transactions.indexWhere((t) => t['id'] == transaction.id);
      if (index != -1) {
        transactions[index] = transaction.toMap();
        await prefs.setString('transactions', jsonEncode(transactions));
        return 1;
      }
      return 0;
    } else {
      return await (db as sqflite.Database).update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    }
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      List<dynamic> transactions = jsonDecode(transactionsJson);
      
      final initialLength = transactions.length;
      transactions.removeWhere((t) => t['id'] == id);
      
      if (transactions.length != initialLength) {
        await prefs.setString('transactions', jsonEncode(transactions));
        return 1;
      }
      return 0;
    } else {
      return await (db as sqflite.Database).delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<KakeiboTransaction>> getTransactions() async {
    final db = await database;
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      final List<dynamic> transactions = jsonDecode(transactionsJson);
      
      // 日付でソート
      transactions.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA); // 降順
      });
      
      return transactions.map((map) => KakeiboTransaction.fromMap(map)).toList();
    } else {
      final List<Map<String, dynamic>> maps = await (db as sqflite.Database).query(
        'transactions', 
        orderBy: 'date DESC'
      );
      return List.generate(maps.length, (i) {
        return KakeiboTransaction.fromMap(maps[i]);
      });
    }
  }

  Future<List<KakeiboTransaction>> getTransactionsByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      final List<dynamic> allTransactions = jsonDecode(transactionsJson);
      
      // 指定した月のトランザクションをフィルタリング
      final filteredTransactions = allTransactions.where((t) {
        final date = DateTime.parse(t['date']);
        return date.isAfter(DateTime.parse(startDate).subtract(const Duration(days: 1))) && 
               date.isBefore(DateTime.parse(endDate).add(const Duration(days: 1)));
      }).toList();
      
      // 日付でソート
      filteredTransactions.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA); // 降順
      });
      
      return filteredTransactions.map((map) => KakeiboTransaction.fromMap(map)).toList();
    } else {
      final List<Map<String, dynamic>> maps = await (db as sqflite.Database).query(
        'transactions',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date DESC',
      );
      
      return List.generate(maps.length, (i) {
        return KakeiboTransaction.fromMap(maps[i]);
      });
    }
  }

  // 月別の集計
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      final List<dynamic> allTransactions = jsonDecode(transactionsJson);
      
      // 指定した月のトランザクションをフィルタリング
      final filteredTransactions = allTransactions.where((t) {
        final date = DateTime.parse(t['date']);
        return date.isAfter(DateTime.parse(startDate).subtract(const Duration(days: 1))) && 
               date.isBefore(DateTime.parse(endDate).add(const Duration(days: 1)));
      }).toList();
      
      // 収入と支出を計算
      double incomeTotal = 0.0;
      double expenseTotal = 0.0;
      
      for (var t in filteredTransactions) {
        if (t['isExpense'] == 0) {
          incomeTotal += t['amount'] as double;
        } else {
          expenseTotal += t['amount'] as double;
        }
      }
      
      return {
        'income': incomeTotal,
        'expense': expenseTotal,
        'balance': incomeTotal - expenseTotal,
      };
    } else {
      // 収入の合計
      final incomeResult = await (db as sqflite.Database).rawQuery('''
        SELECT SUM(amount) as total FROM transactions 
        WHERE isExpense = 0 AND date BETWEEN ? AND ?
      ''', [startDate, endDate]);
      
      // 支出の合計
      final expenseResult = await db.rawQuery('''
        SELECT SUM(amount) as total FROM transactions 
        WHERE isExpense = 1 AND date BETWEEN ? AND ?
      ''', [startDate, endDate]);
      
      final incomeTotal = incomeResult.first['total'] as double? ?? 0.0;
      final expenseTotal = expenseResult.first['total'] as double? ?? 0.0;
      
      return {
        'income': incomeTotal,
        'expense': expenseTotal,
        'balance': incomeTotal - expenseTotal,
      };
    }
  }

  // カテゴリ別の集計
  Future<List<Map<String, dynamic>>> getCategorySummary(int year, int month, {required bool isExpense}) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0).toIso8601String();
    
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final transactionsJson = prefs.getString('transactions') ?? '[]';
      final List<dynamic> allTransactions = jsonDecode(transactionsJson);
      
      // 指定した月のトランザクションをフィルタリング
      final filteredTransactions = allTransactions.where((t) {
        final date = DateTime.parse(t['date']);
        return date.isAfter(DateTime.parse(startDate).subtract(const Duration(days: 1))) && 
               date.isBefore(DateTime.parse(endDate).add(const Duration(days: 1))) &&
               t['isExpense'] == (isExpense ? 1 : 0);
      }).toList();
      
      // カテゴリごとに集計
      final Map<int, double> categorySums = {};
      for (var t in filteredTransactions) {
        final categoryId = t['categoryId'] as int;
        final amount = t['amount'] as double;
        categorySums[categoryId] = (categorySums[categoryId] ?? 0.0) + amount;
      }
      
      // カテゴリ情報を取得
      final List<Map<String, dynamic>> result = [];
      for (var entry in categorySums.entries) {
        final categoryId = entry.key;
        final total = entry.value;
        
        // カテゴリ情報を取得
        final category = await getCategoryById(categoryId);
        result.add({
          'id': category.id,
          'name': category.name,
          'iconCodePoint': category.icon.codePoint,
          'colorValue': category.color.value,
          'total': total,
        });
      }
      
      // 合計金額で降順ソート
      result.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      
      return result;
    } else {
      final List<Map<String, dynamic>> result = await (db as sqflite.Database).rawQuery('''
        SELECT c.id, c.name, c.iconCodePoint, c.colorValue, SUM(t.amount) as total
        FROM transactions t
        JOIN categories c ON t.categoryId = c.id
        WHERE t.isExpense = ? AND t.date BETWEEN ? AND ?
        GROUP BY t.categoryId
        ORDER BY total DESC
      ''', [isExpense ? 1 : 0, startDate, endDate]);
      
      return result;
    }
  }
}
