import 'dart:ui';
import '../models/line_model.dart';
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
}

class _Candidate {
  final double value;
  final double score;
  final Line sourceLine;
  _Candidate(this.value, this.score, this.sourceLine);
  
  @override
  String toString() => 'Val: $value, Score: $score, Text: ${sourceLine.text}';
}
