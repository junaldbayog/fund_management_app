import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handle deletion to empty
    if (newValue.text.isEmpty) {
      return const TextEditingValue();
    }

    // Handle backspace/deletion
    if (oldValue.text.length > newValue.text.length) {
      // If deleting the decimal point or numbers before it
      String newText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
      if (newText.isEmpty) {
        return const TextEditingValue();
      }
      
      double? value = double.tryParse(newText);
      if (value != null) {
        String formatted = _formatter.format(value);
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(
            offset: newValue.selection.baseOffset,
          ),
        );
      }
      return newValue;
    }

    // Get the cursor position before the new character
    int cursorPosition = newValue.selection.baseOffset;
    
    // Remove all non-digit characters except decimal
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Split on decimal point
    List<String> parts = cleanText.split('.');
    String wholeNumber = parts[0];
    
    // If there's a decimal part, limit it to 2 places
    String decimalPart = '';
    if (parts.length > 1) {
      decimalPart = parts[1].length > 2 ? parts[1].substring(0, 2) : parts[1];
    }
    
    // Combine whole number and decimal
    cleanText = wholeNumber + (decimalPart.isNotEmpty ? '.$decimalPart' : '');
    
    // Parse and format
    double? value = double.tryParse(cleanText);
    if (value != null) {
      String formatted = _formatter.format(value);
      
      // Calculate new cursor position
      int newPosition = cursorPosition;
      if (cursorPosition <= wholeNumber.length) {
        // If cursor is in the whole number part, adjust for commas
        int commasBeforeCursor = formatted.substring(0, newPosition).split(',').length - 1;
        newPosition += commasBeforeCursor;
      } else {
        // If cursor is after decimal point, put it at the end
        newPosition = formatted.length;
      }
      
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: newPosition),
      );
    }

    return newValue;
  }

  static double getNumericValue(String text) {
    String numericText = text.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(numericText) ?? 0.0;
  }
} 