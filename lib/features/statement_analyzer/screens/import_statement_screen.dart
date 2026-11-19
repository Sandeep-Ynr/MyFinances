import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/gpay_statement_parser.dart';
import '../services/pdf_extractor_service.dart';
import '../services/statement_storage_service.dart';
import 'my_finance_dashboard_screen.dart';

class ImportStatementScreen extends StatefulWidget {
  final List<String> existingAccountNames;

  const ImportStatementScreen({
    super.key,
    this.existingAccountNames = const [],
  });

  @override
  State<ImportStatementScreen> createState() => _ImportStatementScreenState();
}

class _ImportStatementScreenState extends State<ImportStatementScreen> {
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  int _pageCount = 0;
  bool _isAnalyzing = false;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data. Please try again.')),
          );
          return;
        }

        // Quick page count check
        setState(() {
          _isAnalyzing = true;
          _statusMessage = 'Reading PDF structure...';
        });

        final extractionResult = await PdfExtractorService.extractTextFromBytes(bytes);

        if (!mounted) return;
        setState(() {
          _pickedFile = file;
          _fileBytes = bytes;
          _pageCount = extractionResult.pageCount;
          _isAnalyzing = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _statusMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<void> _importAndAnalyze() async {
    if (_fileBytes == null || _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Google Pay statement PDF file first.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Extracting all pages from PDF...';
    });

    final storage = StatementStorageService();
    await storage.init();
    final existingUpiIds = storage.getExistingUpiIds();

    final extraction = await PdfExtractorService.extractTextFromBytes(_fileBytes!);
    if (!mounted) return;
    if (!extraction.success) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(extraction.errorMessage ?? 'Failed to extract text from PDF.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _statusMessage = 'Auto-categorizing transactions (Income, Expense, Transfer)...';
    });

    final parseResult = GPayStatementParser.parseStatementText(
      rawText: extraction.fullText,
      fileName: _pickedFile!.name,
      existingUpiIds: existingUpiIds,
      userKnownAccounts: widget.existingAccountNames,
    );

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
    });

    if (parseResult.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parseResult.duplicatesSkipped > 0
                ? 'All ${parseResult.duplicatesSkipped} transactions in this statement were already imported previously!'
                : 'No recognizable Google Pay transactions found in this document.',
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    _showImportSuccessModal(parseResult);
  }

  void _showImportSuccessModal(ParseResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7E6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statement Analyzed!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F4E3D),
                          ),
                        ),
                        Text(
                          'Transactions ready to be saved',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Total Found', '${result.totalFound}'),
                    const Divider(height: 16),
                    _buildStatRow('New to Import', '${result.successCount}', color: const Color(0xFF16A34A), bold: true),
                    if (result.duplicatesSkipped > 0) ...[
                      const Divider(height: 16),
                      _buildStatRow('Duplicates Skipped', '${result.duplicatesSkipped}', color: const Color(0xFF64748B)),
                    ],
                    if (result.needsReviewCount > 0) ...[
                      const Divider(height: 16),
                      _buildStatRow('Needs Review', '${result.needsReviewCount}', color: const Color(0xFFD97706)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await StatementStorageService().addTransactions(result.transactions);
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyFinanceDashboardScreen(
                            initialMonthKey: result.transactions.first.monthKey,
                            existingAccountNames: widget.existingAccountNames,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Save & Open Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF475569),
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: color ?? const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F4E3D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Import Statement',
          style: TextStyle(
            color: Color(0xFF1F4E3D),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // PDF Circle Graphic
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 72,
                        color: Color(0xFF0284C7),
                      ),
                      Positioned(
                        bottom: 30,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Google Pay Statement',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your Google Pay transaction statement (PDF) to auto-categorize your transactions.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Select PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isAnalyzing ? null : _pickPdfFile,
                icon: const Icon(Icons.file_upload_outlined, size: 22),
                label: const Text(
                  'Select PDF File',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // File Selected Card
            if (_pickedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFile!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_pageCount > 0 ? '$_pageCount pages • ' : ''}${_formatFileSize(_pickedFile!.size)}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Import & Analyze Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_pickedFile != null && !_isAnalyzing) ? _importAndAnalyze : null,
                child: _isAnalyzing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Import & Analyze',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            if (_isAnalyzing && _statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: const TextStyle(color: Color(0xFF1F4E3D), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 36),

            // Checklist Section (matching mockup)
            _buildChecklistItem('Read transactions from PDF'),
            _buildChecklistItem('Calculate Income, Expense & Transfer'),
            _buildChecklistItem('Categorize automatically'),
            _buildChecklistItem('Show monthly dashboard'),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
