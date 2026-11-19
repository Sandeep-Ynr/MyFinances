import 'dart:math';
import 'package:intl/intl.dart';
import '../models/statement_transaction.dart';

class ParseResult {
  final List<StatementTransaction> transactions;
  final int totalFound;
  final int duplicatesSkipped;
  final int successCount;
  final int needsReviewCount;
  final List<String> parsingWarnings;

  ParseResult({
    required this.transactions,
    required this.totalFound,
    required this.duplicatesSkipped,
    required this.successCount,
    required this.needsReviewCount,
    this.parsingWarnings = const [],
  });
}

class GPayStatementParser {
  // Common Indian Bank identifiers for smart extraction
  static const List<String> knownBankNames = [
    'PNB', 'Punjab National Bank',
    'Canara Bank', 'Canera Bank',
    'SBI', 'State Bank of India',
    'HDFC', 'HDFC Bank',
    'ICICI', 'ICICI Bank',
    'Axis', 'Axis Bank',
    'Bank of Baroda', 'BOB',
    'Kotak', 'Kotak Mahindra Bank',
    'Union Bank', 'Union Bank of India',
    'IDFC', 'IDFC FIRST Bank',
    'IndusInd Bank', 'Yes Bank',
    'Federal Bank', 'Indian Bank',
    'Central Bank of India', 'UCO Bank',
    'Paytm Payments Bank', 'Airtel Payments Bank',
    'UPI Light',
  ];

  /// Parses extracted raw text from Google Pay statement PDF
  static ParseResult parseStatementText({
    required String rawText,
    required String fileName,
    Set<String> existingUpiIds = const {},
    List<String> userKnownAccounts = const [],
  }) {
    final List<StatementTransaction> parsedList = [];
    final Set<String> seenUpiInBatch = {};
    int duplicatesCount = 0;
    final List<String> warnings = [];

    // Normalize text line breaks
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Strategy 1: Multi-line block detection
    // Google Pay transactions typically appear as blocks:
    // Date & Time (e.g. "01 Oct 2026, 10:20 AM" or "Oct 01, 2026")
    // Description (e.g. "Paid to Punjab enterprises" or "Transfer to Canara Bank 4016")
    // Amount (e.g. "₹5,000.00" or "5000.00")
    // UPI Ref / Transaction ID (e.g. "UPI transaction ID: 427512345678")
    // Bank account (e.g. "Punjab National Bank ...5586")

    final List<List<String>> transactionBlocks = _segmentIntoBlocks(lines);

    for (var block in transactionBlocks) {
      try {
        final tx = _parseSingleBlock(
          block: block,
          fileName: fileName,
          userKnownAccounts: userKnownAccounts,
        );

        if (tx != null) {
          // Check for duplicate UPI ID
          if (tx.upiId.isNotEmpty) {
            if (existingUpiIds.contains(tx.upiId) || seenUpiInBatch.contains(tx.upiId)) {
              duplicatesCount++;
              continue;
            }
            seenUpiInBatch.add(tx.upiId);
          }
          parsedList.add(tx);
        }
      } catch (e) {
        warnings.add('Error parsing block: $e');
      }
    }

    // Fallback: If block segmentation found very few, try line-by-line regex scanning
    if (parsedList.isEmpty && lines.length > 5) {
      final lineTxList = _parseLineByLineFallback(
        lines: lines,
        fileName: fileName,
        existingUpiIds: existingUpiIds,
        userKnownAccounts: userKnownAccounts,
      );
      parsedList.addAll(lineTxList);
    }

    // Sort by Date descending
    parsedList.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final int needsRev = parsedList.where((t) => t.type == StatementTransactionType.needsReview).length;

    return ParseResult(
      transactions: parsedList,
      totalFound: parsedList.length + duplicatesCount,
      duplicatesSkipped: duplicatesCount,
      successCount: parsedList.length,
      needsReviewCount: needsRev,
      parsingWarnings: warnings,
    );
  }

  /// Groups raw lines into logical transaction blocks
  static List<List<String>> _segmentIntoBlocks(List<String> lines) {
    final List<List<String>> blocks = [];
    List<String> currentBlock = [];

    final datePattern = RegExp(
      r'^\s*(\d{1,2}[\s\/\-\.](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|[0-9]{1,2})[\s\/\-\.]\d{2,4})|'
      r'^((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4})',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Skip header and footer metadata lines
      if (lower.contains('statement period') ||
          lower.contains('page ') ||
          lower.contains('statement summary') ||
          lower.contains('transaction statement')) {
        continue;
      }

      // If line starts with a date and current block is not empty, start a new block
      if (datePattern.hasMatch(line) && currentBlock.isNotEmpty) {
        // Only split if the current block already contains at least an amount or details
        if (_blockHasAmount(currentBlock)) {
          blocks.add(List.from(currentBlock));
          currentBlock.clear();
        }
      }

      currentBlock.add(line);

      // If block contains "UPI transaction ID" or "UPI Ref", it's usually the tail of a transaction
      if (line.toLowerCase().contains('upi transaction id') || line.toLowerCase().contains('upi ref')) {
        // Collect one or two following lines if they contain bank account info
        if (i + 1 < lines.length && (lines[i + 1].toLowerCase().contains('bank') || lines[i + 1].contains('••••'))) {
          currentBlock.add(lines[i + 1]);
          i++;
        }
        if (_blockHasAmount(currentBlock)) {
          blocks.add(List.from(currentBlock));
          currentBlock.clear();
        }
      }
    }

    if (currentBlock.isNotEmpty && _blockHasAmount(currentBlock)) {
      blocks.add(currentBlock);
    }

    return blocks;
  }

  static bool _blockHasAmount(List<String> block) {
    final amountPattern = RegExp(r'[₹$RsINR]?\s*[0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{2})?');
    return block.any((l) => amountPattern.hasMatch(l) && _extractAmount(l) > 0);
  }

  /// Extracts transaction from a multi-line block
  static StatementTransaction? _parseSingleBlock({
    required List<String> block,
    required String fileName,
    required List<String> userKnownAccounts,
  }) {
    if (block.isEmpty) return null;

    final fullBlockText = block.join(' ');

    // 1. Extract Amount
    double amount = 0.0;
    for (var line in block) {
      final a = _extractAmount(line);
      if (a > 0) {
        amount = a;
        break;
      }
    }
    if (amount <= 0) return null;

    // 2. Extract Date & Time
    DateTime dateTime = _extractDateTime(fullBlockText) ?? DateTime.now();

    // 3. Extract UPI Transaction ID
    String upiId = _extractUpiId(fullBlockText);
    if (upiId.isEmpty) {
      upiId = 'tx_${dateTime.millisecondsSinceEpoch}_${(amount * 100).toInt()}_${Random().nextInt(9999)}';
    }

    // 4. Extract Description / Details
    String details = _extractDetails(block);

    // 5. Extract Source Bank & Dest Bank
    String sourceBank = _extractSourceBank(fullBlockText, userKnownAccounts);
    String? destBank = _extractDestBank(details, fullBlockText, userKnownAccounts);

    // 6. Categorization
    StatementTransactionType type = _determineType(
      details: details,
      sourceBank: sourceBank,
      destBank: destBank,
      fullBlockText: fullBlockText,
      userKnownAccounts: userKnownAccounts,
    );

    // 7. Category Label
    String category = _determineCategory(details, type);

    return StatementTransaction(
      id: upiId,
      dateTime: dateTime,
      details: details,
      amount: amount,
      type: type,
      sourceBank: sourceBank,
      destBank: destBank,
      upiId: upiId,
      category: category,
      rawLine: fullBlockText,
      statementFileName: fileName,
      isReviewed: type != StatementTransactionType.needsReview,
    );
  }

  static double _extractAmount(String text) {
    // Avoid lines that look like dates or timestamps without currency symbols
    if (RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b', caseSensitive: false).hasMatch(text)) {
      final explicit = RegExp(r'[₹$]|(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(text);
      if (explicit == null) return 0.0;
    }

    // 1. First priority: currency symbol followed by amount (e.g., ₹5,000.00, ₹117, Rs. 500)
    final currReg = RegExp(r'[₹$]\s*([0-9,]+(?:\.[0-9]{1,2})?)|(?:Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
    final currMatch = currReg.firstMatch(text);
    if (currMatch != null) {
      final valStr = (currMatch.group(1) ?? currMatch.group(2))?.replaceAll(',', '').trim();
      if (valStr != null) {
        final val = double.tryParse(valStr) ?? 0.0;
        if (val > 0) return val;
      }
    }

    // 2. Standalone line with decimal amount (e.g., 5000.00, 117.00, +5000.00, -117.00)
    final trimmed = text.trim();
    final standaloneReg = RegExp(r'^[+-]?\s*[₹$RsINR]?\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{2}))\s*$', caseSensitive: false);
    final standMatch = standaloneReg.firstMatch(trimmed);
    if (standMatch != null) {
      final valStr = standMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(valStr) ?? 0.0;
      if (val > 0) return val;
    }

    return 0.0;
  }

  static DateTime? _extractDateTime(String text) {
    // 01 Oct 2026, 10:20 AM or 01 Oct, 2026 • 10:20 AM
    try {
      final dateRegex = RegExp(
        r'(\d{1,2})\s+([A-Za-z]{3,9}),?\s+(\d{4})(?:[,\s•]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?)?',
        caseSensitive: false,
      );
      final m = dateRegex.firstMatch(text);
      if (m != null) {
        int day = int.parse(m.group(1)!);
        String monthStr = m.group(2)!.toLowerCase();
        int year = int.parse(m.group(3)!);
        int month = _monthNumber(monthStr);

        int hour = 0;
        int minute = 0;
        if (m.group(4) != null && m.group(5) != null) {
          hour = int.parse(m.group(4)!);
          minute = int.parse(m.group(5)!);
          final ampm = m.group(7)?.toUpperCase();
          if (ampm == 'PM' && hour < 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }

        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}

    // Fallback: dd/MM/yyyy HH:mm
    try {
      final slashRegex = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?');
      final sm = slashRegex.firstMatch(text);
      if (sm != null) {
        int day = int.parse(sm.group(1)!);
        int month = int.parse(sm.group(2)!);
        int year = int.parse(sm.group(3)!);
        if (year < 100) year += 2000;
        int hour = sm.group(4) != null ? int.parse(sm.group(4)!) : 0;
        int min = sm.group(5) != null ? int.parse(sm.group(5)!) : 0;
        return DateTime(year, month, day, hour, min);
      }
    } catch (_) {}

    return null;
  }

  static int _monthNumber(String mStr) {
    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    return months[mStr.toLowerCase()] ?? DateTime.now().month;
  }

  static String _extractUpiId(String text) {
    // Google Pay / UPI UTR is 12 digits or specific alphanumeric ref
    final upiMatch = RegExp(r'(?:UPI\s*(?:transaction\s*ID|Ref(?:\s*no)?)|UTR|Ref\s*#?)[:\s]+([0-9A-Za-z]{10,25})', caseSensitive: false).firstMatch(text);
    if (upiMatch != null) {
      return upiMatch.group(1)!.trim();
    }
    // Generic 12 digit UPI reference
    final ref12 = RegExp(r'\b(\d{12})\b').firstMatch(text);
    if (ref12 != null) {
      return ref12.group(1)!;
    }
    return '';
  }

  static String _extractDetails(List<String> block) {
    for (var line in block) {
      final clean = line.trim();
      final lower = clean.toLowerCase();
      // Skip lines that are just amounts, dates, or headers
      if (lower.startsWith('paid to ') ||
          lower.startsWith('payment to ') ||
          lower.startsWith('received from ') ||
          lower.startsWith('transfer to ') ||
          lower.startsWith('transfer from ') ||
          lower.startsWith('transfer:') ||
          lower.startsWith('transfer ') ||
          lower.startsWith('self transfer') ||
          lower.startsWith('refund from ') ||
          lower.startsWith('cashback from ')) {
        return clean;
      }
    }

    // Secondary fallback: find the most descriptive text line
    for (var line in block) {
      final clean = line.trim();
      final lower = clean.toLowerCase();
      if (clean.isEmpty) continue;
      if (clean.contains('UPI') || lower.contains('upi transaction') || lower.contains('upi ref')) continue;
      if (clean.contains('₹') || lower.contains('rs.') || lower.contains('inr')) continue;
      if (lower.startsWith('completed') || lower.startsWith('failed') || lower.startsWith('pending')) continue;
      // Skip if line looks like date
      if (RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b', caseSensitive: false).hasMatch(clean)) continue;
      if (RegExp(r'^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(clean)) continue;
      if (RegExp(r'^\d+$').hasMatch(clean)) continue;

      if (clean.length > 4) {
        return clean;
      }
    }

    return block.isNotEmpty ? block.first : 'Google Pay Transaction';
  }

  static String _extractSourceBank(String text, List<String> userAccounts) {
    // 1. If explicit transfer syntax: "Transfer: PNB -> Canara Bank"
    final transferArrow = RegExp(r'Transfer:\s*([A-Za-z0-9\s]+?)\s*(?:->|→|to)\s*', caseSensitive: false).firstMatch(text);
    if (transferArrow != null) {
      final src = transferArrow.group(1)!.trim();
      if (src.isNotEmpty) {
        for (var acc in userAccounts) {
          if (acc.toLowerCase().contains(src.toLowerCase()) || src.toLowerCase().contains(acc.toLowerCase())) {
            return acc;
          }
        }
        return src;
      }
    }

    // 2. Check for "Completed • <Bank>" or "Debited from <Bank>"
    final debitedPattern = RegExp(r'(?:Completed\s*[•\-]\s*|Debited from\s+|From\s+)([A-Za-z0-9\s\.\(\)]+)', caseSensitive: false).firstMatch(text);
    if (debitedPattern != null) {
      final candidate = debitedPattern.group(1)!.trim();
      for (var acc in userAccounts) {
        if (candidate.toLowerCase().contains(acc.toLowerCase())) {
          return acc;
        }
      }
      for (var bank in knownBankNames) {
        if (candidate.toLowerCase().contains(bank.toLowerCase())) {
          return bank;
        }
      }
    }

    // 3. Check user's known accounts first
    for (var acc in userAccounts) {
      if (text.toLowerCase().contains(acc.toLowerCase())) {
        return acc;
      }
    }

    // 4. Check standard bank patterns
    for (var bank in knownBankNames) {
      if (text.toLowerCase().contains(bank.toLowerCase())) {
        // Check for 4 digit account number suffix, e.g. "Canara Bank 4016"
        final numSuffix = RegExp('${RegExp.escape(bank)}[\\s\\-•]+(\\d{4})', caseSensitive: false).firstMatch(text);
        if (numSuffix != null) {
          return '$bank ${numSuffix.group(1)}';
        }
        return bank;
      }
    }

    return 'Google Pay';
  }

  static String? _extractDestBank(String details, String fullText, List<String> userAccounts) {
    // Only extract destination bank if it is a transfer-related transaction
    final isTransfer = details.toLowerCase().contains('transfer') ||
        details.contains('->') ||
        details.contains('→') ||
        fullText.toLowerCase().contains('transfer to ');

    if (!isTransfer) {
      return null;
    }

    final toPattern = RegExp(r'(?:to|->|→)\s+([A-Za-z0-9\s\(\)\-]+)', caseSensitive: false);
    final m = toPattern.firstMatch(details);
    if (m != null) {
      String candidate = m.group(1)!.trim();
      for (var acc in userAccounts) {
        if (candidate.toLowerCase().contains(acc.toLowerCase())) {
          return acc;
        }
      }
      for (var bank in knownBankNames) {
        if (candidate.toLowerCase().contains(bank.toLowerCase())) {
          final numSuffix = RegExp('\\b(\\d{4})\\b').firstMatch(candidate);
          if (numSuffix != null) {
            return '$bank ${numSuffix.group(1)}';
          }
          return bank;
        }
      }
      if (candidate.isNotEmpty && candidate.length < 30) {
        return candidate;
      }
    }
    return null;
  }

  static StatementTransactionType _determineType({
    required String details,
    required String sourceBank,
    required String? destBank,
    required String fullBlockText,
    required List<String> userKnownAccounts,
  }) {
    final lowerDetails = details.toLowerCase();
    final lowerFull = fullBlockText.toLowerCase();

    // 1. Self-Transfer Check
    if (lowerDetails.contains('transfer') ||
        lowerDetails.contains('self') ||
        lowerDetails.contains('->') ||
        lowerDetails.contains('→') ||
        lowerFull.contains('transfer:') ||
        lowerFull.contains('transfer to ') ||
        lowerFull.contains('self transfer')) {
      return StatementTransactionType.transfer;
    }

    // 2. Income Check
    if (lowerDetails.contains('received from') ||
        lowerDetails.contains('refund') ||
        lowerDetails.contains('cashback') ||
        lowerFull.contains('credited') ||
        lowerFull.contains('received from') ||
        lowerDetails.startsWith('received')) {
      return StatementTransactionType.income;
    }

    // 3. Expense Check
    if (lowerDetails.contains('paid to') ||
        lowerDetails.contains('payment to') ||
        lowerDetails.contains('bill payment') ||
        lowerFull.contains('debited') ||
        lowerFull.contains('paid to') ||
        lowerDetails.startsWith('paid')) {
      return StatementTransactionType.expense;
    }

    // 4. Fallback: Needs Review
    return StatementTransactionType.needsReview;
  }

  static String _determineCategory(String details, StatementTransactionType type) {
    if (type == StatementTransactionType.transfer) return 'Transfer';
    if (type == StatementTransactionType.income) return 'Income';

    final low = details.toLowerCase();
    if (low.contains('food') || low.contains('swiggy') || low.contains('zomato') || low.contains('dairy') || low.contains('restaurant')) return 'Food';
    if (low.contains('petrol') || low.contains('fuel') || low.contains('hp') || low.contains('indian oil')) return 'Fuel/Petrol';
    if (low.contains('grocery') || low.contains('mart') || low.contains('supermarket')) return 'Groceries';
    if (low.contains('medical') || low.contains('pharmacy') || low.contains('hospital')) return 'Health';
    if (low.contains('electricity') || low.contains('recharge') || low.contains('bill')) return 'Bills & Utilities';
    if (low.contains('education') || low.contains('fee') || low.contains('school')) return 'Education';

    return 'General';
  }

  static List<StatementTransaction> _parseLineByLineFallback({
    required List<String> lines,
    required String fileName,
    required Set<String> existingUpiIds,
    required List<String> userKnownAccounts,
  }) {
    final List<StatementTransaction> list = [];
    for (var line in lines) {
      final a = _extractAmount(line);
      final dt = _extractDateTime(line);
      if (a > 0 && dt != null) {
        final upi = _extractUpiId(line);
        final details = _extractDetails([line]);
        final type = _determineType(
          details: details,
          sourceBank: 'Google Pay',
          destBank: null,
          fullBlockText: line,
          userKnownAccounts: userKnownAccounts,
        );

        list.add(
          StatementTransaction(
            id: upi.isNotEmpty ? upi : 'fb_${dt.millisecondsSinceEpoch}',
            dateTime: dt,
            details: details,
            amount: a,
            type: type,
            sourceBank: 'Google Pay',
            destBank: null,
            upiId: upi,
            category: _determineCategory(details, type),
            rawLine: line,
            statementFileName: fileName,
          ),
        );
      }
    }
    return list;
  }
}
