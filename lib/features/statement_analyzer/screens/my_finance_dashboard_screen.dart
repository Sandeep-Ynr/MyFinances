import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/monthly_statement_summary.dart';
import '../models/statement_transaction.dart';
import '../services/statement_storage_service.dart';
import '../widgets/flow_donut_chart.dart';
import '../widgets/statement_transaction_tile.dart';
import '../widgets/transfer_card.dart';
import 'import_statement_screen.dart';

class MyFinanceDashboardScreen extends StatefulWidget {
  final String? initialMonthKey;
  final List<String> existingAccountNames;

  const MyFinanceDashboardScreen({
    super.key,
    this.initialMonthKey,
    this.existingAccountNames = const [],
  });

  @override
  State<MyFinanceDashboardScreen> createState() => _MyFinanceDashboardScreenState();
}

class _MyFinanceDashboardScreenState extends State<MyFinanceDashboardScreen> {
  final StatementStorageService _storage = StatementStorageService();

  int _selectedTopTab = 0; // 0: Dashboard, 1: Transactions, 2: Transfers, 3: Reports
  String _selectedMonthKey = '';
  List<String> _availableMonths = [];
  bool _isLoading = true;

  // Filter state for Transactions tab
  String _txTypeFilter = 'ALL'; // ALL, EXPENSE, INCOME, TRANSFER
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter state for Transfers tab
  String? _filterSourceBank;
  String? _filterDestBank;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _storage.init();
    final months = _storage.getAvailableMonths();

    String currentMonth = widget.initialMonthKey ?? '';
    if (currentMonth.isEmpty || !months.contains(currentMonth)) {
      final nowKey = DateFormat('MMMM yyyy').format(DateTime.now());
      if (months.contains(nowKey)) {
        currentMonth = nowKey;
      } else if (months.isNotEmpty) {
        currentMonth = months.first;
      } else {
        currentMonth = nowKey;
      }
    }

    setState(() {
      _availableMonths = months;
      _selectedMonthKey = currentMonth;
      _isLoading = false;
    });
  }

  void _switchMonth(int delta) {
    if (_availableMonths.isEmpty) return;
    int idx = _availableMonths.indexOf(_selectedMonthKey);
    if (idx == -1) idx = 0;

    int newIdx = idx - delta; // availableMonths is descending
    if (newIdx >= 0 && newIdx < _availableMonths.length) {
      setState(() {
        _selectedMonthKey = _availableMonths[newIdx];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _storage.getMonthlySummary(_selectedMonthKey);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E3D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'My Finance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined, color: Colors.white),
            tooltip: 'Import Statement',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImportStatementScreen(
                    existingAccountNames: widget.existingAccountNames,
                  ),
                ),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F4E3D)))
          : Column(
              children: [
                // Top Chips Navigation
                _buildTopNavigationChips(),

                // Month Selector Bar
                _buildMonthSelectorBar(),

                // Body based on selected tab
                Expanded(
                  child: _buildCurrentTabBody(summary),
                ),
              ],
            ),
    );
  }

  Widget _buildTopNavigationChips() {
    final tabs = ['Dashboard', 'Transactions', 'Transfers', 'Reports'];

    return Container(
      color: const Color(0xFF1F4E3D),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedTopTab == idx;
          return InkWell(
            onTap: () => setState(() => _selectedTopTab = idx),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1F4E3D) : Colors.white.withOpacity(0.9),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthSelectorBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF1F4E3D)),
            onPressed: () => _switchMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          PopupMenuButton<String>(
            initialValue: _selectedMonthKey,
            onSelected: (m) => setState(() => _selectedMonthKey = m),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF1F4E3D)),
                const SizedBox(width: 8),
                Text(
                  _selectedMonthKey,
                  style: const TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D)),
              ],
            ),
            itemBuilder: (ctx) {
              if (_availableMonths.isEmpty) {
                return [PopupMenuItem(value: _selectedMonthKey, child: Text(_selectedMonthKey))];
              }
              return _availableMonths.map((m) {
                return PopupMenuItem(
                  value: m,
                  child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF1F4E3D)),
            onPressed: () => _switchMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabBody(MonthlyStatementSummary summary) {
    if (_storage.allTransactions.isEmpty) {
      return _buildEmptyState();
    }

    switch (_selectedTopTab) {
      case 0:
        return _buildDashboardTab(summary);
      case 1:
        return _buildTransactionsTab(summary);
      case 2:
        return _buildTransfersTab(summary);
      case 3:
        return _buildReportsTab(summary);
      default:
        return _buildDashboardTab(summary);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.file_upload_outlined, size: 48, color: Color(0xFF0284C7)),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Statements Imported Yet',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your Google Pay PDF statement to auto-extract transactions and generate insights.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImportStatementScreen(
                      existingAccountNames: widget.existingAccountNames,
                    ),
                  ),
                );
                _loadData();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Import Google Pay PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. DASHBOARD VIEW (Matching Mockup Screen 2)
  // ===========================================================================
  Widget _buildDashboardTab(MonthlyStatementSummary summary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        // Monthly Summary Card (Google Pay)
        _buildMonthlySummaryHeaderCard(summary),

        const SizedBox(height: 16),

        // Expense vs Income Donut Chart
        FlowDonutChart(
          totalIncome: summary.totalIncome,
          totalExpense: summary.totalExpense,
          totalTransfer: summary.totalTransfer,
          totalFlow: summary.totalFlow,
        ),

        const SizedBox(height: 20),

        // Recent Transfers Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transfers',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _selectedTopTab = 2),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (summary.recentTransfers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No self-transfers recorded in this month.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          ...summary.recentTransfers.map((tx) => TransferCard(
                transfer: tx,
                onTap: () => _showEditTransactionDialog(tx),
              )),
      ],
    );
  }

  Widget _buildMonthlySummaryHeaderCard(MonthlyStatementSummary summary) {
    final currencyFmt = NumberFormat('#,##,###');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Summary (Google Pay)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Income
              Expanded(
                child: _buildSummarySubCard(
                  title: 'Income',
                  amount: '₹${currencyFmt.format(summary.totalIncome.toInt())}',
                  subtitle: 'Received',
                  arrowIcon: Icons.arrow_downward_rounded,
                  arrowColor: const Color(0xFF16A34A),
                  textColor: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 10),
              // Expense
              Expanded(
                child: _buildSummarySubCard(
                  title: 'Expense',
                  amount: '₹${currencyFmt.format(summary.totalExpense.toInt())}',
                  subtitle: 'Sent (Payments)',
                  arrowIcon: Icons.arrow_upward_rounded,
                  arrowColor: const Color(0xFFDC2626),
                  textColor: const Color(0xFFB91C1C),
                ),
              ),
              const SizedBox(width: 10),
              // Transfer
              Expanded(
                child: _buildSummarySubCard(
                  title: 'Transfer',
                  amount: '₹${currencyFmt.format(summary.totalTransfer.toInt())}',
                  subtitle: '${summary.transferCount} Transactions',
                  arrowIcon: Icons.swap_horiz_rounded,
                  arrowColor: const Color(0xFF2563EB),
                  textColor: const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySubCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData arrowIcon,
    required Color arrowColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(arrowIcon, size: 14, color: arrowColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TRANSACTIONS TAB (Matching Mockup Screen 3)
  // ===========================================================================
  Widget _buildTransactionsTab(MonthlyStatementSummary summary) {
    // Filter transactions
    var list = summary.transactions;

    if (_txTypeFilter == 'EXPENSE') {
      list = list.where((t) => t.type == StatementTransactionType.expense).toList();
    } else if (_txTypeFilter == 'INCOME') {
      list = list.where((t) => t.type == StatementTransactionType.income).toList();
    } else if (_txTypeFilter == 'TRANSFER') {
      list = list.where((t) => t.type == StatementTransactionType.transfer).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((t) {
        return t.details.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.sourceBank.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (t.destBank != null && t.destBank!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
            t.upiId.contains(_searchQuery);
      }).toList();
    }

    // Group by Date e.g. "01 Oct, 2026"
    final Map<String, List<StatementTransaction>> grouped = {};
    for (var tx in list) {
      final dKey = tx.formattedDate;
      if (!grouped.containsKey(dKey)) grouped[dKey] = [];
      grouped[dKey]!.add(tx);
    }

    return Column(
      children: [
        // Search & Type Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search merchant, person or UPI ID...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF1F4E3D)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 10),
              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('All', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expense', 'EXPENSE'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Income', 'INCOME'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Transfer', 'TRANSFER'),
                ],
              ),
            ],
          ),
        ),

        // Transaction List Grouped by Date
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('No matching transactions found.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (tx) => StatementTransactionTile(
                            transaction: tx,
                            onTap: () => _showEditTransactionDialog(tx),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final isSelected = _txTypeFilter == code;
    return InkWell(
      onTap: () => setState(() => _txTypeFilter = code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. TRANSFERS TAB (Dedicated Bank-to-Bank History)
  // ===========================================================================
  Widget _buildTransfersTab(MonthlyStatementSummary summary) {
    var transfers = summary.transfers;

    if (_filterSourceBank != null && _filterSourceBank!.isNotEmpty) {
      transfers = transfers.where((t) => t.sourceBank == _filterSourceBank).toList();
    }
    if (_filterDestBank != null && _filterDestBank!.isNotEmpty) {
      transfers = transfers.where((t) => t.destBank == _filterDestBank).toList();
    }

    final allSourceBanks = summary.transfers.map((t) => t.sourceBank).toSet().toList();
    final allDestBanks = summary.transfers.map((t) => t.destBank ?? '').where((b) => b.isNotEmpty).toSet().toList();

    return Column(
      children: [
        // Bank Filters
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterSourceBank,
                  decoration: InputDecoration(
                    labelText: 'From Bank',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sources', style: TextStyle(fontSize: 12))),
                    ...allSourceBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) => setState(() => _filterSourceBank = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterDestBank,
                  decoration: InputDecoration(
                    labelText: 'To Bank',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Destinations', style: TextStyle(fontSize: 12))),
                    ...allDestBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) => setState(() => _filterDestBank = val),
                ),
              ),
            ],
          ),
        ),

        // Transfer List
        Expanded(
          child: transfers.isEmpty
              ? const Center(
                  child: Text('No self-transfers match the selected filters.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: transfers.length,
                  itemBuilder: (ctx, idx) {
                    final tx = transfers[idx];
                    return TransferCard(
                      transfer: tx,
                      onTap: () => _showEditTransactionDialog(tx),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. REPORTS TAB (Historical overview)
  // ===========================================================================
  Widget _buildReportsTab(MonthlyStatementSummary currentSummary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Historical Financial Statements',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        ..._availableMonths.map((mKey) {
          final s = _storage.getMonthlySummary(mKey);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedMonthKey = mKey;
                  _selectedTopTab = 0;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mKey,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D)),
                        ),
                        Text(
                          '${s.totalCount} transactions',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildReportStat('Income', '₹${NumberFormat('#,##,###').format(s.totalIncome.toInt())}', const Color(0xFF16A34A)),
                        _buildReportStat('Expense', '₹${NumberFormat('#,##,###').format(s.totalExpense.toInt())}', const Color(0xFFDC2626)),
                        _buildReportStat('Transfer', '₹${NumberFormat('#,##,###').format(s.totalTransfer.toInt())}', const Color(0xFF2563EB)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReportStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ===========================================================================
  // EDIT / REVIEW TRANSACTION DIALOG
  // ===========================================================================
  void _showEditTransactionDialog(StatementTransaction tx) {
    StatementTransactionType editType = tx.type;
    final detailsController = TextEditingController(text: tx.details);
    final sourceController = TextEditingController(text: tx.sourceBank);
    final destController = TextEditingController(text: tx.destBank ?? '');
    final categoryController = TextEditingController(text: tx.category);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
            ),
            title: const Text(
              'Edit Transaction',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selection chips
                  Wrap(
                    spacing: 6,
                    children: StatementTransactionType.values.map((t) {
                      final isSel = editType == t;
                      return ChoiceChip(
                        label: Text(t.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setDlgState(() => editType = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    decoration: const InputDecoration(labelText: 'Details / Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(labelText: 'Source Bank (From)'),
                  ),
                  if (editType == StatementTransactionType.transfer) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: destController,
                      decoration: const InputDecoration(labelText: 'Destination Bank (To)'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E3D), foregroundColor: Colors.white),
                onPressed: () async {
                  tx.type = editType;
                  tx.sourceBank = sourceController.text.trim();
                  tx.destBank = destController.text.trim().isNotEmpty ? destController.text.trim() : null;
                  tx.category = categoryController.text.trim();
                  tx.isReviewed = true;
                  await _storage.updateTransaction(tx);
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
