class KakeiboTransaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final int categoryId;
  final String? note;
  final bool isExpense;

  KakeiboTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.note,
    required this.isExpense,
  });


  // データベースから読み込む用のファクトリコンストラクタ
  factory KakeiboTransaction.fromMap(Map<String, dynamic> map) {
    return KakeiboTransaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      categoryId: map['categoryId'],
      note: map['note'],
      isExpense: map['isExpense'] == 1,
    );
  }

  // データベースに保存する用のメソッド
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'categoryId': categoryId,
      'note': note,
      'isExpense': isExpense ? 1 : 0,
    };
  }

  // コピーを作成するメソッド
  KakeiboTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    int? categoryId,
    String? note,
    bool? isExpense,
  }) {
    return KakeiboTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      isExpense: isExpense ?? this.isExpense,
    );
  }
}
