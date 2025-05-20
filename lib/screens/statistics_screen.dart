import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  final dateFormat = DateFormat('yyyy年MM月');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '収入'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildMonthSelector(context, provider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpenseTab(provider),
                    _buildIncomeTab(provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, TransactionProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
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
      ),
    );
  }

  Widget _buildExpenseTab(TransactionProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getCategorySummary(isExpense: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('この月の支出データはありません'));
        }

        final categorySummary = snapshot.data!;
        double totalExpense = 0;
        for (var item in categorySummary) {
          totalExpense += item['total'] as double;
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今月の支出合計: ${currencyFormat.format(totalExpense)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(categorySummary, totalExpense),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'カテゴリ別支出',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCategoryList(categorySummary, totalExpense),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncomeTab(TransactionProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getCategorySummary(isExpense: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('この月の収入データはありません'));
        }

        final categorySummary = snapshot.data!;
        double totalIncome = 0;
        for (var item in categorySummary) {
          totalIncome += item['total'] as double;
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今月の収入合計: ${currencyFormat.format(totalIncome)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(categorySummary, totalIncome),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'カテゴリ別収入',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCategoryList(categorySummary, totalIncome),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      List<Map<String, dynamic>> categorySummary, double total) {
    return categorySummary.map((item) {
      final double amount = item['total'] as double;
      final double percentage = (amount / total) * 100;
      final Color color = Color(item['colorValue'] as int);
      
      return PieChartSectionData(
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> categorySummary, double total) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categorySummary.length,
      itemBuilder: (context, index) {
        final item = categorySummary[index];
        final double amount = item['total'] as double;
        final double percentage = (amount / total) * 100;
        final Color color = Color(item['colorValue'] as int);
        final IconData icon = IconData(
          item['iconCodePoint'] as int,
          fontFamily: 'MaterialIcons',
        );
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(item['name'] as String),
          subtitle: Text('${percentage.toStringAsFixed(1)}%'),
          trailing: Text(
            currencyFormat.format(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
