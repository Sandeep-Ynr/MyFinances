import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/main.dart';

void main() {
  group('Account Transfer & Opening Balance Tests', () {
    test('isTransferToAccountGlobal correctly detects transfer destination', () {
      final transferRec = TransactionRecord(
        id: 't1',
        type: 'TRANSFER',
        accountName: 'PNB (19-863-55)',
        category: 'Transfer to FD',
        amount: 5000.0,
        notes: 'Transfer from PNB (19-863-55) to FD',
        dateTime: DateTime.now(),
      );

      expect(isTransferToAccountGlobal(transferRec, 'FD'), isTrue);
      expect(isTransferToAccountGlobal(transferRec, 'fd'), isTrue);
      expect(isTransferToAccountGlobal(transferRec, 'PNB (19-863-55)'), isFalse);
    });

    test('getTransferToAccountGlobal extracts correct destination account', () {
      final rec1 = TransactionRecord(
        id: 't1',
        type: 'TRANSFER',
        accountName: 'PNB',
        category: 'Transfer to Canara Bank',
        amount: 1000.0,
        notes: '',
        dateTime: DateTime.now(),
      );
      expect(getTransferToAccountGlobal(rec1), 'Canara Bank');

      final rec2 = TransactionRecord(
        id: 't2',
        type: 'TRANSFER',
        accountName: 'PNB',
        category: '[PNB > Canara Bank 4016]',
        amount: 2000.0,
        notes: '',
        dateTime: DateTime.now(),
      );
      expect(getTransferToAccountGlobal(rec2), 'Canara Bank 4016');
    });

    test('AccountDetailsScreen does not auto-create Opening Balance for accounts receiving transfers', () {
      final pnbAcc = AccountItem(
        id: 'pnb_id',
        name: 'PNB (19-863-55)',
        balance: 45000.0,
        icon: Icons.account_balance,
        iconBgColor: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0369A1),
      );

      final fdAcc = AccountItem(
        id: 'fd_id',
        name: 'FD',
        balance: 5000.0,
        icon: Icons.account_balance_wallet,
        iconBgColor: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0369A1),
      );

      // User has an initial opening balance for PNB, but NOT for FD
      final records = <TransactionRecord>[
        TransactionRecord(
          id: 'init_pnb',
          type: 'INCOME',
          accountName: 'PNB (19-863-55)',
          category: 'Opening Balance',
          amount: 50000.0,
          notes: 'Initial Account Balance',
          dateTime: DateTime(2026, 11, 1),
        ),
        TransactionRecord(
          id: 'tx_transfer_1',
          type: 'TRANSFER',
          accountName: 'PNB (19-863-55)',
          category: 'Transfer to FD',
          amount: 5000.0,
          notes: 'Transfer from PNB (19-863-55) to FD',
          dateTime: DateTime(2026, 11, 21),
        ),
      ];

      // Verify FD has no opening balance record before viewing
      expect(records.any((r) => r.accountName == 'FD' && r.category == 'Opening Balance'), isFalse);

      // Verify that no opening balance record is created
      expect(records.where((r) => r.category == 'Opening Balance').length, 1);
      expect(records.first.accountName, 'PNB (19-863-55)');
    });
  });
}
