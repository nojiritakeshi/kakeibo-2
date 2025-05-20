import 'package:flutter/material.dart';

class KakeiboCategory {
  final int? id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isExpense;

  KakeiboCategory({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isExpense,
  });

  // データベースから読み込む用のファクトリコンストラクタ
  factory KakeiboCategory.fromMap(Map<String, dynamic> map) {
    return KakeiboCategory(
      id: map['id'],
      name: map['name'],
      icon: IconData(map['iconCodePoint'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      isExpense: map['isExpense'] == 1,
    );
  }

  // データベースに保存する用のメソッド
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
      'isExpense': isExpense ? 1 : 0,
    };
  }
}

// デフォルトのカテゴリリスト
class DefaultCategories {
  // 支出カテゴリ
  static List<KakeiboCategory> expenses = [
    KakeiboCategory(
      name: '食費',
      icon: Icons.restaurant,
      color: Colors.red,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '交通費',
      icon: Icons.directions_bus,
      color: Colors.blue,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '住居費',
      icon: Icons.home,
      color: Colors.brown,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '光熱費',
      icon: Icons.lightbulb,
      color: Colors.yellow.shade800,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '通信費',
      icon: Icons.phone,
      color: Colors.green,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '娯楽費',
      icon: Icons.movie,
      color: Colors.purple,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '医療費',
      icon: Icons.local_hospital,
      color: Colors.pink,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '教育費',
      icon: Icons.school,
      color: Colors.indigo,
      isExpense: true,
    ),
    KakeiboCategory(
      name: '衣服費',
      icon: Icons.shopping_bag,
      color: Colors.teal,
      isExpense: true,
    ),
    KakeiboCategory(
      name: 'その他',
      icon: Icons.more_horiz,
      color: Colors.grey,
      isExpense: true,
    ),
  ];

  // 収入カテゴリ
  static List<KakeiboCategory> incomes = [
    KakeiboCategory(
      name: '給料',
      icon: Icons.work,
      color: Colors.green,
      isExpense: false,
    ),
    KakeiboCategory(
      name: 'ボーナス',
      icon: Icons.card_giftcard,
      color: Colors.amber,
      isExpense: false,
    ),
    KakeiboCategory(
      name: '副業',
      icon: Icons.business_center,
      color: Colors.blue,
      isExpense: false,
    ),
    KakeiboCategory(
      name: '投資',
      icon: Icons.trending_up,
      color: Colors.purple,
      isExpense: false,
    ),
    KakeiboCategory(
      name: 'その他',
      icon: Icons.more_horiz,
      color: Colors.grey,
      isExpense: false,
    ),
  ];
}
