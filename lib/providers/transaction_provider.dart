import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';

class TransactionProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<KakeiboTransaction> _transactions = [];
  List<KakeiboCategory> _expenseCategories = [];
  List<KakeiboCategory> _incomeCategories = [];
  DateTime _selectedDate = DateTime.now();
  
  // ゲッター
  List<KakeiboTransaction> get transactions => _transactions;
  List<KakeiboCategory> get expenseCategories => _expenseCategories;
  List<KakeiboCategory> get incomeCategories => _incomeCategories;
  DateTime get selectedDate => _selectedDate;
  
  int get selectedYear => _selectedDate.year;
  int get selectedMonth => _selectedDate.month;
  
  // 初期化
  Future<void> initialize() async {
    await _loadCategories();
    await loadTransactionsForSelectedMonth();
  }
  
  // カテゴリの読み込み
  Future<void> _loadCategories() async {
    _expenseCategories = await _databaseService.getCategories(isExpense: true);
    _incomeCategories = await _databaseService.getCategories(isExpense: false);
    notifyListeners();
  }
  
  // 選択された月のトランザクションを読み込む
  Future<void> loadTransactionsForSelectedMonth() async {
    _transactions = await _databaseService.getTransactionsByMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    notifyListeners();
  }
  
  // 月を変更する
  void changeMonth(int year, int month) {
    _selectedDate = DateTime(year, month, 1);
    loadTransactionsForSelectedMonth();
  }
  
  // 前の月に移動
  void previousMonth() {
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month - 1,
      1,
    );
    loadTransactionsForSelectedMonth();
  }
  
  // 次の月に移動
  void nextMonth() {
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      1,
    );
    loadTransactionsForSelectedMonth();
  }
  
  // トランザクションの追加
  Future<void> addTransaction(KakeiboTransaction transaction) async {
    await _databaseService.insertTransaction(transaction);
    await loadTransactionsForSelectedMonth();
  }
  
  // トランザクションの更新
  Future<void> updateTransaction(KakeiboTransaction transaction) async {
    await _databaseService.updateTransaction(transaction);
    await loadTransactionsForSelectedMonth();
  }
  
  // トランザクションの削除
  Future<void> deleteTransaction(int id) async {
    await _databaseService.deleteTransaction(id);
    await loadTransactionsForSelectedMonth();
  }
  
  // 月別の集計を取得
  Future<Map<String, double>> getMonthlySummary() async {
    return await _databaseService.getMonthlySummary(
      _selectedDate.year,
      _selectedDate.month,
    );
  }
  
  // カテゴリ別の集計を取得
  Future<List<Map<String, dynamic>>> getCategorySummary({required bool isExpense}) async {
    return await _databaseService.getCategorySummary(
      _selectedDate.year,
      _selectedDate.month,
      isExpense: isExpense,
    );
  }
  
  // カテゴリIDからカテゴリを取得
  Future<KakeiboCategory> getCategoryById(int id) async {
    return await _databaseService.getCategoryById(id);
  }
}
