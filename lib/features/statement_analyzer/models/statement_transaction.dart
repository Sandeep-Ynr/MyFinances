import 'package:intl/intl.dart';

enum StatementTransactionType {
  income,
  expense,
  transfer,
  needsReview,
}

extension StatementTransactionTypeExtension on StatementTransactionType {
  String get displayName {
    switch (this) {
      case StatementTransactionType.income:
        return 'Income';
      case StatementTransactionType.expense:
        return 'Expense';
      case StatementTransactionType.transfer:
        return 'Transfer';
      case StatementTransactionType.needsReview:
        return 'Needs Review';
    }
  }

  String get code {
    switch (this) {
      case StatementTransactionType.income:
        return 'INCOME';
      case StatementTransactionType.expense:
        return 'EXPENSE';
      case StatementTransactionType.transfer:
        return 'TRANSFER';
      case StatementTransactionType.needsReview:
        return 'NEEDS_REVIEW';
    }
  }

  static StatementTransactionType fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'INCOME':
        return StatementTransactionType.income;
      case 'EXPENSE':
        return StatementTransactionType.expense;
      case 'TRANSFER':
        return StatementTransactionType.transfer;
      default:
        return StatementTransactionType.needsReview;
    }
  }
}

class StatementTransaction {
  final String id;
  final DateTime dateTime;
  final String details;
  final double amount;
  StatementTransactionType type;
  String sourceBank;
  String? destBank;
  final String upiId;
  String category;
  final String rawLine;
  final String statementFileName;
  bool isReviewed;

  StatementTransaction({
    required this.id,
    required this.dateTime,
    required this.details,
    required this.amount,
    required this.type,
    required this.sourceBank,
    this.destBank,
    required this.upiId,
    required this.category,
    required this.rawLine,
    required this.statementFileName,
    this.isReviewed = false,
  });

  String get formattedAmount => '₹${NumberFormat('#,##,###.##').format(amount)}';
  String get formattedDate => DateFormat('dd MMM, yyyy').format(dateTime);
  String get formattedTime => DateFormat('hh:mm a').format(dateTime);
  String get monthKey => DateFormat('MMMM yyyy').format(dateTime);
  String get shortMonthKey => DateFormat('MMM yyyy').format(dateTime);

  String get displayTitle {
    if (type == StatementTransactionType.transfer) {
      final from = sourceBank.isNotEmpty ? sourceBank : 'Account';
      final to = (destBank != null && destBank!.isNotEmpty) ? destBank! : 'Account';
      return '$from → $to';
    }
    return details;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'details': details,
        'amount': amount,
        'type': type.code,
        'sourceBank': sourceBank,
        'destBank': destBank,
        'upiId': upiId,
        'category': category,
        'rawLine': rawLine,
        'statementFileName': statementFileName,
        'isReviewed': isReviewed,
      };

  factory StatementTransaction.fromJson(Map<String, dynamic> json) => StatementTransaction(
        id: json['id']?.toString() ?? '',
        dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
        details: json['details']?.toString() ?? '',
        amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
        type: StatementTransactionTypeExtension.fromCode(json['type']?.toString() ?? ''),
        sourceBank: json['sourceBank']?.toString() ?? '',
        destBank: json['destBank']?.toString(),
        upiId: json['upiId']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        rawLine: json['rawLine']?.toString() ?? '',
        statementFileName: json['statementFileName']?.toString() ?? '',
        isReviewed: json['isReviewed'] == true,
      );

  StatementTransaction copyWith({
    String? id,
    DateTime? dateTime,
    String? details,
    double? amount,
    StatementTransactionType? type,
    String? sourceBank,
    String? destBank,
    String? upiId,
    String? category,
    String? rawLine,
    String? statementFileName,
    bool? isReviewed,
  }) {
    return StatementTransaction(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      details: details ?? this.details,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      sourceBank: sourceBank ?? this.sourceBank,
      destBank: destBank ?? this.destBank,
      upiId: upiId ?? this.upiId,
      category: category ?? this.category,
      rawLine: rawLine ?? this.rawLine,
      statementFileName: statementFileName ?? this.statementFileName,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }
}
