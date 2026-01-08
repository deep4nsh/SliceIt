import 'dart:ui';
import '../models/line_model.dart';

class BillParserService {
  /// Parses the total amount from a list of recognized text lines.
  /// Uses keyword matching and spatial proximity.
  double? parseTotalAmount(List<Line> lines) {
    if (lines.isEmpty) return null;

    final keywords = ['total', 'amount', 'due', 'payable', 'balance'];
    final currencyRegex = RegExp(r'[$€£¥₹]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)');

    double? bestAmount;
    double maxConfidence = 0.0;

    // Helper to clean and parse amount string
    double? parseAmount(String text) {
      final match = currencyRegex.firstMatch(text);
      if (match != null) {
        String clean = match.group(1)!.replaceAll(',', '.');
        // Handle cases like 1.200,00 -> 1200.00 if needed, but for now standardizing on dot decimal
        // If there are multiple dots, remove all but last
        if (clean.indexOf('.') != clean.lastIndexOf('.')) {
          clean = clean.replaceAll('.', '');
          // Re-insert dot at 2 decimals if it looks like cents, otherwise...
          // For simplicity in this iteration, let's assume standard float format
        }
        return double.tryParse(clean);
      }
      return null;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text.toLowerCase();

      // Check if line contains a keyword
      bool hasKeyword = keywords.any((k) => text.contains(k));

      if (hasKeyword) {
        // STRATEGY 1: Amount on the same line
        double? amount = parseAmount(line.text);
        if (amount != null) {
          // If we found both keyword and amount on same line, it's a strong candidate
          if (amount > maxConfidence) { // simplistic 'confidence' based on amount value? No.
             // Heuristic: "Total: 50.00" is better than just "50.00"
             // Let's just store this for now.
             bestAmount = amount; 
             // We can return early? Maybe not, "Subtotal: 40" vs "Total: 50".
             // Usually Total > Subtotal.
          }
        }

        // STRATEGY 2: Amount on the right (same vertical alignment)
        // Look for other lines that have similar 'top' and 'bottom' (+- tolerance)
        // and are to the right of this line.
        final centerY = line.boundingBox.top + (line.boundingBox.height / 2);
        final tolerance = line.boundingBox.height * 0.5;

        for (var other in lines) {
          if (other == line) continue;
          
          final otherCenterY = other.boundingBox.top + (other.boundingBox.height / 2);
          
          if ((otherCenterY - centerY).abs() < tolerance && 
              other.boundingBox.left > line.boundingBox.left) {
             
             double? rightAmount = parseAmount(other.text);
             if (rightAmount != null) {
               // Found an amount to the right of "Total"
               if (bestAmount == null || rightAmount > bestAmount!) {
                 bestAmount = rightAmount;
               }
             }
          }
        }
      }
    }
    
    // Fallback: If no keyword associations found, just look for the largest number 
    // that looks like a price at the bottom half of the receipt? 
    // For now, let's stick to the previous logic as fallback or just return best found.
    
    // If we haven't found anything with keywords, try just finding the largest number 
    // that matches currency format, assuming the total is usually the largest number.
    if (bestAmount == null) {
       double maxVal = 0;
       for (var line in lines) {
         double? val = parseAmount(line.text);
         if (val != null && val > maxVal) {
           maxVal = val;
         }
       }
       if (maxVal > 0) bestAmount = maxVal;
    }

    return bestAmount;
  }
}
