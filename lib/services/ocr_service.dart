import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class OcrService {
  final textRecognizer = TextRecognizer();

  // カメラ権限のリクエスト
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  // 画像ライブラリ権限のリクエスト
  Future<bool> requestGalleryPermission() async {
    final status = await Permission.photos.request();
    return status == PermissionStatus.granted;
  }

  // カメラで撮影した画像からテキストを認識
  Future<String?> scanImageFromCamera() async {
    if (!await requestCameraPermission()) {
      return null;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      return null;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) {
      return null;
    }

    return await _processImage(File(pickedFile.path));
  }

  // ギャラリーから選択した画像からテキストを認識
  Future<String?> scanImageFromGallery() async {
    if (!await requestGalleryPermission()) {
      return null;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return null;
    }

    return await _processImage(File(pickedFile.path));
  }

  // 画像からテキストを認識する処理
  Future<String?> _processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR処理エラー: $e');
      return null;
    }
  }

  // レシートテキストから取引情報を抽出
  KakeiboTransaction? extractTransactionFromReceipt(
    String receiptText,
    List<KakeiboCategory> categories,
  ) {
    // 日付の抽出（YYYY/MM/DD、YYYY-MM-DD、YYYY年MM月DD日などの形式に対応）
    final datePattern = RegExp(r'(\d{4}[年/.-]\d{1,2}[月/.-]\d{1,2}日?)');
    final dateMatch = datePattern.firstMatch(receiptText);
    DateTime? date;

    if (dateMatch != null) {
      final dateStr = dateMatch.group(0)!;
      try {
        // 日付文字列をDateTime型に変換
        if (dateStr.contains('年')) {
          // 日本語形式の日付（例：2023年5月21日）
          final parts = dateStr
              .replaceAll('年', '/')
              .replaceAll('月', '/')
              .replaceAll('日', '')
              .split('/');
          date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          // スラッシュやハイフン区切りの日付
          final cleanDateStr = dateStr.replaceAll(RegExp(r'[^0-9/.-]'), '');
          final parts = cleanDateStr.split(RegExp(r'[/.-]'));
          date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (e) {
        debugPrint('日付の解析エラー: $e');
        date = DateTime.now(); // エラー時は現在の日付を使用
      }
    } else {
      date = DateTime.now(); // 日付が見つからない場合は現在の日付を使用
    }

    // 金額の抽出（¥マークや,を含む数値、または合計/小計の後の数値）
    final amountPattern = RegExp(
      r'(合計|小計|総額|金額)[\s:：]*¥?(\d{1,3}(,\d{3})*|\d+)',
    );
    final simpleAmountPattern = RegExp(r'¥(\d{1,3}(,\d{3})*|\d+)');

    double? amount;
    final amountMatch = amountPattern.firstMatch(receiptText);
    final simpleAmountMatch = simpleAmountPattern.firstMatch(receiptText);

    if (amountMatch != null) {
      final amountStr = amountMatch.group(2)!.replaceAll(',', '');
      amount = double.tryParse(amountStr);
    } else if (simpleAmountMatch != null) {
      final amountStr = simpleAmountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(amountStr);
    }

    if (amount == null) {
      // 金額が見つからない場合は処理を中止
      return null;
    }

    // 店舗名/タイトルの抽出（レシートの最初の数行から推測）
    final lines = receiptText.split('\n');
    String title = '';

    if (lines.isNotEmpty) {
      // 最初の非空行を店舗名として使用
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty &&
            !trimmedLine.contains(
              RegExp(r'\d{4}[年/.-]\d{1,2}[月/.-]\d{1,2}'),
            ) && // 日付行を除外
            !trimmedLine.contains(RegExp(r'(合計|小計|総額|金額)'))) {
          // 金額行を除外
          title = trimmedLine;
          break;
        }
      }
    }

    if (title.isEmpty) {
      title = '支出'; // デフォルトタイトル
    }

    // カテゴリの推測（レシートの内容から適切なカテゴリを推測）
    int? categoryId;

    // 支出カテゴリのみをフィルタリング
    final expenseCategories = categories.where((c) => c.isExpense).toList();

    // キーワードとカテゴリのマッピング
    final categoryKeywords = {
      '食費': [
        'スーパー',
        'マート',
        'ストア',
        '食品',
        'フード',
        'レストラン',
        '食堂',
        '弁当',
        'コンビニ',
        'セブン',
        'ファミリー',
        'ローソン',
      ],
      '交通費': [
        '交通',
        '電車',
        'バス',
        'タクシー',
        '駅',
        '切符',
        'チケット',
        'ガソリン',
        '燃料',
        '高速',
        '駐車',
      ],
      '住居費': ['家賃', '住宅', 'マンション', 'アパート', '不動産', '管理費', '修繕'],
      '光熱費': ['電気', 'ガス', '水道', '光熱'],
      '通信費': ['通信', '電話', 'モバイル', 'インターネット', 'Wi-Fi', 'ワイファイ'],
      '娯楽費': ['映画', 'シネマ', '劇場', 'カラオケ', 'ゲーム', '遊園地', '旅行', 'ホテル', '宿泊'],
      '医療費': ['病院', '医院', '薬局', 'ドラッグ', '薬', '医療'],
      '教育費': ['学校', '塾', '習い事', '書籍', '本', '教材'],
      '衣服費': ['衣料', '洋服', 'アパレル', 'ファッション', '靴', 'シューズ'],
    };

    // レシートテキストからカテゴリを推測
    for (final category in expenseCategories) {
      final keywords = categoryKeywords[category.name];
      if (keywords != null) {
        for (final keyword in keywords) {
          if (receiptText.toLowerCase().contains(keyword.toLowerCase())) {
            categoryId = category.id;
            break;
          }
        }
        if (categoryId != null) break;
      }
    }

    // カテゴリが推測できない場合はデフォルトの「その他」カテゴリを使用
    if (categoryId == null && expenseCategories.isNotEmpty) {
      final otherCategory = expenseCategories.firstWhere(
        (c) => c.name == 'その他',
        orElse: () => expenseCategories.first,
      );
      categoryId = otherCategory.id;
    }

    // メモの作成（レシートの主要な項目をメモとして使用）
    final memoLines = <String>[];
    bool isItemSection = false;

    for (final line in lines) {
      final trimmedLine = line.trim();

      // 商品名と価格のパターンを検出
      if (trimmedLine.contains(RegExp(r'\d+円')) ||
          trimmedLine.contains(RegExp(r'¥\d+'))) {
        isItemSection = true;
        memoLines.add(trimmedLine);
      } else if (isItemSection &&
          trimmedLine.isNotEmpty &&
          !trimmedLine.contains('合計') &&
          !trimmedLine.contains('小計') &&
          memoLines.length < 5) {
        // メモは最大5行まで
        memoLines.add(trimmedLine);
      }
    }

    final memo = memoLines.join('\n');

    // 取引オブジェクトの作成
    return KakeiboTransaction(
      title: title,
      amount: amount,
      date: date,
      categoryId: categoryId ?? 0,
      note: memo,
      isExpense: true, // レシートは常に支出として扱う
    );
  }

  // リソースの解放
  void dispose() {
    textRecognizer.close();
  }
}
