import 'statement_transaction.dart';

class MonthlyStatementSummary {
  final String monthKey; // e.g. 'October 2026'
  final double totalIncome;
  final double totalExpense;
  final double totalTransfer;
  final int incomeCount;
  final int expenseCount;
  final int transferCount;
  final int needsReviewCount;
  final List<StatementTransaction> transactions;

  MonthlyStatementSummary({
    required this.monthKey,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransfer,
    required this.incomeCount,
    required this.expenseCount,
    required this.transferCount,
    required this.needsReviewCount,
    required this.transactions,
  });

  double get totalFlow => totalIncome + totalExpense + totalTransfer;
  int get totalCount => transactions.length;

  double get incomePercentage => totalFlow > 0 ? (totalIncome / totalFlow) * 100 : 0.0;
  double get expensePercentage => totalFlow > 0 ? (totalExpense / totalFlow) * 100 : 0.0;
  double get transferPercentage => totalFlow > 0 ? (totalTransfer / totalFlow) * 100 : 0.0;

  List<StatementTransaction> get transfers =>
      transactions.where((t) => t.type == StatementTransactionType.transfer).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  List<StatementTransaction> get recentTransfers => transfers.take(5).toList();

  factory MonthlyStatementSummary.fromTransactions(String monthKey, List<StatementTransaction> list) {
    double inc = 0.0;
    double exp = 0.0;
    double trf = 0.0;
    int incC = 0;
    int expC = 0;
    int trfC = 0;
    int revC = 0;

    for (var t in list) {
      switch (t.type) {
        case StatementTransactionType.income:
          inc += t.amount;
          incC++;
          break;
        case StatementTransactionType.expense:
          exp += t.amount;
          expC++;
          break;
        case StatementTransactionType.transfer:
          trf += t.amount;
          trfC++;
          break;
        case StatementTransactionType.needsReview:
          revC++;
          break;
      }
    }

    final sorted = List<StatementTransaction>.from(list)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return MonthlyStatementSummary(
      monthKey: monthKey,
      totalIncome: inc,
      totalExpense: exp,
      totalTransfer: trf,
      incomeCount: incC,
      expenseCount: expC,
      transferCount: trfC,
      needsReviewCount: revC,
      transactions: sorted,
    );
  }
}
