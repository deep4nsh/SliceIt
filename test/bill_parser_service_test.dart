import 'package:flutter_test/flutter_test.dart';
import 'package:sliceit/models/line_model.dart';
import 'package:sliceit/services/bill_parser_service.dart';
import 'dart:ui';

void main() {
  group('BillParserService OCR Parsing Tests', () {
    late BillParserService parser;

    setUp(() {
      parser = BillParserService();
    });

    test('Parses total amount on the same line with strong keywords', () {
      final lines = [
        Line('Store Name', const Rect.fromLTWH(10, 10, 100, 20)),
        Line('Item 1 ₹500.00', const Rect.fromLTWH(10, 50, 150, 20)),
        Line('Item 2 ₹300.00', const Rect.fromLTWH(10, 80, 150, 20)),
        Line('Total Amount ₹800.00', const Rect.fromLTWH(10, 120, 200, 20)),
        Line('Thank you!', const Rect.fromLTWH(10, 160, 100, 20)),
      ];

      final result = parser.parseTotalAmount(lines);
      expect(result, 800.00);
    });

    test('Parses total amount aligned horizontally on a separate line', () {
      final lines = [
        Line('Subtotal', const Rect.fromLTWH(10, 100, 80, 20)),
        Line('1000.00', const Rect.fromLTWH(200, 100, 80, 20)),
        Line('Tax', const Rect.fromLTWH(10, 130, 50, 20)),
        Line('50.00', const Rect.fromLTWH(200, 130, 50, 20)),
        // "Total" keyword on left, value on right at similar Y position
        Line('Total', const Rect.fromLTWH(10, 160, 60, 20)),
        Line('1050.00', const Rect.fromLTWH(200, 160, 80, 20)),
      ];

      final result = parser.parseTotalAmount(lines);
      expect(result, 1050.00);
    });

    test('Handles OCR cleanup formats like 1.200.00', () {
      final lines = [
        Line('Total Payable 1.200.00', const Rect.fromLTWH(10, 200, 200, 20)),
      ];

      final result = parser.parseTotalAmount(lines);
      expect(result, 1200.00);
    });

    test('Ignores negative keywords/disqualifiers like savings or cash tendered', () {
      final lines = [
        Line('Total Amount 500.00', const Rect.fromLTWH(10, 100, 200, 20)),
        Line('Cash Tendered 1000.00', const Rect.fromLTWH(10, 130, 200, 20)),
        Line('You Saved 50.00', const Rect.fromLTWH(10, 160, 200, 20)),
      ];

      final result = parser.parseTotalAmount(lines);
      expect(result, 500.00);
    });

    test('Returns null when no lines or no valid values are present', () {
      expect(parser.parseTotalAmount([]), isNull);
      expect(parser.parseTotalAmount([Line('Welcome', const Rect.fromLTWH(0, 0, 10, 10))]), isNull);
    });

    test('Parses line items containing name and price on the same line', () {
      final lines = [
        Line('Store Name', const Rect.fromLTWH(10, 10, 100, 20)),
        Line('Veggie Pizza ₹450.00', const Rect.fromLTWH(10, 50, 150, 20)),
        Line('Garlic Bread ₹150.00', const Rect.fromLTWH(10, 80, 150, 20)),
        Line('Total Amount ₹600.00', const Rect.fromLTWH(10, 120, 200, 20)),
      ];

      final items = parser.parseLineItems(lines);
      expect(items.length, 2);
      expect(items[0].name, 'Veggie Pizza');
      expect(items[0].price, 450.00);
      expect(items[1].name, 'Garlic Bread');
      expect(items[1].price, 150.00);
    });

    test('Parses line items aligned horizontally on separate lines', () {
      final lines = [
        Line('Pasta Tartufata', const Rect.fromLTWH(10, 100, 120, 20)),
        Line('550.00', const Rect.fromLTWH(200, 102, 60, 20)), // Similar Y position
        Line('Subtotal', const Rect.fromLTWH(10, 140, 80, 20)),
        Line('550.00', const Rect.fromLTWH(200, 140, 60, 20)),
      ];

      final items = parser.parseLineItems(lines);
      expect(items.length, 1);
      expect(items[0].name, 'Pasta Tartufata');
      expect(items[0].price, 550.00);
    });
  });
}
