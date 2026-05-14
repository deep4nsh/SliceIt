import '../models/line_model.dart';
import '../models/split_item_model.dart';
import 'dart:math' as math;

class BillParserService {
  /// Parses the total amount using a weighted scoring system.
  /// This simulates a "trained" model by evaluating multiple features:
  /// 1. Keywords (Total, Amount, etc.)
  /// 2. Vertical Position (Bottom of receipt is more likely)
  /// 3. Horizontal Alignment (Values to the right of keywords)
  /// 4. Negative Keywords (Excluding tax, savings, etc.)
  /// 5. Value Magnitude (Larger values are slightly favored)
  double? parseTotalAmount(List<Line> lines) {
    if (lines.isEmpty) return null;

    // 1. Calculate Page Height (to normalize vertical position scoring)
    double pageHeight = 0;
    for (var line in lines) {
      if (line.boundingBox.bottom > pageHeight) {
        pageHeight = line.boundingBox.bottom;
      }
    }
    if (pageHeight == 0) pageHeight = 1000; // Fallback

    final candidates = <_Candidate>[];
    
    // Regex for currency (handles commas, dots, currency symbols)
    final currencyRegex = RegExp(r'[€£¥₹$]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)');

    // Keywords configuration
    final targetKeywords = ['total', 'amount', 'due', 'payable', 'balance', 'payment', 'net', 'grand'];
    final strongKeywords = ['grant total', 'total amount', 'net payable', 'payment']; // Extra bonus
    final negativeKeywords = ['change', 'tendered', 'savings', 'saved', 'card', 'cash', 'upi', 'visa', 'tax', 'gst', 'vat', 'cgst', 'sgst']; 
    final disqualifiers = ['saved', 'savings']; // Specifically for "You Saved" lines

    // Helper: Extract all valid double values from a line of text
    List<double> extractValues(String text) {
      final matches = currencyRegex.allMatches(text);
      List<double> values = [];
      for (final match in matches) {
        String clean = match.group(1)!.replaceAll(',', '.');
        
        // OCR Cleanup: Handle 1.200.00 vs 1,200.00
        if (clean.indexOf('.') != clean.lastIndexOf('.')) {
          List<String> parts = clean.split('.');
          if (parts.length > 2) {
             String main = parts.take(parts.length - 1).join('');
             String fraction = parts.last;
             clean = '$main.$fraction';
          }
        }
        
        // Remove thousands separators if they are purely dots (1.000) vs decimal (1.00)
        // Heuristic: if 3 digits follow dot and it's not the last dot... handled above.
        
        final val = double.tryParse(clean);
        if (val != null) values.add(val);
      }
      return values;
    }

    // 2. Scan lines and score them
    double maxFoundValue = 0; // For relative value scoring

    // First pass: identify max value and collect initial candidates
    for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final text = line.text.toLowerCase();
        
        // Disqualify specific lines immediately
        if (disqualifiers.any((k) => text.contains(k))) continue;

        final vals = extractValues(line.text);
        if (vals.isNotEmpty) {
           double maxInLine = vals.reduce(math.max);
           if (maxInLine > maxFoundValue) maxFoundValue = maxInLine;
        }
    }

    // Second pass: Score candidates
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text.toLowerCase();
      
      if (disqualifiers.any((k) => text.contains(k))) continue;

      final values = extractValues(line.text);
      if (values.isEmpty && !targetKeywords.any((k) => text.contains(k))) continue;

      // --- Feature 1: Vertical Position (0 to 20 points) ---
      double relativeY = line.boundingBox.center.dy / pageHeight;
      double posScore = relativeY * 20;

      // --- Feature 2: Keyword Presence (Same Line) ---
      bool hasTarget = targetKeywords.any((k) => text.contains(k));
      bool hasStrong = strongKeywords.any((k) => text.contains(k));
      bool hasNegative = negativeKeywords.any((k) => text.contains(k));

      double keywordScore = 0;
      if (hasTarget) keywordScore += 40;
      if (hasStrong) keywordScore += 10;
      if (hasNegative) keywordScore -= 30;

      // Evaluate values ON this line
      for (final val in values) {
         double valScore = 0;
         // --- Feature 3: Value Magnitude (0 to 10 points) ---
         if (maxFoundValue > 0) {
            valScore = (val / maxFoundValue) * 10; 
         }
         
         double totalScore = 10.0 + posScore + keywordScore + valScore;
         candidates.add(_Candidate(val, totalScore, line));
      }

      // --- Feature 4: Alignment (Value to the right of Keyword) ---
      // If this line is a keyword label (e.g. "Total:"), look for values in OTHER lines to the right
      if (hasTarget && !hasNegative) { // Don't look right of "Tax:"
         for (var other in lines) {
            if (other == line) continue;
            
            final otherText = other.text.toLowerCase();
            if (disqualifiers.any((k) => otherText.contains(k))) continue;
            // Also avoid picking up negative keyword lines as the value source if possible, but "Total Tax: 50" -> 50 is valid as tax.
            // But we want Total.
            
            // Check vertical alignment
             final centerY = line.boundingBox.center.dy;
             final otherCenterY = other.boundingBox.center.dy;
             final tolerance = line.boundingBox.height * 0.8;

             if ((otherCenterY - centerY).abs() < tolerance && 
                 other.boundingBox.left > line.boundingBox.left) {
                 
                 final otherValues = extractValues(other.text);
                 for (final val in otherValues) {
                    double valScore = (maxFoundValue > 0) ? (val / maxFoundValue) * 10 : 0;
                    double otherPosScore = (other.boundingBox.center.dy / pageHeight) * 20;
                    
                    // Massive bonus for explicit alignment with a clean keyword
                    double alignScore = 10.0 + otherPosScore + valScore + 60.0; // +60 Alignment Bonus
                    
                    if (hasStrong) alignScore += 10;

                    candidates.add(_Candidate(val, alignScore, other));
                 }
             }
         }
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));
    
    // Return the value with the highest score
    return candidates.first.value;
  }

  /// Parses individual line items from OCR lines using layout heuristics.
  /// Identifies rows containing an item name and price, filtering out summary rows.
  List<SplitItem> parseLineItems(List<Line> lines) {
    final items = <SplitItem>[];
    if (lines.isEmpty) return items;

    final currencyRegex = RegExp(r'[€£¥₹$]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)');
    final disqualifiers = [
      'total', 'subtotal', 'tax', 'gst', 'vat', 'cgst', 'sgst',
      'change', 'tendered', 'saved', 'savings', 'card', 'cash', 'upi', 'visa',
      'mastercard', 'due', 'payable', 'balance', 'payment', 'net', 'grand',
      'welcome', 'thank', 'date', 'time', 'store', 'shop', 'bill', 'invoice'
    ];

    // Helper to extract double value cleanly using OCR cleanup heuristics
    double? extractSinglePrice(String text) {
      final matches = currencyRegex.allMatches(text);
      double? bestValue;
      for (final match in matches) {
        String clean = match.group(1)!.replaceAll(',', '.');
        if (clean.indexOf('.') != clean.lastIndexOf('.')) {
          List<String> parts = clean.split('.');
          if (parts.length > 2) {
            String main = parts.take(parts.length - 1).join('');
            String fraction = parts.last;
            clean = '$main.$fraction';
          }
        }
        final val = double.tryParse(clean);
        // Usually line items have prices greater than 0
        if (val != null && val > 0) {
          bestValue = val;
        }
      }
      return bestValue;
    }

    int idCounter = 1;

    // First, let's track lines that are purely/mostly numeric to avoid treating them as separate item names if they get paired.
    final usedLineIndices = <int>{};

    for (int i = 0; i < lines.length; i++) {
      if (usedLineIndices.contains(i)) continue;
      final line = lines[i];
      final lowerText = line.text.toLowerCase();

      // Skip lines that have disqualifying keywords
      if (disqualifiers.any((kw) => lowerText.contains(kw))) {
        continue;
      }

      // Check if price is on the same line
      final price = extractSinglePrice(line.text);
      if (price != null) {
        // Strip out the price string to get clean item name
        // E.g. "Pizza 450.00" -> "Pizza"
        String cleanName = line.text;
        final matches = currencyRegex.allMatches(line.text);
        if (matches.isNotEmpty) {
          // Remove the last match or all matches
          for (final m in matches) {
            cleanName = cleanName.replaceAll(m.group(0)!, '');
          }
        }
        // Also remove trailing/leading currency symbols and trim
        cleanName = cleanName.replaceAll(RegExp(r'[€£¥₹$]'), '').trim();
        // Remove trailing non-alphanumeric chars if any
        cleanName = cleanName.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9)]+$'), '').trim();

        if (cleanName.isNotEmpty && cleanName.length > 1 && RegExp(r'[a-zA-Z]').hasMatch(cleanName)) {
          items.add(SplitItem(
            id: 'item_${idCounter++}',
            name: cleanName,
            price: price,
            assignedParticipants: [],
          ));
          usedLineIndices.add(i);
          continue;
        }
      }

      // If price wasn't on the same line, look for horizontally aligned line to the right
      // Receipt format: Item Name on left, Price on right
      // Only consider if the current line has letters (is a valid item name)
      String cleanName = line.text.replaceAll(RegExp(r'[€£¥₹$]'), '').trim();
      if (cleanName.isNotEmpty && cleanName.length > 1 && RegExp(r'[a-zA-Z]').hasMatch(cleanName)) {
        final centerY = line.boundingBox.top + line.boundingBox.height / 2;
        
        // Find candidate line to the right
        int? bestRightIndex;
        double? bestRightPrice;
        double minDistance = double.infinity;

        for (int j = 0; j < lines.length; j++) {
          if (i == j || usedLineIndices.contains(j)) continue;
          final rightLine = lines[j];
          final rightCenterY = rightLine.boundingBox.top + rightLine.boundingBox.height / 2;

          // Check if vertically aligned within a tolerance (e.g. 15 pixels)
          if ((centerY - rightCenterY).abs() < 15.0) {
            // Check if it's to the right
            if (rightLine.boundingBox.left > line.boundingBox.left) {
              final rightPrice = extractSinglePrice(rightLine.text);
              if (rightPrice != null) {
                final dist = rightLine.boundingBox.left - line.boundingBox.left;
                if (dist < minDistance) {
                  minDistance = dist;
                  bestRightPrice = rightPrice;
                  bestRightIndex = j;
                }
              }
            }
          }
        }

        if (bestRightPrice != null && bestRightIndex != null) {
          items.add(SplitItem(
            id: 'item_${idCounter++}',
            name: cleanName,
            price: bestRightPrice,
            assignedParticipants: [],
          ));
          usedLineIndices.add(i);
          usedLineIndices.add(bestRightIndex);
        }
      }
    }

    return items;
  }
}

class _Candidate {
  final double value;
  final double score;
  final Line sourceLine;
  _Candidate(this.value, this.score, this.sourceLine);
  
  @override
  String toString() => 'Val: $value, Score: $score, Text: ${sourceLine.text}';
}
