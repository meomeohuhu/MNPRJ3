import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/services/receipt_parser_service.dart';

void main() {
  final parser = ReceiptParserService();

  test('parses Vietnamese grouped amount and date', () {
    final result =
        parser.parse('WINMART\nNgày: 08/10/2026\nTỔNG THANH TOÁN: 150.000đ');
    expect(result.totalAmount, 150000);
    expect(result.transactionDate, DateTime(2026, 10, 8));
  });

  test('parses comma VND and prefers payment total over product lines', () {
    final result = parser.parse(
        'COOPMART\nSỮA 150,000 VND\nGIẢM GIÁ -10,000\nTOTAL 140,000 VND\nTIỀN THỪA 60,000');
    expect(result.totalAmount, 140000);
  });

  test('does not choose change or VAT as total when payment keyword exists',
      () {
    final result = parser.parse(
        'MINI MART\nVAT 8% 12.000đ\nAMOUNT DUE 162.000 VNĐ\nTIỀN THỪA 38.000đ');
    expect(result.totalAmount, 162000);
  });

  test('returns uncertainty for empty text and missing date', () {
    final empty = parser.parse('');
    expect(empty.totalAmount, isNull);
    expect(empty.uncertainFields, contains('totalAmount'));
    final missingDate = parser.parse('Cửa hàng tiện lợi\nTỔNG CỘNG 85 000 VNĐ');
    expect(missingDate.totalAmount, 85000);
    expect(missingDate.transactionDate, isNull);
    expect(missingDate.uncertainFields, contains('transactionDate'));
  });

  test('does not accept an invalid future date', () {
    final result = parser.parse('SHOP\n31/02/2025\nTỔNG 150000đ');
    expect(result.transactionDate, isNull);
  });

  test('parses payment receipt with standalone total label and time', () {
    final result = parser.parse(
        'SPA NA XINH\nNGÀY GIỜ: 28/02/2026 18:05:54\nTỔNG: VND 1,300,000');
    expect(result.merchantName, 'SPA NA XINH');
    expect(result.transactionDate, DateTime(2026, 2, 28));
    expect(result.totalAmount, 1300000);
  });

  test('prefers total amount over quantity on retail bill', () {
    final result = parser.parse(
        'SIÊU THỊ MINH LOAN\nTỔNG SỐ LƯỢNG: 5,81\nTỔNG TIỀN HÀNG: 188,350\nTỔNG TIỀN (VND): 188,350');
    expect(result.totalAmount, 188350);
  });

  test('parses small restaurant bill with total cộng', () {
    final result = parser.parse('QUÁN KHÓI\nNgày: 13.04.24\nTổng cộng 180,000');
    expect(result.merchantName, 'QUAN KHOI');
    expect(result.transactionDate, DateTime(2024, 4, 13));
    expect(result.totalAmount, 180000);
  });

  test('parses amount when OCR separates total label and currency', () {
    final result = parser.parse(
        'SPA NA XINH\nTỔNG:\nVND1,300,000\nNGÀY GIỜ: 28/02/2026 18:05:54');
    expect(result.totalAmount, 1300000);
    expect(result.transactionDate, DateTime(2026, 2, 28));
  });

  test('shows a low-confidence fallback amount instead of leaving it blank',
      () {
    final result = parser.parse('CỬA HÀNG\nSỮA 25.000\nBÁNH 15.000\n180.000');
    expect(result.totalAmount, 180000);
    expect(result.uncertainFields, contains('totalAmount'));
  });
}
