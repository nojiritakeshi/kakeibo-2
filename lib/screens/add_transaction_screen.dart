import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'receipt_scanner_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final KakeiboTransaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isExpense = true;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    // 編集モードの場合、既存のデータを設定
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _noteController.text = widget.transaction!.note ?? '';
      _selectedDate = widget.transaction!.date;
      _isExpense = widget.transaction!.isExpense;
      _selectedCategoryId = widget.transaction!.categoryId;
    }

    // 初期カテゴリ選択のために遅延実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultCategory();
    });
  }

  // 初期カテゴリ選択
  void _initializeDefaultCategory() {
    if (_selectedCategoryId == null) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final categories =
          _isExpense ? provider.expenseCategories : provider.incomeCategories;
      if (categories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = categories.first.id;
          print('初期カテゴリを選択しました: $_selectedCategoryId');
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? '新規取引の追加' : '取引の編集'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // レシートスキャンボタンを追加
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'レシートをスキャン',
            onPressed: _scanReceipt,
          ),
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _buildCategorySelector(provider),
                  const SizedBox(height: 16),
                  _buildDatePicker(context),
                  const SizedBox(height: 16),
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildAmountField(),
                  const SizedBox(height: 16),
                  _buildNoteField(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('支出'),
                selected: _isExpense,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isExpense = true;
                      _selectedCategoryId = null;
                    });
                    // 収支タイプ変更後に適切なカテゴリを選択
                    Future.microtask(() => _initializeDefaultCategory());
                  }
                },
                selectedColor: Colors.red.shade200,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('収入'),
                selected: !_isExpense,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isExpense = false;
                      _selectedCategoryId = null;
                    });
                    // 収支タイプ変更後に適切なカテゴリを選択
                    Future.microtask(() => _initializeDefaultCategory());
                  }
                },
                selectedColor: Colors.green.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(TransactionProvider provider) {
    final categories =
        _isExpense ? provider.expenseCategories : provider.incomeCategories;

    // カテゴリが空の場合
    if (categories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('カテゴリがありません')),
        ),
      );
    }

    // デバッグ情報
    print('現在選択されているカテゴリID: $_selectedCategoryId');
    print(
      '利用可能なカテゴリ: ${categories.map((c) => '${c.id}:${c.name}').join(', ')}',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'カテゴリ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedCategoryId == null ? '未選択' : '選択済み',
                  style: TextStyle(
                    color:
                        _selectedCategoryId == null ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  categories.map((category) {
                    final isSelected = _selectedCategoryId == category.id;
                    return ChoiceChip(
                      label: Text(
                        category.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        print(
                          'カテゴリ選択: ${category.name}, ID: ${category.id}, 選択: $selected',
                        );
                        setState(() {
                          // 選択されたら、そのカテゴリIDを設定。選択解除されたら、nullに設定。
                          _selectedCategoryId = selected ? category.id : null;
                        });
                      },
                      avatar: CircleAvatar(
                        backgroundColor:
                            isSelected ? Colors.white : category.color,
                        child: Icon(
                          category.icon,
                          color: isSelected ? category.color : Colors.white,
                          size: 16,
                        ),
                      ),
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: category.color,
                      // 選択状態を強調
                      elevation: isSelected ? 6 : 0,
                      shadowColor: isSelected ? category.color : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('日付'),
        subtitle: Text(
          DateFormat('yyyy年MM月dd日').format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            setState(() {
              _selectedDate = pickedDate;
            });
          }
        },
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: '内容',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '内容を入力してください';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: '金額',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.attach_money),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '金額を入力してください';
        }
        if (double.tryParse(value) == null) {
          return '有効な数値を入力してください';
        }
        return null;
      },
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'メモ（任意）',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
      ),
      maxLines: 3,
    );
  }

  Widget _buildSubmitButton(TransactionProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            if (_selectedCategoryId == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('カテゴリを選択してください')));
              return;
            }
            _saveTransaction(provider);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: Text(
          widget.transaction == null ? '追加' : '更新',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _saveTransaction(TransactionProvider provider) async {
    final title = _titleController.text;
    final amount = double.parse(_amountController.text);
    final note = _noteController.text.isEmpty ? null : _noteController.text;

    // カテゴリが選択されていない場合の処理
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('カテゴリを選択してください')));
      return;
    }

    print(
      '保存するトランザクション: タイトル=$title, 金額=$amount, カテゴリID=$_selectedCategoryId, 支出=${_isExpense ? "はい" : "いいえ"}',
    );

    final transaction = KakeiboTransaction(
      id: widget.transaction?.id,
      title: title,
      amount: amount,
      date: _selectedDate,
      categoryId: _selectedCategoryId!,
      note: note,
      isExpense: _isExpense,
    );

    if (widget.transaction == null) {
      await provider.addTransaction(transaction);
    } else {
      await provider.updateTransaction(transaction);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // レシートスキャン機能
  Future<void> _scanReceipt() async {
    final result = await Navigator.push<KakeiboTransaction>(
      context,
      MaterialPageRoute(builder: (context) => const ReceiptScannerScreen()),
    );

    if (result != null) {
      setState(() {
        _titleController.text = result.title;
        _amountController.text = result.amount.toString();
        if (result.note != null) {
          _noteController.text = result.note!;
        }
        _selectedDate = result.date;
        _isExpense = result.isExpense;
        _selectedCategoryId = result.categoryId;
      });

      // スナックバーでフィードバックを表示
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('レシートから情報を取得しました')));
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('取引の削除'),
          content: const Text('この取引を削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final provider = Provider.of<TransactionProvider>(
                  context,
                  listen: false,
                );
                provider.deleteTransaction(widget.transaction!.id!);
                Navigator.pop(context); // ダイアログを閉じる
                Navigator.pop(context); // 画面を閉じる
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
