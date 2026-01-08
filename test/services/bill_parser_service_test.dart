import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliceit/models/line_model.dart';
import 'package:sliceit/services/bill_parser_service.dart';

void main() {
  group('BillParserService', () {
    final parser = BillParserService();

    test('returns null for empty lines', () {
      expect(parser.parseTotalAmount([]), isNull);
    });

    test('extracts amount from single line with keyword', () {
      final lines = [
        Line('Total: 50.00', const Rect.fromLTWH(0, 0, 100, 20)),
      ];
      expect(parser.parseTotalAmount(lines), 50.0);
    });

    test('extracts amount from separate lines (keyword left, amount right)', () {
      final lines = [
        Line('Total', const Rect.fromLTWH(10, 100, 50, 20)),
        Line('123.45', const Rect.fromLTWH(100, 100, 60, 20)), // Same Y, to the right
      ];
      expect(parser.parseTotalAmount(lines), 123.45);
    });

    test('handling currency symbols', () {
      final lines = [
        Line('Total Amount', const Rect.fromLTWH(10, 100, 100, 20)),
        Line('₹ 1,234.50', const Rect.fromLTWH(150, 100, 100, 20)),
      ];
      expect(parser.parseTotalAmount(lines), 1234.50);
    });

    test('chooses largest amount among candidates if multiple valid options', () {
      // Scenario: Subtotal vs Total
      final lines = [
        Line('Subtotal 100.00', const Rect.fromLTWH(10, 50, 200, 20)),
        Line('Tax 10.00', const Rect.fromLTWH(10, 80, 200, 20)),
        Line('Total 110.00', const Rect.fromLTWH(10, 110, 200, 20)),
      ];
      // Note: My current simple logic just returns the last best match or specifically looks for "total".
      // The implementation iterates all lines. "Total 110.00" will be processed. 
      // "Subtotal 100.00" will also be processed.
      // If "Total" is a keyword, it sets bestAmount.
      // Ideally it should pick 110.00.
      expect(parser.parseTotalAmount(lines), 110.00);
    });

    test('fallback to largest number if no keywords found', () {
      final lines = [
        Line('Burger 10.00', const Rect.fromLTWH(0, 0, 100, 20)),
        Line('Fries 5.00', const Rect.fromLTWH(0, 30, 100, 20)),
        Line('25.50', const Rect.fromLTWH(0, 60, 100, 20)), // Total but no label
      ];
      expect(parser.parseTotalAmount(lines), 25.50);
    });
  });
}
