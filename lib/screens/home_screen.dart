import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import './add_transaction_screen.dart';
import './statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final dateFormat = DateFormat('yyyy年MM月');

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    await provider.initialize();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家計簿アプリ'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatisticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TransactionProvider>(
              builder: (context, provider, child) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await provider.loadTransactionsForSelectedMonth();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMonthSelector(context, provider),
                          const SizedBox(height: 16),
                          _buildMonthlySummary(context, provider),
                          const SizedBox(height: 24),
                          _buildRecentTransactions(context, provider),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, TransactionProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            provider.previousMonth();
          },
        ),
        Text(
          dateFormat.format(provider.selectedDate),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            provider.nextMonth();
          },
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(BuildContext context, TransactionProvider provider) {
    return FutureBuilder<Map<String, double>>(
      future: provider.getMonthlySummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('データがありません'));
        }

        final summary = snapshot.data!;
        final income = summary['income'] ?? 0.0;
        final expense = summary['expense'] ?? 0.0;
        final balance = summary['balance'] ?? 0.0;

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今月の収支',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('収入', income, Colors.green),
                const Divider(),
                _buildSummaryRow('支出', expense, Colors.red),
                const Divider(),
                _buildSummaryRow('残高', balance, balance >= 0 ? Colors.blue : Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, TransactionProvider provider) {
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'まだ取引がありません。\n右下の+ボタンから追加してください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近の取引',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length > 5 ? 5 : transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return FutureBuilder<KakeiboCategory>(
              future: provider.getCategoryById(transaction.categoryId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(
                    title: Text('読み込み中...'),
                  );
                }

                final category = snapshot.data!;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.color,
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(transaction.title),
                  subtitle: Text(
                    DateFormat('yyyy/MM/dd').format(transaction.date),
                  ),
                  trailing: Text(
                    currencyFormat.format(transaction.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: transaction.isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddTransactionScreen(
                          transaction: transaction,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        if (transactions.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: TextButton(
                onPressed: () {
                  // TODO: 全ての取引を表示する画面に遷移
                },
                child: const Text('すべての取引を表示'),
              ),
            ),
          ),
      ],
    );
  }
}
