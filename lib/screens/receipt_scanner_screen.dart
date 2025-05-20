import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ocr_service.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // カメラでスキャン
  Future<void> _scanWithCamera() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final receiptText = await _ocrService.scanImageFromCamera();
      if (receiptText != null && receiptText.isNotEmpty) {
        _processReceiptText(receiptText);
      } else {
        _showErrorSnackBar('レシートのテキストを認識できませんでした。');
      }
    } catch (e) {
      _showErrorSnackBar('エラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ギャラリーから選択
  Future<void> _scanFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final receiptText = await _ocrService.scanImageFromGallery();
      if (receiptText != null && receiptText.isNotEmpty) {
        _processReceiptText(receiptText);
      } else {
        _showErrorSnackBar('レシートのテキストを認識できませんでした。');
      }
    } catch (e) {
      _showErrorSnackBar('エラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // レシートテキストの処理
  void _processReceiptText(String receiptText) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final categories = provider.expenseCategories;

    final transaction = _ocrService.extractTransactionFromReceipt(
      receiptText,
      categories,
    );

    if (transaction != null) {
      // 取引データを前の画面に返す
      Navigator.pop(context, transaction);
    } else {
      _showErrorSnackBar('レシートから情報を抽出できませんでした。');
    }
  }

  // エラーメッセージの表示
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レシートスキャン'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child:
            _isProcessing
                ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('レシートを処理中...'),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 100,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'レシートをスキャンして取引情報を自動入力',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('カメラでスキャン'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _scanWithCamera,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('ギャラリーから選択'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _scanFromGallery,
                    ),
                  ],
                ),
      ),
    );
  }
}
