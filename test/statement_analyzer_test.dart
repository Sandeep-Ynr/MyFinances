import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/features/statement_analyzer/models/monthly_statement_summary.dart';
import 'package:my_first_app/features/statement_analyzer/models/statement_transaction.dart';
import 'package:my_first_app/features/statement_analyzer/services/gpay_statement_parser.dart';

void main() {
  group('Google Pay Statement Analyzer Tests', () {
    test('Correctly extracts and auto-categorizes Google Pay transactions', () {
      const sampleStatement = '''
Google Pay Transaction Statement
Statement Period: 01 Oct 2026 - 31 Oct 2026

01 Oct 2026, 10:20 AM
Transfer: PNB -> Canara Bank 4016
₹5,000.00
UPI transaction ID: 427512345678
Completed • Punjab National Bank ...5586

01 Oct 2026, 10:21 AM
Transfer: PNB -> Canara Bank 4016
₹10,000.00
UPI transaction ID: 427512345679
Completed • Punjab National Bank ...5586

01 Oct 2026, 08:57 PM
Paid to Punjab enterprises
₹117.00
UPI transaction ID: 427512345680
Completed • Canara Bank ...4016

03 Oct 2026, 12:47 PM
Paid to DAPINDER KAUR
₹20.00
UPI transaction ID: 427512345681
Completed • Canara Bank ...4016

05 Oct 2026, 02:15 PM
Received from Client Payments
₹65,250.00
UPI transaction ID: 427512345682
Completed • Canara Bank ...4016
''';

      final result = GPayStatementParser.parseStatementText(
        rawText: sampleStatement,
        fileName: 'GooglePay_Statement_Oct.pdf',
        userKnownAccounts: ['PNB', 'Canara Bank', 'SBI'],
      );

      expect(result.transactions.length, 5);

      final transfers = result.transactions.where((t) => t.type == StatementTransactionType.transfer).toList();
      final expenses = result.transactions.where((t) => t.type == StatementTransactionType.expense).toList();
      final incomes = result.transactions.where((t) => t.type == StatementTransactionType.income).toList();

      expect(transfers.length, 2);
      expect(expenses.length, 2);
      expect(incomes.length, 1);

      // Verify transfer bank extraction
      expect(transfers.first.sourceBank.contains('PNB'), isTrue);
      expect(transfers.first.destBank?.contains('Canara Bank'), isTrue);

      // Verify amounts
      final transferSum = transfers.fold(0.0, (s, t) => s + t.amount);
      expect(transferSum, 15000.0);

      final expenseSum = expenses.fold(0.0, (s, t) => s + t.amount);
      expect(expenseSum, 137.0);

      final incomeSum = incomes.fold(0.0, (s, t) => s + t.amount);
      expect(incomeSum, 65250.0);
    });

    test('Prevents duplicate transactions using UPI Transaction ID', () {
      const sampleStatement = '''
01 Oct 2026, 10:20 AM
Transfer: PNB -> Canara Bank 4016
₹5,000.00
UPI transaction ID: 427512345678
Completed • Punjab National Bank ...5586
''';

      final existingUpiIds = {'427512345678'};

      final result = GPayStatementParser.parseStatementText(
        rawText: sampleStatement,
        fileName: 'GooglePay_Statement_Oct.pdf',
        existingUpiIds: existingUpiIds,
        userKnownAccounts: ['PNB', 'Canara Bank'],
      );

      expect(result.transactions.isEmpty, isTrue);
      expect(result.duplicatesSkipped, 1);
    });

    test('MonthlyStatementSummary correctly calculates flow and excludes self transfers from income/expense', () {
      final now = DateTime(2026, 10, 15);
      final txList = [
        StatementTransaction(
          id: '1',
          dateTime: now,
          details: 'Received from Client',
          amount: 65250.0,
          type: StatementTransactionType.income,
          sourceBank: 'Canara Bank',
          upiId: 'upi_1',
          category: 'Income',
          rawLine: '',
          statementFileName: 'test.pdf',
        ),
        StatementTransaction(
          id: '2',
          dateTime: now,
          details: 'Paid to Merchant',
          amount: 53968.0,
          type: StatementTransactionType.expense,
          sourceBank: 'PNB',
          upiId: 'upi_2',
          category: 'Shopping',
          rawLine: '',
          statementFileName: 'test.pdf',
        ),
        StatementTransaction(
          id: '3',
          dateTime: now,
          details: 'Transfer: PNB -> Canara Bank',
          amount: 101679.0,
          type: StatementTransactionType.transfer,
          sourceBank: 'PNB',
          destBank: 'Canara Bank 4016',
          upiId: 'upi_3',
          category: 'Transfer',
          rawLine: '',
          statementFileName: 'test.pdf',
        ),
      ];

      final summary = MonthlyStatementSummary.fromTransactions('October 2026', txList);

      expect(summary.totalIncome, 65250.0);
      expect(summary.totalExpense, 53968.0);
      expect(summary.totalTransfer, 101679.0);
      expect(summary.totalFlow, 65250.0 + 53968.0 + 101679.0);
      expect(summary.totalCount, 3);
      expect(summary.transferCount, 1);

      // Verify self-transfer is not in income or expense
      expect(summary.totalIncome, isNot(contains(101679.0)));
      expect(summary.totalExpense, isNot(contains(101679.0)));
    });
  });
}
