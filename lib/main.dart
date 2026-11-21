import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'features/statement_analyzer/screens/my_finance_dashboard_screen.dart';
import 'features/statement_analyzer/screens/import_statement_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {},
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    } catch (_) {}
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    await init();
    await requestPermissions();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Expense Reminders',
      channelDescription: 'Reminds you to log your daily expenses in MyFinances',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      999,
      'MyFinances Daily Reminder 💸',
      'Don\'t forget to log your daily income & expenses today!',
      notificationDetails,
    );
  }

  Future<void> scheduleDailyNotification(int hour, int minute) async {
    if (kIsWeb) return;
    await init();
    await requestPermissions();
    await cancelDailyNotification();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Expense Reminders',
      channelDescription: 'Reminds you to log your daily expenses in MyFinances',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'MyFinances Reminder 💸',
        'Time to log today\'s expenses and update your account balances!',
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // Fallback for Android system exact alarm restrictions
      try {
        final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
        await flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          'MyFinances Reminder 💸',
          'Time to log today\'s expenses and update your account balances!',
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e2) {
        debugPrint('Notification scheduling error: $e2');
      }
    }
  }

  Future<void> cancelDailyNotification() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await NotificationService().init();
  }
  runApp(const MyMoneyApp());
}

class MyMoneyApp extends StatefulWidget {
  const MyMoneyApp({super.key});

  @override
  State<MyMoneyApp> createState() => _MyMoneyAppState();
}

class _MyMoneyAppState extends State<MyMoneyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyMoney',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFAF7E6), // Signature warm cream
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E3D),
          primary: const Color(0xFF1F4E3D),
          surface: const Color(0xFFFAF7E6),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF121E19),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6B56),
          brightness: Brightness.dark,
          surface: const Color(0xFF121E19),
        ),
      ),
      home: MyMoneyMainScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// Icon mapper helper for constant IconData compatibility across Web & Android
IconData _getIconFromCode(int? code) {
  if (code == null) return Icons.account_balance_wallet_rounded;
  const iconMap = <int, IconData>{
    0xe3f7: Icons.money_rounded,
    0xe19f: Icons.credit_card_rounded,
    0xe556: Icons.savings_rounded,
    0xe041: Icons.account_balance_wallet_rounded,
    0xe040: Icons.account_balance,
    0xe478: Icons.payments_rounded,
    0xe699: Icons.trending_up_rounded,
    0xe487: Icons.percent_rounded,
    0xe1d7: Icons.directions_car_rounded,
    0xe59c: Icons.shopping_cart_rounded,
    0xe1c0: Icons.content_cut_rounded,
    0xe4a2: Icons.phone_android_rounded,
    0xe1d5: Icons.directions_bus_rounded,
    0xe307: Icons.groups_rounded,
    0xe170: Icons.checkroom_rounded,
    0xe56c: Icons.restaurant_rounded,
    0xe318: Icons.home_rounded,
    0xe3ab: Icons.local_gas_station_rounded,
    0xe415: Icons.movie_rounded,
    0xe25b: Icons.favorite_rounded,
    0xe6b4: Icons.verified_user_rounded,
    0xe5ee: Icons.sports_tennis_rounded,
    0xe13d: Icons.card_giftcard_rounded,
    0xe29e: Icons.flight_takeoff_rounded,
    0xe559: Icons.school_rounded,
    0xe10c: Icons.build_rounded,
    0xe3f8: Icons.monetization_on_rounded,
    0xe569: Icons.shopping_bag_rounded,
    0xe11d: Icons.business_rounded,
    0xe3ae: Icons.lock_rounded,
  };
  return iconMap[code] ?? Icons.account_balance_wallet_rounded;
}

// Data Models with Bulletproof JSON Serialization & Deserialization
class AccountItem {
  final String id;
  String name;
  double balance;
  IconData icon;
  Color iconBgColor;
  Color iconColor;
  final String? badgeText;
  bool isIgnored;
  int priority;

  AccountItem({
    required this.id,
    required this.name,
    required this.balance,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.badgeText,
    this.isIgnored = false,
    this.priority = 99,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'balance': balance,
        'iconCode': icon.codePoint,
        'iconBgColor': iconBgColor.value,
        'iconColor': iconColor.value,
        'badgeText': badgeText,
        'isIgnored': isIgnored,
        'priority': priority,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) => AccountItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
        icon: _getIconFromCode(int.tryParse(json['iconCode']?.toString() ?? '')),
        iconBgColor: Color(int.tryParse(json['iconBgColor']?.toString() ?? '') ?? 0xFFE0F2FE),
        iconColor: Color(int.tryParse(json['iconColor']?.toString() ?? '') ?? 0xFF0369A1),
        badgeText: json['badgeText']?.toString(),
        isIgnored: json['isIgnored'] == true,
        priority: json['priority'] != null ? (int.tryParse(json['priority'].toString()) ?? 99) : 99,
      );
}

class CategoryItem {
  final String id;
  String name;
  String type; // 'INCOME' or 'EXPENSE'
  IconData icon;
  Color bgColor;

  CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.bgColor,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'iconCode': icon.codePoint,
        'bgColor': bgColor.value,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'EXPENSE',
        icon: _getIconFromCode(int.tryParse(json['iconCode']?.toString() ?? '')),
        bgColor: Color(int.tryParse(json['bgColor']?.toString() ?? '') ?? 0xFF1F4E3D),
      );
}

class TransactionRecord {
  final String id;
  String type; // 'INCOME', 'EXPENSE', 'TRANSFER'
  String accountName;
  String category;
  double amount;
  String notes;
  DateTime dateTime;

  TransactionRecord({
    required this.id,
    required this.type,
    required this.accountName,
    required this.category,
    required this.amount,
    required this.notes,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'accountName': accountName,
        'category': category,
        'amount': amount,
        'notes': notes,
        'dateTime': dateTime.toIso8601String(),
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) => TransactionRecord(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'EXPENSE',
        accountName: json['accountName']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
        notes: json['notes']?.toString() ?? '',
        dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
      );
}

class BudgetItem {
  final String id;
  String categoryName;
  double limitAmount;
  int month;
  int year;

  BudgetItem({
    required this.id,
    required this.categoryName,
    required this.limitAmount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryName': categoryName,
        'limitAmount': limitAmount,
        'month': month,
        'year': year,
      };

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        categoryName: json['categoryName']?.toString() ?? '',
        limitAmount: double.tryParse(json['limitAmount']?.toString() ?? '0') ?? 0.0,
        month: int.tryParse(json['month']?.toString() ?? '') ?? DateTime.now().month,
        year: int.tryParse(json['year']?.toString() ?? '') ?? DateTime.now().year,
      );
}

class MonthlyReportData {
  final String month;
  final int monthIndex;
  final double income;
  final double expense;

  double get balance => income - expense;

  MonthlyReportData({
    required this.month,
    required this.monthIndex,
    required this.income,
    required this.expense,
  });
}

class AccountMonthSummary {
  final double openingBalance;
  final double income;
  final double expense;
  final double closingBalance;

  AccountMonthSummary({
    required this.openingBalance,
    required this.income,
    required this.expense,
    required this.closingBalance,
  });
}

String? getTransferToAccountGlobal(TransactionRecord rec) {
  if (rec.type != 'TRANSFER') return null;
  if (rec.category.startsWith('Transfer to ')) {
    final toAcc = rec.category.substring('Transfer to '.length).trim();
    if (toAcc.isNotEmpty) return toAcc;
  }
  if (rec.category.contains(' > ')) {
    final parts = rec.category.replaceAll('[', '').replaceAll(']', '').split(' > ');
    if (parts.length > 1 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
  }
  if (rec.notes.contains(' to ')) {
    final clean = rec.notes.split('•').first.trim();
    final parts = clean.split(' to ');
    if (parts.length > 1 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
  }
  return null;
}

bool isTransferToAccountGlobal(TransactionRecord rec, String accountName) {
  final toAcc = getTransferToAccountGlobal(rec);
  if (toAcc == null) return false;
  return toAcc.trim().toLowerCase() == accountName.trim().toLowerCase();
}

class MyMoneyMainScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleTheme;

  const MyMoneyMainScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MyMoneyMainScreen> createState() => _MyMoneyMainScreenState();
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final String centerLabel;

  DonutChartPainter({
    required this.values,
    required this.colors,
    required this.centerLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.fold(0.0, (a, b) => a + b) <= 0) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 14, paint);
      return;
    }

    final total = values.fold(0.0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.butt;

    double startAngle = -3.1415926535 / 2;
    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * 3.1415926535;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => true;
}

class _MyMoneyMainScreenState extends State<MyMoneyMainScreen> {
  int _currentTabIndex = 0; // Reports tab default
  String _selectedCurrency = '₹ INR';
  bool _isPasscodeEnabled = false;
  bool _isDailyReminderEnabled = true;
  String _analysisOverviewType = 'EXPENSE OVERVIEW';

  int _reminderHour = 20;
  int _reminderMinute = 0;

  // Selected Report Options
  String _selectedReportType = 'YEARLY REPORT';
  int _selectedYear = DateTime.now().year;
  int _selectedDetailMonth = DateTime.now().month;
  bool _isLoadingLocalData = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Accounts list maintained in mobile & web local memory
  List<AccountItem> _accounts = [];

  // Transaction records list maintained in mobile & web local memory
  List<TransactionRecord> _records = [];

  // Categories list maintained in mobile & web local memory
  List<CategoryItem> _categories = [
    CategoryItem(id: 'c1', name: 'Opening Balance', type: 'INCOME', icon: Icons.account_balance, bgColor: const Color(0xFF0369A1)),
    CategoryItem(id: 'c2', name: 'Salary', type: 'INCOME', icon: Icons.payments_rounded, bgColor: const Color(0xFF166534)),
    CategoryItem(id: 'c3', name: 'Bonus & Profit', type: 'INCOME', icon: Icons.trending_up_rounded, bgColor: const Color(0xFF6B21A8)),
    CategoryItem(id: 'c4', name: 'Round off', type: 'EXPENSE', icon: Icons.percent_rounded, bgColor: const Color(0xFFB91C1C)),
    CategoryItem(id: 'c5', name: 'Rent', type: 'EXPENSE', icon: Icons.home_rounded, bgColor: const Color(0xFF854D0E)),
    CategoryItem(id: 'c6', name: 'Food', type: 'EXPENSE', icon: Icons.restaurant_rounded, bgColor: const Color(0xFFB91C1C)),
    CategoryItem(id: 'c7', name: 'Electricity', type: 'EXPENSE', icon: Icons.content_cut_rounded, bgColor: const Color(0xFFC2410C)),
    CategoryItem(id: 'c8', name: 'Travel', type: 'EXPENSE', icon: Icons.directions_car_rounded, bgColor: const Color(0xFF6B21A8)),
    CategoryItem(id: 'c9', name: 'Shopping', type: 'EXPENSE', icon: Icons.shopping_cart_rounded, bgColor: const Color(0xFF0284C7)),
    CategoryItem(id: 'c10', name: 'Other Expense', type: 'EXPENSE', icon: Icons.build_rounded, bgColor: const Color(0xFF475569)),
  ];

  // Monthly budgets maintained in local memory
  List<BudgetItem> _budgets = [
    BudgetItem(id: 'b1', categoryName: 'Travel', limitAmount: 1000.0, month: 8, year: 2026),
    BudgetItem(id: 'b2', categoryName: 'Food', limitAmount: 5000.0, month: 8, year: 2026),
    BudgetItem(id: 'b3', categoryName: 'Rent', limitAmount: 8000.0, month: 8, year: 2026),
    BudgetItem(id: 'b4', categoryName: 'Shopping', limitAmount: 6000.0, month: 8, year: 2026),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedDetailMonth = now.month;
    _loadDataFromLocalStorage();
  }

  // ==========================================================================
  // MOBILE & WEB LOCAL STORAGE SAVE & LOAD METHODS
  // ==========================================================================
  Future<void> _loadDataFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accountsJsonStr = prefs.getString('mymoney_accounts');
      final String? recordsJsonStr = prefs.getString('mymoney_records');
      final String? categoriesJsonStr = prefs.getString('mymoney_categories');
      final String? budgetsJsonStr = prefs.getString('mymoney_budgets');
      _isDailyReminderEnabled = prefs.getBool('daily_reminder_enabled') ?? true;
      _reminderHour = prefs.getInt('daily_reminder_hour') ?? 20;
      _reminderMinute = prefs.getInt('daily_reminder_minute') ?? 0;

      if (_isDailyReminderEnabled && !kIsWeb) {
        NotificationService().scheduleDailyNotification(_reminderHour, _reminderMinute);
      }

      if (accountsJsonStr != null && accountsJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(accountsJsonStr);
        _accounts = decodedList.map((item) => AccountItem.fromJson(item)).toList();
        _accounts.sort((a, b) => a.priority.compareTo(b.priority));
      }

      if (recordsJsonStr != null && recordsJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(recordsJsonStr);
        _records = decodedList.map((item) => TransactionRecord.fromJson(item)).toList();
      }

      if (_accounts.isNotEmpty && _records.isNotEmpty) {
        _syncAccountBalances();
      }

      if (categoriesJsonStr != null && categoriesJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(categoriesJsonStr);
        _categories = decodedList.map((item) => CategoryItem.fromJson(item)).toList();
      }

      if (budgetsJsonStr != null && budgetsJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(budgetsJsonStr);
        _budgets = decodedList.map((item) => BudgetItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading local storage: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocalData = false;
        });
      }
    }
  }

  Future<void> _saveDataToLocalStorage() async {
    try {
      _syncAccountBalances();
      final prefs = await SharedPreferences.getInstance();
      final accountsJsonStr = jsonEncode(_accounts.map((a) => a.toJson()).toList());
      final recordsJsonStr = jsonEncode(_records.map((r) => r.toJson()).toList());
      final categoriesJsonStr = jsonEncode(_categories.map((c) => c.toJson()).toList());
      final budgetsJsonStr = jsonEncode(_budgets.map((b) => b.toJson()).toList());

      await prefs.setString('mymoney_accounts', accountsJsonStr);
      await prefs.setString('mymoney_records', recordsJsonStr);
      await prefs.setString('mymoney_categories', categoriesJsonStr);
      await prefs.setString('mymoney_budgets', budgetsJsonStr);
      await prefs.setBool('daily_reminder_enabled', _isDailyReminderEnabled);
      await prefs.setInt('daily_reminder_hour', _reminderHour);
      await prefs.setInt('daily_reminder_minute', _reminderMinute);
    } catch (e) {
      debugPrint('Error saving local storage: $e');
    }
  }

  String? _getTransferToAccount(TransactionRecord rec) => getTransferToAccountGlobal(rec);

  bool _isTransferToAccount(TransactionRecord rec, String accountName) => isTransferToAccountGlobal(rec, accountName);

  void _syncAccountBalances() {
    for (var acc in _accounts) {
      final accNameLower = acc.name.trim().toLowerCase();
      final openingRecs = _records.where(
        (r) => r.accountName.trim().toLowerCase() == accNameLower && r.category == 'Opening Balance',
      ).toList();

      double openingBal = 0.0;
      if (openingRecs.isNotEmpty) {
        for (var op in openingRecs) {
          if (op.type == 'EXPENSE') {
            openingBal -= op.amount;
          } else {
            openingBal += op.amount;
          }
        }
      }

      double calculated = openingBal;
      for (var r in _records) {
        if (r.category == 'Opening Balance') continue;
        final rAccLower = r.accountName.trim().toLowerCase();
        if (rAccLower == accNameLower) {
          if (r.type == 'INCOME') calculated += r.amount;
          else if (r.type == 'EXPENSE') calculated -= r.amount;
          else if (r.type == 'TRANSFER') calculated -= r.amount;
        } else if (r.type == 'TRANSFER' && isTransferToAccountGlobal(r, acc.name)) {
          calculated += r.amount;
        }
      }
      acc.balance = calculated;
    }
  }


  // ==========================================================================
  // DYNAMIC COMPUTATION OF MONTHLY REPORT DATA FOR SELECTED YEAR
  // ==========================================================================
  List<MonthlyReportData> _getDynamicMonthlyReport(int targetYear) {
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    List<MonthlyReportData> result = [];
    final activeNames = _activeAccountNames;

    for (int m = 1; m <= 12; m++) {
      double monthIncome = 0.0;
      double monthExpense = 0.0;

      for (var r in _records) {
        if (r.dateTime.year == targetYear &&
            r.dateTime.month == m &&
            activeNames.contains(r.accountName)) {
          if (r.type == 'INCOME') {
            monthIncome += r.amount;
          } else if (r.type == 'EXPENSE') {
            monthExpense += r.amount;
          }
        }
      }

      result.add(MonthlyReportData(
        month: monthsNames[m - 1],
        monthIndex: m,
        income: monthIncome,
        expense: monthExpense,
      ));
    }

    return result;
  }

  double _calculateOpeningBalance(int targetYear, int targetMonth) {
    double currentTotal = _accounts.where((a) => !a.isIgnored).fold(0.0, (s, a) => s + a.balance);
    final targetDate = DateTime(targetYear, targetMonth, 1);
    final activeNames = _activeAccountNames;

    double netTransactionsOnOrAfterTarget = 0.0;
    for (var r in _records) {
      if (activeNames.contains(r.accountName) && !r.dateTime.isBefore(targetDate)) {
        if (r.type == 'INCOME') {
          netTransactionsOnOrAfterTarget += r.amount;
        } else if (r.type == 'EXPENSE') {
          netTransactionsOnOrAfterTarget -= r.amount;
        }
      }
    }
    return currentTotal - netTransactionsOnOrAfterTarget;
  }

  AccountMonthSummary _getAccountMonthSummary(AccountItem account, int targetYear, int targetMonth) {
    final targetDate = DateTime(targetYear, targetMonth, 1);

    double monthIncome = 0.0;
    double monthExpense = 0.0;

    for (var r in _records) {
      if (r.accountName == account.name) {
        if (r.dateTime.year == targetYear && r.dateTime.month == targetMonth) {
          if (r.type == 'INCOME') {
            monthIncome += r.amount;
          } else if (r.type == 'EXPENSE') {
            monthExpense += r.amount;
          }
        }
      }
    }

    double netOnOrAfter = 0.0;
    for (var r in _records) {
      if (r.accountName == account.name && !r.dateTime.isBefore(targetDate)) {
        if (r.type == 'INCOME') {
          netOnOrAfter += r.amount;
        } else if (r.type == 'EXPENSE') {
          netOnOrAfter -= r.amount;
        }
      }
    }

    double openingBal = account.balance - netOnOrAfter;
    double closingBal = openingBal + monthIncome - monthExpense;

    return AccountMonthSummary(
      openingBalance: openingBal,
      income: monthIncome,
      expense: monthExpense,
      closingBalance: closingBal,
    );
  }

  Set<String> get _activeAccountNames => _accounts
      .where((a) => !a.isIgnored)
      .map((a) => a.name)
      .toSet();

  double get _totalExpense => _records
      .where((r) => r.type == 'EXPENSE' && _activeAccountNames.contains(r.accountName))
      .fold(0.0, (sum, r) => sum + r.amount);

  double get _totalIncome => _records
      .where((r) => r.type == 'INCOME' && _activeAccountNames.contains(r.accountName))
      .fold(0.0, (sum, r) => sum + r.amount);

  double get _totalBalance => _accounts
      .where((a) => !a.isIgnored)
      .fold(0.0, (sum, account) => sum + account.balance);

  // ==========================================================================
  // ADD NEW CATEGORY DIALOG
  // ==========================================================================
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedType = 'EXPENSE';
    IconData selectedIcon = Icons.directions_car_rounded;
    Color selectedColor = const Color(0xFF6B21A8);

    final availableIcons = [
      {'icon': Icons.directions_car_rounded, 'color': const Color(0xFF6B21A8)},
      {'icon': Icons.checkroom_rounded, 'color': const Color(0xFFEA580C)},
      {'icon': Icons.restaurant_rounded, 'color': const Color(0xFFB91C1C)},
      {'icon': Icons.home_rounded, 'color': const Color(0xFF854D0E)},
      {'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFF0284C7)},
      {'icon': Icons.local_gas_station_rounded, 'color': const Color(0xFFD97706)},
      {'icon': Icons.movie_rounded, 'color': const Color(0xFF4338CA)},
      {'icon': Icons.favorite_rounded, 'color': const Color(0xFFDC2626)},
      {'icon': Icons.verified_user_rounded, 'color': const Color(0xFFD97706)},
      {'icon': Icons.sports_tennis_rounded, 'color': const Color(0xFF15803D)},
      {'icon': Icons.payments_rounded, 'color': const Color(0xFF166534)},
      {'icon': Icons.card_giftcard_rounded, 'color': const Color(0xFFC2410C)},
      {'icon': Icons.flight_takeoff_rounded, 'color': const Color(0xFF0284C7)},
      {'icon': Icons.school_rounded, 'color': const Color(0xFF4338CA)},
      {'icon': Icons.build_rounded, 'color': const Color(0xFF475569)},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
            ),
            title: const Text(
              'Add new category',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Type:  ',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'INCOME'),
                        child: Row(
                          children: [
                            if (selectedType == 'INCOME')
                              const Icon(Icons.check, color: Color(0xFF1F4E3D), size: 18),
                            if (selectedType == 'INCOME') const SizedBox(width: 4),
                            Text(
                              'INCOME',
                              style: TextStyle(
                                color: const Color(0xFF1F4E3D),
                                fontWeight: selectedType == 'INCOME' ? FontWeight.bold : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'EXPENSE'),
                        child: Row(
                          children: [
                            if (selectedType == 'EXPENSE')
                              const Icon(Icons.check, color: Color(0xFF1F4E3D), size: 18),
                            if (selectedType == 'EXPENSE') const SizedBox(width: 4),
                            Text(
                              'EXPENSE',
                              style: TextStyle(
                                color: const Color(0xFF1F4E3D),
                                fontWeight: selectedType == 'EXPENSE' ? FontWeight.bold : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text(
                        'Name  ',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Vegetables, Bonus',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            fillColor: const Color(0xFFFDF6D8),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F4E3D)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F4E3D), width: 1.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Icon',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF6D8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F4E3D)),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableIcons.map((item) {
                        final IconData ic = item['icon'] as IconData;
                        final Color col = item['color'] as Color;
                        final bool isSel = selectedIcon == ic;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = ic;
                              selectedColor = col;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? const Color(0xFF1F4E3D) : Colors.transparent,
                                width: isSel ? 3.5 : 0,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1F4E3D).withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: col,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    ic,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  if (isSel)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black38,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F4E3D),
                  side: const BorderSide(color: Color(0xFF1F4E3D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    setState(() {
                      _categories.add(
                        CategoryItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text,
                          type: selectedType,
                          icon: selectedIcon,
                          bgColor: selectedColor,
                        ),
                      );
                    });
                    _saveDataToLocalStorage();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Category "${nameController.text}" saved to local memory!')),
                    );
                  }
                },
                child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCategoryDialog(CategoryItem category) {
    final nameController = TextEditingController(text: category.name);
    String selectedType = category.type;
    IconData selectedIcon = category.icon;
    Color selectedColor = category.bgColor;

    final availableIcons = [
      {'icon': Icons.directions_car_rounded, 'color': const Color(0xFF6B21A8)},
      {'icon': Icons.checkroom_rounded, 'color': const Color(0xFFEA580C)},
      {'icon': Icons.restaurant_rounded, 'color': const Color(0xFFB91C1C)},
      {'icon': Icons.home_rounded, 'color': const Color(0xFF854D0E)},
      {'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFF0284C7)},
      {'icon': Icons.local_gas_station_rounded, 'color': const Color(0xFFD97706)},
      {'icon': Icons.movie_rounded, 'color': const Color(0xFF4338CA)},
      {'icon': Icons.favorite_rounded, 'color': const Color(0xFFDC2626)},
      {'icon': Icons.verified_user_rounded, 'color': const Color(0xFFD97706)},
      {'icon': Icons.sports_tennis_rounded, 'color': const Color(0xFF15803D)},
      {'icon': Icons.payments_rounded, 'color': const Color(0xFF166534)},
      {'icon': Icons.card_giftcard_rounded, 'color': const Color(0xFFC2410C)},
      {'icon': Icons.flight_takeoff_rounded, 'color': const Color(0xFF0284C7)},
      {'icon': Icons.school_rounded, 'color': const Color(0xFF4338CA)},
      {'icon': Icons.build_rounded, 'color': const Color(0xFF475569)},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
            ),
            title: const Text(
              'Edit Category',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Type:  ',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'INCOME'),
                        child: Row(
                          children: [
                            if (selectedType == 'INCOME')
                              const Icon(Icons.check, color: Color(0xFF1F4E3D), size: 18),
                            if (selectedType == 'INCOME') const SizedBox(width: 4),
                            Text(
                              'INCOME',
                              style: TextStyle(
                                color: const Color(0xFF1F4E3D),
                                fontWeight: selectedType == 'INCOME' ? FontWeight.bold : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => setDialogState(() => selectedType = 'EXPENSE'),
                        child: Row(
                          children: [
                            if (selectedType == 'EXPENSE')
                              const Icon(Icons.check, color: Color(0xFF1F4E3D), size: 18),
                            if (selectedType == 'EXPENSE') const SizedBox(width: 4),
                            Text(
                              'EXPENSE',
                              style: TextStyle(
                                color: const Color(0xFF1F4E3D),
                                fontWeight: selectedType == 'EXPENSE' ? FontWeight.bold : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text(
                        'Name  ',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Vegetables, Bonus',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            fillColor: const Color(0xFFFDF6D8),
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F4E3D)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F4E3D), width: 1.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Icon',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF6D8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F4E3D)),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableIcons.map((item) {
                        final IconData ic = item['icon'] as IconData;
                        final Color col = item['color'] as Color;
                        final bool isSel = selectedIcon == ic;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = ic;
                              selectedColor = col;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? const Color(0xFF1F4E3D) : Colors.transparent,
                                width: isSel ? 3.5 : 0,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1F4E3D).withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: col,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    ic,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  if (isSel)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black38,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F4E3D),
                  side: const BorderSide(color: Color(0xFF1F4E3D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    final oldName = category.name;
                    setState(() {
                      category.name = newName;
                      category.type = selectedType;
                      category.icon = selectedIcon;
                      category.bgColor = selectedColor;

                      for (var r in _records) {
                        if (r.category == oldName) {
                          r.category = newName;
                        }
                      }
                    });
                    _saveDataToLocalStorage();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Category "$newName" updated & saved!')),
                    );
                  }
                },
                child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateTransactionAccountCategory(TransactionRecord record, String newAccountName, String newCategory) {
    setState(() {
      if (newAccountName != record.accountName) {
        if (record.type == 'TRANSFER') {
          final oldFromIdx = _accounts.indexWhere((a) => a.name == record.accountName);
          if (oldFromIdx != -1) _accounts[oldFromIdx].balance += record.amount;
          final newFromIdx = _accounts.indexWhere((a) => a.name == newAccountName);
          if (newFromIdx != -1) _accounts[newFromIdx].balance -= record.amount;
          record.accountName = newAccountName;
          final toName = _getTransferToAccount(record) ?? '';
          record.notes = 'Transfer from $newAccountName to $toName';
        } else {
          final oldAccIdx = _accounts.indexWhere((a) => a.name == record.accountName);
          if (oldAccIdx != -1) {
            if (record.type == 'EXPENSE') {
              _accounts[oldAccIdx].balance += record.amount;
            } else if (record.type == 'INCOME') {
              _accounts[oldAccIdx].balance -= record.amount;
            }
          }
          final newAccIdx = _accounts.indexWhere((a) => a.name == newAccountName);
          if (newAccIdx != -1) {
            if (record.type == 'EXPENSE') {
              _accounts[newAccIdx].balance -= record.amount;
            } else if (record.type == 'INCOME') {
              _accounts[newAccIdx].balance += record.amount;
            }
          }
          record.accountName = newAccountName;
        }
      }
      record.category = newCategory;
      _syncAccountBalances();
    });
    _saveDataToLocalStorage();
  }

  void _openAccountDetailsScreen(AccountItem account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountDetailsScreen(
          account: account,
          accounts: _accounts,
          allRecords: _records,
          categories: _categories,
          onDeleteRecord: (rec) => _deleteTransaction(rec),
          onEditRecord: (rec) => _showEditTransactionDialog(rec),
          onDuplicateRecord: (rec) => _duplicateTransaction(rec),
          onUpdateRecord: _updateTransactionAccountCategory,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showMonthBreakdownDialog(String monthName, int monthIndex, {String filterType = 'ALL'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsScreen(
          categoryName: filterType == 'ALL' ? 'Monthly All Records' : '$filterType Records',
          type: filterType,
          month: monthIndex,
          year: _selectedYear,
          accounts: _accounts,
          allRecords: _records,
          categories: _categories,
          onDeleteRecord: (rec) => _deleteTransaction(rec),
          onEditRecord: (rec) => _showEditTransactionDialog(rec),
          onDuplicateRecord: (rec) => _duplicateTransaction(rec),
          onUpdateRecord: _updateTransactionAccountCategory,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showCategoryBreakdownDialog(String categoryName, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailsScreen(
          categoryName: categoryName,
          type: type,
          month: _selectedDetailMonth,
          year: _selectedYear,
          accounts: _accounts,
          allRecords: _records,
          categories: _categories,
          onDeleteRecord: (rec) => _deleteTransaction(rec),
          onEditRecord: (rec) => _showEditTransactionDialog(rec),
          onDuplicateRecord: (rec) => _duplicateTransaction(rec),
          onUpdateRecord: _updateTransactionAccountCategory,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _duplicateTransaction(TransactionRecord rec) {
    final dup = TransactionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: rec.type,
      amount: rec.amount,
      category: rec.category,
      accountName: rec.accountName,
      dateTime: DateTime.now(),
      notes: rec.notes,
    );
    _addTransaction(dup, toAccountName: _getTransferToAccount(rec));
  }

  // ==========================================================================
  // TRANSACTION CRUD & TRANSFER OPERATIONS WITH AUTO-SAVE TO LOCAL MEMORY
  // ==========================================================================
  void _addTransaction(TransactionRecord record, {String? toAccountName}) {
    setState(() {
      _records.add(record);

      final destAccount = toAccountName ?? _getTransferToAccount(record);
      if (record.type == 'TRANSFER' && destAccount != null) {
        final fromIdx = _accounts.indexWhere((a) => a.name == record.accountName);
        if (fromIdx != -1) {
          _accounts[fromIdx].balance -= record.amount;
        }
        final toIdx = _accounts.indexWhere((a) => a.name == destAccount);
        if (toIdx != -1) {
          _accounts[toIdx].balance += record.amount;
        }
      } else {
        final index = _accounts.indexWhere((a) => a.name == record.accountName);
        if (index != -1) {
          if (record.type == 'EXPENSE') {
            _accounts[index].balance -= record.amount;
          } else if (record.type == 'INCOME') {
            _accounts[index].balance += record.amount;
          }
        }
      }
      _syncAccountBalances();
    });

    _saveDataToLocalStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${record.type} of ₹${record.amount.toStringAsFixed(0)} saved to local memory!'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _deleteTransaction(TransactionRecord record) {
    setState(() {
      if (record.type == 'TRANSFER') {
        final fromIdx = _accounts.indexWhere((a) => a.name == record.accountName);
        if (fromIdx != -1) {
          _accounts[fromIdx].balance += record.amount;
        }
        final toName = _getTransferToAccount(record);
        if (toName != null) {
          final toIdx = _accounts.indexWhere((a) => a.name == toName);
          if (toIdx != -1) {
            _accounts[toIdx].balance -= record.amount;
          }
        }
      } else {
        final index = _accounts.indexWhere((a) => a.name == record.accountName);
        if (index != -1) {
          if (record.type == 'EXPENSE') {
            _accounts[index].balance += record.amount;
          } else if (record.type == 'INCOME') {
            _accounts[index].balance -= record.amount;
          }
        }
      }

      _records.removeWhere((r) => r.id == record.id);
      _syncAccountBalances();
    });

    _saveDataToLocalStorage();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted! Local memory updated.')),
    );
  }

  Future<void> _showEditTransactionDialog(TransactionRecord record) async {
    final amountController = TextEditingController(text: record.amount.toStringAsFixed(0));
    
    // Clean raw notes for editing
    String initialNotes = record.notes;
    if (record.type == 'TRANSFER') {
      if (initialNotes.contains('•')) {
        final parts = initialNotes.split('•');
        initialNotes = parts.sublist(1).join('•').trim();
      } else if (initialNotes.startsWith('Transfer from ')) {
        initialNotes = '';
      }
    }
    final notesController = TextEditingController(text: initialNotes);
    String editType = record.type;
    String editAccount = _accounts.any((a) => a.name == record.accountName)
        ? record.accountName
        : (_accounts.isNotEmpty ? _accounts.first.name : record.accountName);

    String? initialToAcc = _getTransferToAccount(record);
    String editToAccount = (initialToAcc != null && _accounts.any((a) => a.name == initialToAcc))
        ? initialToAcc
        : (_accounts.where((a) => a.name != editAccount).isNotEmpty
            ? _accounts.where((a) => a.name != editAccount).first.name
            : (_accounts.isNotEmpty ? _accounts.first.name : ''));

    String editCategory = _categories.any((c) => c.name == record.category)
        ? record.category
        : (_categories.where((c) => c.type == editType).isNotEmpty
            ? _categories.where((c) => c.type == editType).first.name
            : (_categories.isNotEmpty ? _categories.first.name : record.category));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matchingCategories = _categories.where((c) => c.type == editType).toList();
          final categoryOptions = matchingCategories.isNotEmpty ? matchingCategories : _categories;

          if (!categoryOptions.any((c) => c.name == editCategory) && categoryOptions.isNotEmpty) {
            editCategory = categoryOptions.first.name;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ChoiceChip(
                        label: const Text('EXPENSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: editType == 'EXPENSE',
                        selectedColor: const Color(0xFFFEE2E2),
                        onSelected: (val) {
                          setDialogState(() {
                            editType = 'EXPENSE';
                            final cats = _categories.where((c) => c.type == 'EXPENSE').toList();
                            if (cats.isNotEmpty) editCategory = cats.first.name;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('INCOME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: editType == 'INCOME',
                        selectedColor: const Color(0xFFDCFCE7),
                        onSelected: (val) {
                          setDialogState(() {
                            editType = 'INCOME';
                            final cats = _categories.where((c) => c.type == 'INCOME').toList();
                            if (cats.isNotEmpty) editCategory = cats.first.name;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('TRANSFER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: editType == 'TRANSFER',
                        selectedColor: const Color(0xFFDBEAFE),
                        onSelected: (val) {
                          setDialogState(() {
                            editType = 'TRANSFER';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (editType == 'TRANSFER') ...[
                    if (_accounts.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _accounts.any((a) => a.name == editAccount) ? editAccount : _accounts.first.name,
                        decoration: const InputDecoration(
                          labelText: 'From Account (Source)',
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                          ),
                        ),
                        items: _accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.name,
                            child: Row(
                              children: [
                                Icon(acc.icon, color: acc.iconColor, size: 18),
                                const SizedBox(width: 8),
                                Text(acc.name, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => editAccount = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _accounts.any((a) => a.name == editToAccount)
                            ? editToAccount
                            : (_accounts.where((a) => a.name != editAccount).isNotEmpty
                                ? _accounts.where((a) => a.name != editAccount).first.name
                                : _accounts.first.name),
                        decoration: const InputDecoration(
                          labelText: 'To Account (Destination)',
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                          ),
                        ),
                        items: _accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.name,
                            child: Row(
                              children: [
                                Icon(acc.icon, color: acc.iconColor, size: 18),
                                const SizedBox(width: 8),
                                Text(acc.name, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => editToAccount = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else ...[
                    if (_accounts.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _accounts.any((a) => a.name == editAccount) ? editAccount : _accounts.first.name,
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                          ),
                        ),
                        items: _accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.name,
                            child: Row(
                              children: [
                                Icon(acc.icon, color: acc.iconColor, size: 18),
                                const SizedBox(width: 8),
                                Text(acc.name, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => editAccount = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (categoryOptions.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: categoryOptions.any((c) => c.name == editCategory) ? editCategory : categoryOptions.first.name,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                          ),
                        ),
                        items: categoryOptions.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.name,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor: cat.bgColor,
                                  child: Icon(cat.icon, size: 11, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(cat.name, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => editCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final newAmount = double.tryParse(amountController.text) ?? record.amount;
                  if (newAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an amount greater than 0')),
                    );
                    return;
                  }

                  if (editType == 'TRANSFER' && editAccount == editToAccount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Source and Destination accounts cannot be the same!')),
                    );
                    return;
                  }

                  setState(() {
                    // 1. Revert old transaction amount from old account balances
                    if (record.type == 'EXPENSE') {
                      final oldIdx = _accounts.indexWhere((a) => a.name == record.accountName);
                      if (oldIdx != -1) _accounts[oldIdx].balance += record.amount;
                    } else if (record.type == 'INCOME') {
                      final oldIdx = _accounts.indexWhere((a) => a.name == record.accountName);
                      if (oldIdx != -1) _accounts[oldIdx].balance -= record.amount;
                    } else if (record.type == 'TRANSFER') {
                      final oldFromIdx = _accounts.indexWhere((a) => a.name == record.accountName);
                      if (oldFromIdx != -1) _accounts[oldFromIdx].balance += record.amount;
                      final oldToName = _getTransferToAccount(record);
                      if (oldToName != null) {
                        final oldToIdx = _accounts.indexWhere((a) => a.name == oldToName);
                        if (oldToIdx != -1) _accounts[oldToIdx].balance -= record.amount;
                      }
                    }

                    // 2. Apply new transaction amount to new account balances
                    if (editType == 'EXPENSE') {
                      final newIdx = _accounts.indexWhere((a) => a.name == editAccount);
                      if (newIdx != -1) _accounts[newIdx].balance -= newAmount;
                    } else if (editType == 'INCOME') {
                      final newIdx = _accounts.indexWhere((a) => a.name == editAccount);
                      if (newIdx != -1) _accounts[newIdx].balance += newAmount;
                    } else if (editType == 'TRANSFER') {
                      final newFromIdx = _accounts.indexWhere((a) => a.name == editAccount);
                      if (newFromIdx != -1) _accounts[newFromIdx].balance -= newAmount;
                      final newToIdx = _accounts.indexWhere((a) => a.name == editToAccount);
                      if (newToIdx != -1) _accounts[newToIdx].balance += newAmount;
                    }

                    // 3. Update the record details
                    record.type = editType;
                    record.accountName = editAccount;
                    record.amount = newAmount;

                    final userNote = notesController.text.trim();
                    if (editType == 'TRANSFER') {
                      record.category = 'Transfer to $editToAccount';
                      record.notes = userNote.isNotEmpty
                          ? 'Transfer from $editAccount to $editToAccount • $userNote'
                          : 'Transfer from $editAccount to $editToAccount';
                    } else {
                      record.category = editCategory;
                      record.notes = userNote;
                    }

                    _syncAccountBalances();
                  });

                  _saveDataToLocalStorage();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction updated & balance reflected!')),
                  );
                },
                child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddTransactionModal() {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one account first before adding transactions!'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      _showAddAccountDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        accounts: _accounts.where((a) => !a.isIgnored).toList(),
        categories: _categories,
        onSaveWithToAccount: _addTransaction,
      ),
    );
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    final priorityController = TextEditingController(text: '1');
    DateTime selectedOpeningDate = DateTime.now();
    IconData selectedIcon = Icons.account_balance_wallet_rounded;
    Color selectedBgColor = const Color(0xFFE0F2FE);
    Color selectedIconColor = const Color(0xFF0369A1);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
            ),
            title: const Text(
              'Add New Account',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. HDFC Bank, Cash',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Initial Balance (₹)',
                      hintText: '0.00',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priorityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Priority Order (e.g. 1 = Top)',
                      hintText: '1',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Opening Date:',
                        style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedOpeningDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedOpeningDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7E6),
                            border: Border.all(color: const Color(0xFF1F4E3D)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1F4E3D)),
                              const SizedBox(width: 6),
                              Text(
                                '${selectedOpeningDate.day.toString().padLeft(2, '0')}/${selectedOpeningDate.month.toString().padLeft(2, '0')}/${selectedOpeningDate.year}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F4E3D)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Account Icon (20 Choices):',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF6D8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          {'icon': Icons.money_rounded, 'bgColor': const Color(0xFFDCFCE7), 'iconColor': const Color(0xFF166534), 'label': 'Cash'},
                          {'icon': Icons.credit_card_rounded, 'bgColor': const Color(0xFFE0F2FE), 'iconColor': const Color(0xFF0369A1), 'label': 'Credit Card'},
                          {'icon': Icons.savings_rounded, 'bgColor': const Color(0xFFFFEDD5), 'iconColor': const Color(0xFFC2410C), 'label': 'Savings'},
                          {'icon': Icons.account_balance_wallet_rounded, 'bgColor': const Color(0xFFFEF3C7), 'iconColor': const Color(0xFFD97706), 'label': 'Wallet'},
                          {'icon': Icons.account_balance_rounded, 'bgColor': const Color(0xFFE0E7FF), 'iconColor': const Color(0xFF3730A3), 'label': 'Bank'},
                          {'icon': Icons.trending_up_rounded, 'bgColor': const Color(0xFFF3E8FF), 'iconColor': const Color(0xFF6B21A8), 'label': 'Stocks'},
                          {'icon': Icons.qr_code_scanner_rounded, 'bgColor': const Color(0xFFD1FAE5), 'iconColor': const Color(0xFF047857), 'label': 'UPI'},
                          {'icon': Icons.monetization_on_rounded, 'bgColor': const Color(0xFFFEF08A), 'iconColor': const Color(0xFF854D0E), 'label': 'Gold'},
                          {'icon': Icons.phone_android_rounded, 'bgColor': const Color(0xFFCFFAFE), 'iconColor': const Color(0xFF0E7490), 'label': 'Mobile Pay'},
                          {'icon': Icons.business_center_rounded, 'bgColor': const Color(0xFFF1F5F9), 'iconColor': const Color(0xFF334155), 'label': 'Business'},
                          {'icon': Icons.lock_rounded, 'bgColor': const Color(0xFFCCFBF1), 'iconColor': const Color(0xFF0F766E), 'label': 'Emergency'},
                          {'icon': Icons.card_giftcard_rounded, 'bgColor': const Color(0xFFFCE7F3), 'iconColor': const Color(0xFFBE185D), 'label': 'Rewards'},
                          {'icon': Icons.flight_takeoff_rounded, 'bgColor': const Color(0xFFBAE6FD), 'iconColor': const Color(0xFF0284C7), 'label': 'Travel'},
                          {'icon': Icons.other_houses_rounded, 'bgColor': const Color(0xFFFFE4E6), 'iconColor': const Color(0xFFBE123C), 'label': 'Property'},
                          {'icon': Icons.receipt_long_rounded, 'bgColor': const Color(0xFFFEF3C7), 'iconColor': const Color(0xFFB45309), 'label': 'Bills'},
                          {'icon': Icons.lightbulb_rounded, 'bgColor': const Color(0xFFFEF9C3), 'iconColor': const Color(0xFFA16207), 'label': 'Utilities'},
                          {'icon': Icons.school_rounded, 'bgColor': const Color(0xFFDDD6FE), 'iconColor': const Color(0xFF6D28D9), 'label': 'Education'},
                          {'icon': Icons.inventory_2_rounded, 'bgColor': const Color(0xFFFFEDD5), 'iconColor': const Color(0xFF9A3412), 'label': 'FD Deposit'},
                          {'icon': Icons.flash_on_rounded, 'bgColor': const Color(0xFFE0F2FE), 'iconColor': const Color(0xFF0284C7), 'label': 'UPI Lite'},
                          {'icon': Icons.currency_exchange_rounded, 'bgColor': const Color(0xFFCCFBF1), 'iconColor': const Color(0xFF115E59), 'label': 'Forex'},
                        ].map((item) {
                          final IconData ic = item['icon'] as IconData;
                          final Color bgCol = item['bgColor'] as Color;
                          final Color icCol = item['iconColor'] as Color;
                          final String lbl = item['label'] as String;
                          final bool isSel = selectedIcon == ic;

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedIcon = ic;
                                selectedBgColor = bgCol;
                                selectedIconColor = icCol;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: bgCol,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF1F4E3D) : Colors.transparent,
                                  width: isSel ? 2.5 : 0,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1F4E3D).withOpacity(0.35),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(ic, color: icCol, size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    lbl,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                      color: icCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    final initialBal = double.tryParse(balanceController.text) ?? 0.0;
                    final accountPriority = int.tryParse(priorityController.text) ?? 99;
                    final accountId = DateTime.now().millisecondsSinceEpoch.toString();
                    final accName = nameController.text.trim();

                    setState(() {
                      _accounts.add(
                        AccountItem(
                          id: accountId,
                          name: accName,
                          balance: initialBal,
                          icon: selectedIcon,
                          iconBgColor: selectedBgColor,
                          iconColor: selectedIconColor,
                          priority: accountPriority,
                        ),
                      );

                      _accounts.sort((a, b) => a.priority.compareTo(b.priority));

                      if (initialBal != 0) {
                        _records.add(
                          TransactionRecord(
                            id: 'init_$accountId',
                            type: initialBal >= 0 ? 'INCOME' : 'EXPENSE',
                            accountName: accName,
                            category: 'Opening Balance',
                            amount: initialBal.abs(),
                            notes: 'Initial Account Balance',
                            dateTime: selectedOpeningDate,
                          ),
                        );
                      }
                    });
                    _saveDataToLocalStorage();
                    Navigator.pop(context);
                  }
                },
                child: const Text('ADD ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditAccountDialog(AccountItem account) {
    final existingOpeningIndex = _records.indexWhere((r) => r.accountName == account.name && r.category == 'Opening Balance');
    final existingOpeningRec = existingOpeningIndex != -1 ? _records[existingOpeningIndex] : null;

    final nameController = TextEditingController(text: account.name);
    final initialBalVal = existingOpeningRec != null
        ? (existingOpeningRec.type == 'EXPENSE' ? -existingOpeningRec.amount : existingOpeningRec.amount)
        : 0.0;
    final balanceController = TextEditingController(text: initialBalVal.toStringAsFixed(2));
    final priorityController = TextEditingController(text: account.priority.toString());
    DateTime selectedOpeningDate = existingOpeningRec != null ? existingOpeningRec.dateTime : DateTime.now();
    IconData selectedIcon = account.icon;
    Color selectedBgColor = account.iconBgColor;
    Color selectedIconColor = account.iconColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
          ),
          title: Text(
            'Edit ${account.name}',
            style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Opening Balance (₹)',
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priorityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Priority Order (e.g. 1 = Top)',
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1F4E3D)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Opening Date:',
                      style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedOpeningDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedOpeningDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7E6),
                          border: Border.all(color: const Color(0xFF1F4E3D)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1F4E3D)),
                            const SizedBox(width: 6),
                            Text(
                              '${selectedOpeningDate.day.toString().padLeft(2, '0')}/${selectedOpeningDate.month.toString().padLeft(2, '0')}/${selectedOpeningDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F4E3D)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Account Icon (20 Choices):',
                  style: TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF6D8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        {'icon': Icons.money_rounded, 'bgColor': const Color(0xFFDCFCE7), 'iconColor': const Color(0xFF166534), 'label': 'Cash'},
                        {'icon': Icons.credit_card_rounded, 'bgColor': const Color(0xFFE0F2FE), 'iconColor': const Color(0xFF0369A1), 'label': 'Credit Card'},
                        {'icon': Icons.savings_rounded, 'bgColor': const Color(0xFFFFEDD5), 'iconColor': const Color(0xFFC2410C), 'label': 'Savings'},
                        {'icon': Icons.account_balance_wallet_rounded, 'bgColor': const Color(0xFFFEF3C7), 'iconColor': const Color(0xFFD97706), 'label': 'Wallet'},
                        {'icon': Icons.account_balance_rounded, 'bgColor': const Color(0xFFE0E7FF), 'iconColor': const Color(0xFF3730A3), 'label': 'Bank'},
                        {'icon': Icons.trending_up_rounded, 'bgColor': const Color(0xFFF3E8FF), 'iconColor': const Color(0xFF6B21A8), 'label': 'Stocks'},
                        {'icon': Icons.qr_code_scanner_rounded, 'bgColor': const Color(0xFFD1FAE5), 'iconColor': const Color(0xFF047857), 'label': 'UPI'},
                        {'icon': Icons.monetization_on_rounded, 'bgColor': const Color(0xFFFEF08A), 'iconColor': const Color(0xFF854D0E), 'label': 'Gold'},
                        {'icon': Icons.phone_android_rounded, 'bgColor': const Color(0xFFCFFAFE), 'iconColor': const Color(0xFF0E7490), 'label': 'Mobile Pay'},
                        {'icon': Icons.business_center_rounded, 'bgColor': const Color(0xFFF1F5F9), 'iconColor': const Color(0xFF334155), 'label': 'Business'},
                        {'icon': Icons.lock_rounded, 'bgColor': const Color(0xFFCCFBF1), 'iconColor': const Color(0xFF0F766E), 'label': 'Emergency'},
                        {'icon': Icons.card_giftcard_rounded, 'bgColor': const Color(0xFFFCE7F3), 'iconColor': const Color(0xFFBE185D), 'label': 'Rewards'},
                        {'icon': Icons.flight_takeoff_rounded, 'bgColor': const Color(0xFFBAE6FD), 'iconColor': const Color(0xFF0284C7), 'label': 'Travel'},
                        {'icon': Icons.other_houses_rounded, 'bgColor': const Color(0xFFFFE4E6), 'iconColor': const Color(0xFFBE123C), 'label': 'Property'},
                        {'icon': Icons.receipt_long_rounded, 'bgColor': const Color(0xFFFEF3C7), 'iconColor': const Color(0xFFB45309), 'label': 'Bills'},
                        {'icon': Icons.lightbulb_rounded, 'bgColor': const Color(0xFFFEF9C3), 'iconColor': const Color(0xFFA16207), 'label': 'Utilities'},
                        {'icon': Icons.school_rounded, 'bgColor': const Color(0xFFDDD6FE), 'iconColor': const Color(0xFF6D28D9), 'label': 'Education'},
                        {'icon': Icons.inventory_2_rounded, 'bgColor': const Color(0xFFFFEDD5), 'iconColor': const Color(0xFF9A3412), 'label': 'FD Deposit'},
                        {'icon': Icons.flash_on_rounded, 'bgColor': const Color(0xFFE0F2FE), 'iconColor': const Color(0xFF0284C7), 'label': 'UPI Lite'},
                        {'icon': Icons.currency_exchange_rounded, 'bgColor': const Color(0xFFCCFBF1), 'iconColor': const Color(0xFF115E59), 'label': 'Forex'},
                      ].map((item) {
                        final IconData ic = item['icon'] as IconData;
                        final Color bgCol = item['bgColor'] as Color;
                        final Color icCol = item['iconColor'] as Color;
                        final String lbl = item['label'] as String;
                        final bool isSel = selectedIcon == ic;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = ic;
                              selectedBgColor = bgCol;
                              selectedIconColor = icCol;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: bgCol,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? const Color(0xFF1F4E3D) : Colors.transparent,
                                width: isSel ? 2.5 : 0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(ic, color: icCol, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  lbl,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: icCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E3D),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    final oldName = account.name;
                    final newName = nameController.text.trim();
                    final newOpeningBal = double.tryParse(balanceController.text) ?? account.balance;
                    final newPriority = int.tryParse(priorityController.text) ?? 99;

                    account.name = newName;
                    account.icon = selectedIcon;
                    account.iconBgColor = selectedBgColor;
                    account.iconColor = selectedIconColor;
                    account.priority = newPriority;

                    _accounts.sort((a, b) => a.priority.compareTo(b.priority));

                    for (var r in _records) {
                      if (r.accountName == oldName) {
                        r.accountName = newName;
                      }
                    }

                    if (newOpeningBal == 0) {
                      if (existingOpeningRec != null) {
                        _records.remove(existingOpeningRec);
                      }
                    } else {
                      if (existingOpeningRec != null) {
                        existingOpeningRec.accountName = newName;
                        existingOpeningRec.amount = newOpeningBal.abs();
                        existingOpeningRec.type = newOpeningBal >= 0 ? 'INCOME' : 'EXPENSE';
                        existingOpeningRec.dateTime = selectedOpeningDate;
                      } else {
                        _records.add(
                          TransactionRecord(
                            id: 'init_${account.id}',
                            type: newOpeningBal >= 0 ? 'INCOME' : 'EXPENSE',
                            accountName: newName,
                            category: 'Opening Balance',
                            amount: newOpeningBal.abs(),
                            notes: 'Initial Account Balance',
                            dateTime: selectedOpeningDate,
                          ),
                        );
                      }
                    }

                    _syncAccountBalances();
                  });
                  _saveDataToLocalStorage();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account updated & saved!')),
                  );
                }
              },
              child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirm(AccountItem account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
            SizedBox(width: 8),
            Text('Delete Account?', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${account.name}"? All associated transactions will also be deleted.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                final deletedName = account.name;
                _accounts.removeWhere((a) => a.id == account.id);
                _records.removeWhere((r) => r.accountName == deletedName);
              });
              _saveDataToLocalStorage();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${account.name} deleted & saved to local memory.')),
              );
            },
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildIconChoice({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1F4E3D) : Colors.transparent,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          selectedCurrency: _selectedCurrency,
          onCurrencyChanged: (curr) => setState(() => _selectedCurrency = curr),
          isPasscodeEnabled: _isPasscodeEnabled,
          onPasscodeToggled: (val) => setState(() => _isPasscodeEnabled = val),
          isDailyReminder: _isDailyReminderEnabled,
          onReminderToggled: (val) {
            setState(() => _isDailyReminderEnabled = val);
            _saveDataToLocalStorage();
          },
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
          onReminderTimeChanged: (h, m) {
            setState(() {
              _reminderHour = h;
              _reminderMinute = m;
            });
            _saveDataToLocalStorage();
          },
          accounts: _accounts,
          records: _records,
          categories: _categories,
          onRestoreBackup: (importedAccounts, importedRecords, importedCategories) {
            setState(() {
              _accounts = importedAccounts;
              _records = importedRecords;
              _categories = importedCategories;
            });
            _saveDataToLocalStorage();
          },
        ),
      ),
    );
  }

  void _showReportFormatPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Report Format',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reportFormatOption('YEARLY REPORT', 'Yearly Monthly Balance Summary', Icons.calendar_month_rounded),
                  _reportFormatOption('MONTHLY DETAILED REPORT', 'Detailed month-by-month breakdown', Icons.table_chart_rounded),
                  _reportFormatOption('DAY-WISE EXPENSE REPORT', 'Daily income, expense & balance breakdown', Icons.calendar_view_day_rounded),
                  _reportFormatOption('CATEGORY WISE REPORT', 'Expense breakdown by category', Icons.pie_chart_rounded),
                  _reportFormatOption('ACCOUNT WISE REPORT', 'Summary grouped by account', Icons.account_balance_wallet_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reportFormatOption(String title, String subtitle, IconData icon) {
    final bool isSelected = _selectedReportType == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFDF6D8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1F4E3D) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1F4E3D)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF1F4E3D)) : null,
        onTap: () {
          setState(() {
            _selectedReportType = title;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showYearPicker() {
    final years = [2026, 2025, 2024];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Year',
                style: TextStyle(
                  color: Color(0xFF1F4E3D),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ...years.map(
                (y) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _selectedYear == y ? const Color(0xFFFDF6D8) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedYear == y ? const Color(0xFF1F4E3D) : const Color(0xFFE2E8F0),
                      width: _selectedYear == y ? 1.8 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      '$y',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: _selectedYear == y ? const Icon(Icons.check, color: Color(0xFF1F4E3D)) : null,
                    onTap: () {
                      setState(() {
                        _selectedYear = y;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocalData) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7E6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1F4E3D)),
              const SizedBox(height: 16),
              Text(
                'Loading MyFinances data...',
                style: TextStyle(color: const Color(0xFF1F4E3D), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1F4E3D), size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'MyMoney',
          style: TextStyle(
            color: Color(0xFF1F4E3D),
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontFamily: 'serif',
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1F4E3D), size: 24),
            tooltip: 'Google Pay Statement Analyzer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyFinanceDashboardScreen(
                    existingAccountNames: _accounts.map((a) => a.name).toList(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1F4E3D), size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF1F4E3D), size: 26),
            onPressed: _openSettingsPage,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildReportsTab(),
          _buildAnalysisTab(),
          _buildBudgetsTab(),
          _buildAccountsTab(),
          _buildCategoriesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionModal,
        backgroundColor: const Color(0xFFFDF6D8),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
        ),
        elevation: 4,
        child: const Icon(Icons.add, color: Color(0xFF1F4E3D), size: 32),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1F4E3D), width: 0.8),
          ),
          color: Color(0xFFFAF7E6),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFAF7E6),
          selectedItemColor: const Color(0xFF1F4E3D),
          unselectedItemColor: const Color(0xFF6B7280),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Records',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.donut_large_outlined),
              activeIcon: Icon(Icons.donut_large),
              label: 'Analysis',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Budgets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.label_outlined),
              activeIcon: Icon(Icons.label),
              label: 'Categories',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFAF7E6),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1F4E3D)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Color(0xFFFDF6D8),
              child: Text(
                'MF',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D)),
              ),
            ),
            accountName: const Text('MyFinances User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text('Total Balance: ₹${_formatCurrency(_totalBalance)}'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF1F4E3D)),
            title: const Text('Yearly & Monthly Reports', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 0);
              Future.microtask(() => _showReportFormatPicker());
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF1F4E3D)),
            title: const Text('Accounts Manager', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined, color: Color(0xFF1F4E3D)),
            title: const Text('Financial Analysis', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 1);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1F4E3D)),
            title: const Text('Google Pay Statement Analyzer', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Analyze PDF statement & Finance Dashboard', style: TextStyle(fontSize: 11.5, color: Color(0xFF52796F))),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('NEW', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyFinanceDashboardScreen(
                    existingAccountNames: _accounts.map((a) => a.name).toList(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined, color: Color(0xFF1F4E3D)),
            title: const Text('Import Statement PDF', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImportStatementScreen(
                    existingAccountNames: _accounts.map((a) => a.name).toList(),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xFF1F4E3D)),
            title: const Text('Settings & Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _openSettingsPage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Color(0xFF1F4E3D)),
            title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('MyFinances App v1.0.0 (Local Memory Active)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: REPORTS (DYNAMIC DRILL-DOWN TABLE / MONTHLY DETAILED / CATEGORY-WISE / ACCOUNT-WISE)
  // ==========================================================================
  Widget _buildReportsTab() {
    List<MonthlyReportData> activeYearData = _getDynamicMonthlyReport(_selectedYear);

    double totalYearlyIncome = activeYearData.fold(0.0, (sum, m) => sum + m.income);
    double totalYearlyExpense = activeYearData.fold(0.0, (sum, m) => sum + m.expense);
    double totalYearlyBalance = totalYearlyIncome - totalYearlyExpense;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // TOP REPORT FORMAT SELECTOR BOX
        Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7E6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF1F4E3D),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _showReportFormatPicker,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedReportType,
                        style: const TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D)),
                    ],
                  ),
                ),
                if (_selectedReportType == 'YEARLY REPORT') ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_selectedYear > 2024) {
                            setState(() {
                              _selectedYear--;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _showYearPicker,
                        child: Row(
                          children: [
                            Text(
                              '$_selectedYear',
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_selectedYear < 2026) {
                            setState(() {
                              _selectedYear++;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        if (_selectedReportType == 'MONTHLY DETAILED REPORT')
          _buildMonthlyDetailedReportView()
        else if (_selectedReportType == 'DAY-WISE EXPENSE REPORT')
          _buildDayWiseExpenseReportView()
        else if (_selectedReportType == 'CATEGORY WISE REPORT')
          _buildCategoryWiseReportView()
        else if (_selectedReportType == 'ACCOUNT WISE REPORT')
          _buildAccountWiseReportView()
        else ...[
          // DYNAMIC DRILL-DOWN YEARLY MONTHLY TABLE CARD
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // TABLE HEADER ROW
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Month',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Income',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Expense',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Balance',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // DYNAMIC TAPPABLE MONTHLY DATA ROWS
                ...activeYearData.map((data) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                    ),
                    child: Row(
                      children: [
                        // Month Name Cell
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => _showMonthBreakdownDialog(data.month, data.monthIndex, filterType: 'ALL'),
                            child: Text(
                              data.month,
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Income Cell
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => _showMonthBreakdownDialog(data.month, data.monthIndex, filterType: 'INCOME'),
                            child: Text(
                              '₹${_formatInteger(data.income)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: data.income > 0 ? const Color(0xFF166534) : const Color(0xFF334155),
                                fontSize: 14.5,
                                fontWeight: data.income > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // Expense Cell
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => _showMonthBreakdownDialog(data.month, data.monthIndex, filterType: 'EXPENSE'),
                            child: Text(
                              '₹${_formatInteger(data.expense)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: data.expense > 0 ? const Color(0xFFB91C1C) : const Color(0xFF334155),
                                fontSize: 14.5,
                                fontWeight: data.expense > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // Balance Cell
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => _showMonthBreakdownDialog(data.month, data.monthIndex, filterType: 'ALL'),
                            child: Text(
                              '₹${_formatInteger(data.balance)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: data.balance < 0 ? const Color(0xFFB91C1C) : const Color(0xFF334155),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // TOTAL SUMMARY FOOTER ROW
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Total ($_selectedYear)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F4E3D),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${_formatInteger(totalYearlyIncome)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${_formatInteger(totalYearlyExpense)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB91C1C),
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${_formatInteger(totalYearlyBalance)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F4E3D),
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // RECENT TRANSACTIONS LIST WITH EDIT & DELETE POPUP MENUS (LIMITED TO 5 LATEST TRANSACTIONS)
          Builder(
            builder: (context) {
              final recentRecords = (_records.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime))).take(5).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(color: Color(0xFF1F4E3D), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        recentRecords.isEmpty ? '0 items' : 'Showing ${recentRecords.length} of ${_records.length}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recentRecords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF6D8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F4E3D)),
                      ),
                      child: const Center(
                        child: Text(
                          'No transaction records yet.\nTap "+" button to add your first transaction!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                  else
                    ...recentRecords.map((record) {
              final isExpense = record.type == 'EXPENSE';
              final isTransfer = record.type == 'TRANSFER';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF6D8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F4E3D), width: 1),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isTransfer
                          ? const Color(0xFFE0F2FE)
                          : (isExpense ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)),
                      child: Icon(
                        isTransfer
                            ? Icons.swap_horiz_rounded
                            : (isExpense ? Icons.arrow_downward : Icons.arrow_upward),
                        color: isTransfer
                            ? const Color(0xFF0369A1)
                            : (isExpense ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${record.accountName} • ${_formatDate(record.dateTime)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (record.notes.isNotEmpty)
                            Text(
                              record.notes,
                              style: const TextStyle(color: Color(0xFF1F4E3D), fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${isTransfer ? '' : (isExpense ? '-' : '+')}₹${_formatCurrency(record.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isTransfer
                            ? const Color(0xFF0369A1)
                            : (isExpense ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF1F4E3D), size: 20),
                      color: const Color(0xFFFAF7E6),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showEditTransactionDialog(record);
                        } else if (val == 'delete') {
                          _deleteTransaction(record);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: Color(0xFF0369A1), size: 18),
                              SizedBox(width: 8),
                              Text('Edit Entry'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Color(0xFFB91C1C), size: 18),
                              SizedBox(width: 8),
                              Text('Delete Entry', style: TextStyle(color: Color(0xFFB91C1C))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    ),

          const SizedBox(height: 80),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String title, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14.5,
            color: const Color(0xFF1F4E3D),
          ),
        ),
        Text(
          '₹${_formatCurrency(amount)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14.5,
            color: color ?? const Color(0xFF1F4E3D),
          ),
        ),
      ],
    );
  }

  String _formatDayMonth(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayStr = dt.day.toString().padLeft(2, '0');
    return '$dayStr ${months[dt.month - 1]}';
  }

  Widget _buildMonthlyDetailedReportView() {
    final activeNames = _activeAccountNames;
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final monthIncomeRecords = _records.where((r) =>
      r.dateTime.year == _selectedYear &&
      r.dateTime.month == _selectedDetailMonth &&
      r.type == 'INCOME' &&
      activeNames.contains(r.accountName)
    ).toList();

    final monthExpenseRecords = _records.where((r) =>
      r.dateTime.year == _selectedYear &&
      r.dateTime.month == _selectedDetailMonth &&
      r.type == 'EXPENSE' &&
      activeNames.contains(r.accountName)
    ).toList();

    final Map<String, double> incomeByCategory = {};
    final Map<String, DateTime> incomeLatestDate = {};
    for (var r in monthIncomeRecords) {
      incomeByCategory[r.category] = (incomeByCategory[r.category] ?? 0.0) + r.amount;
      if (!incomeLatestDate.containsKey(r.category) || r.dateTime.isAfter(incomeLatestDate[r.category]!)) {
        incomeLatestDate[r.category] = r.dateTime;
      }
    }
    final sortedIncomeCategories = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> expenseByCategory = {};
    final Map<String, DateTime> expenseLatestDate = {};
    for (var r in monthExpenseRecords) {
      expenseByCategory[r.category] = (expenseByCategory[r.category] ?? 0.0) + r.amount;
      if (!expenseLatestDate.containsKey(r.category) || r.dateTime.isAfter(expenseLatestDate[r.category]!)) {
        expenseLatestDate[r.category] = r.dateTime;
      }
    }
    final sortedExpenseCategories = expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    double totalIncome = monthIncomeRecords.fold(0.0, (sum, r) => sum + r.amount);
    double totalExpense = monthExpenseRecords.fold(0.0, (sum, r) => sum + r.amount);
    double openingBalance = _calculateOpeningBalance(_selectedYear, _selectedDetailMonth);
    double closingBalance = openingBalance + totalIncome - totalExpense;

    return Column(
      children: [
        // MONTHLY DETAILS HEADER WITH MONTH SWITCHER
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth > 1) {
                      _selectedDetailMonth--;
                    } else {
                      _selectedDetailMonth = 12;
                      _selectedYear--;
                    }
                  });
                },
              ),
              Column(
                children: [
                  Text(
                    '${monthsNames[_selectedDetailMonth - 1].toUpperCase()} $_selectedYear',
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Monthly Details',
                    style: TextStyle(
                      color: Color(0xFF52796F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth < 12) {
                      _selectedDetailMonth++;
                    } else {
                      _selectedDetailMonth = 1;
                      _selectedYear++;
                    }
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // SUMMARY BOX: OPENING, TOTAL INCOME, TOTAL EXPENSE, CLOSING BALANCE
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow('Opening Balance', openingBalance, color: const Color(0xFF1F4E3D)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(height: 1),
              ),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'INCOME'),
                child: _buildSummaryRow('Total Income', totalIncome, color: const Color(0xFF166534)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'EXPENSE'),
                child: _buildSummaryRow('Total Expense', totalExpense, color: const Color(0xFFB91C1C)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(height: 1),
              ),
              _buildSummaryRow('Closing Balance', closingBalance, isBold: true, color: const Color(0xFF1F4E3D)),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // INCOME DETAILS SECTION (CATEGORY-WISE GROUPED)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF166534), width: 1.5),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'INCOME'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: const Center(
                    child: Text(
                      'INCOME DETAILS',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              if (sortedIncomeCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No income entries for this month.', style: TextStyle(color: Colors.grey)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedIncomeCategories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = sortedIncomeCategories[index];
                    final catName = entry.key;
                    final amt = entry.value;
                    final date = incomeLatestDate[catName]!;
                    return ListTile(
                      dense: true,
                      onTap: () => _showCategoryBreakdownDialog(catName, 'INCOME'),
                      leading: SizedBox(
                        width: 54,
                        child: Text(
                          _formatDayMonth(date),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                      title: Text(
                        catName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1F4E3D)),
                      ),
                      trailing: Text(
                        '₹${_formatCurrency(amt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF166534)),
                      ),
                    );
                  },
                ),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'INCOME'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    border: Border(top: BorderSide(color: Color(0xFFDCFCE7))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Income', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 15)),
                      Text('₹${_formatCurrency(totalIncome)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF166534))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // EXPENSE DETAILS SECTION (CATEGORY-WISE GROUPED)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB91C1C), width: 1.5),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'EXPENSE'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: const Center(
                    child: Text(
                      'EXPENSE DETAILS',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              if (sortedExpenseCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No expense entries for this month.', style: TextStyle(color: Colors.grey)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedExpenseCategories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = sortedExpenseCategories[index];
                    final catName = entry.key;
                    final amt = entry.value;
                    final date = expenseLatestDate[catName]!;
                    return ListTile(
                      dense: true,
                      onTap: () => _showCategoryBreakdownDialog(catName, 'EXPENSE'),
                      leading: SizedBox(
                        width: 54,
                        child: Text(
                          _formatDayMonth(date),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                      title: Text(
                        catName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1F4E3D)),
                      ),
                      trailing: Text(
                        '₹${_formatCurrency(amt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFFB91C1C)),
                      ),
                    );
                  },
                ),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'EXPENSE'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    border: Border(top: BorderSide(color: Color(0xFFFEE2E2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), fontSize: 15)),
                      Text('₹${_formatCurrency(totalExpense)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFB91C1C))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================================================
  // DAY-WISE EXPENSE REPORT VIEW MATCHING USER FORMAT EXACTLY
  // ==========================================================================
  Widget _buildDayWiseExpenseReportView() {
    final activeNames = _activeAccountNames;
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    // Filter records for selected month & year and active accounts
    final monthRecords = _records.where((r) =>
      r.dateTime.year == _selectedYear &&
      r.dateTime.month == _selectedDetailMonth &&
      activeNames.contains(r.accountName)
    ).toList();

    // Group by day (1..31)
    final Map<int, List<TransactionRecord>> recordsByDay = {};
    for (var r in monthRecords) {
      final day = r.dateTime.day;
      recordsByDay.putIfAbsent(day, () => []).add(r);
    }

    // Get sorted days descending (newest first, e.g. 16, 15, 14...)
    final sortedDays = recordsByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    double totalMonthIncome = 0.0;
    double totalMonthExpense = 0.0;

    for (var r in monthRecords) {
      if (r.type == 'INCOME') {
        totalMonthIncome += r.amount;
      } else if (r.type == 'EXPENSE') {
        totalMonthExpense += r.amount;
      }
    }
    double totalMonthBalance = totalMonthIncome - totalMonthExpense;

    return Column(
      children: [
        // 1. MONTH SELECTOR HEADER WITH ARROWS
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth > 1) {
                      _selectedDetailMonth--;
                    } else {
                      _selectedDetailMonth = 12;
                      _selectedYear--;
                    }
                  });
                },
              ),
              Column(
                children: [
                  const Text(
                    'DAY-WISE EXPENSE REPORT',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
                        style: const TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 20),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth < 12) {
                      _selectedDetailMonth++;
                    } else {
                      _selectedDetailMonth = 1;
                      _selectedYear++;
                    }
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. DAY-WISE EXPENSE TABLE CARD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // TABLE HEADER (Date, Total Income, Total Expense, Balance)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7E6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E3D),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Income',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E3D),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Expense',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E3D),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Balance',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E3D),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (sortedDays.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No transactions logged for this month.',
                      style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                )
              else
                ...sortedDays.map((day) {
                  final dayRecs = recordsByDay[day]!;
                  double dayIncome = 0.0;
                  double dayExpense = 0.0;
                  for (var r in dayRecs) {
                    if (r.type == 'INCOME') {
                      dayIncome += r.amount;
                    } else if (r.type == 'EXPENSE') {
                      dayExpense += r.amount;
                    }
                  }
                  double dayBalance = dayIncome - dayExpense;
                  final displayDateStr = '$day ${shortMonths[_selectedDetailMonth - 1]}';
                  final fullDateStr = '$day ${shortMonths[_selectedDetailMonth - 1]} $_selectedYear';

                  return InkWell(
                    onTap: () => _showDayBreakdownDialog(fullDateStr, dayRecs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                      ),
                      child: Row(
                        children: [
                          // Date Cell (e.g. 16 Aug)
                          Expanded(
                            flex: 3,
                            child: Text(
                              displayDateStr,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Total Income Cell
                          Expanded(
                            flex: 3,
                            child: Text(
                              '₹${_formatInteger(dayIncome)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: dayIncome > 0 ? const Color(0xFF166534) : const Color(0xFF475569),
                                fontSize: 14,
                                fontWeight: dayIncome > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Total Expense Cell
                          Expanded(
                            flex: 3,
                            child: Text(
                              '₹${_formatInteger(dayExpense)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: dayExpense > 0 ? const Color(0xFFB91C1C) : const Color(0xFF475569),
                                fontSize: 14,
                                fontWeight: dayExpense > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Balance Cell
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${dayBalance < 0 ? '-' : ''}₹${_formatInteger(dayBalance.abs())}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: dayBalance < 0
                                    ? const Color(0xFFB91C1C)
                                    : (dayBalance > 0 ? const Color(0xFF1F4E3D) : const Color(0xFF475569)),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              // TOTAL SUMMARY FOOTER ROW
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7E6),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Total (${shortMonths[_selectedDetailMonth - 1]})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E3D),
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '₹${_formatInteger(totalMonthIncome)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '₹${_formatInteger(totalMonthExpense)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB91C1C),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${totalMonthBalance < 0 ? '-' : ''}₹${_formatInteger(totalMonthBalance.abs())}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: totalMonthBalance < 0 ? const Color(0xFFB91C1C) : const Color(0xFF1F4E3D),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  void _showDayBreakdownDialog(String dateStr, List<TransactionRecord> records) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions on $dateStr',
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${records.length} entries',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, idx) {
                    final r = records[idx];
                    final isExpense = r.type == 'EXPENSE';
                    final isTransfer = r.type == 'TRANSFER';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F4E3D), width: 1),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isTransfer
                                ? const Color(0xFFE0F2FE)
                                : (isExpense ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)),
                            child: Icon(
                              isTransfer
                                  ? Icons.swap_horiz_rounded
                                  : (isExpense ? Icons.arrow_downward : Icons.arrow_upward),
                              color: isTransfer
                                  ? const Color(0xFF0369A1)
                                  : (isExpense ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.category,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  r.accountName,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                if (r.notes.isNotEmpty)
                                  Text(
                                    r.notes,
                                    style: const TextStyle(color: Color(0xFF1F4E3D), fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${isTransfer ? '' : (isExpense ? '-' : '+')}₹${_formatCurrency(r.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isTransfer
                                  ? const Color(0xFF0369A1)
                                  : (isExpense ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // CATEGORY-WISE REPORT VIEW WITH DYNAMIC PROGRESS BARS & PERCENTAGES
  // ==========================================================================
  Widget _buildCategoryWiseReportView() {
    final activeNames = _activeAccountNames;
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final monthRecords = _records.where((r) =>
      r.dateTime.year == _selectedYear &&
      r.dateTime.month == _selectedDetailMonth &&
      activeNames.contains(r.accountName)
    ).toList();

    final Map<String, double> expenseByCategory = {};
    for (var r in monthRecords.where((r) => r.type == 'EXPENSE')) {
      expenseByCategory[r.category] = (expenseByCategory[r.category] ?? 0.0) + r.amount;
    }

    final Map<String, double> incomeByCategory = {};
    for (var r in monthRecords.where((r) => r.type == 'INCOME')) {
      incomeByCategory[r.category] = (incomeByCategory[r.category] ?? 0.0) + r.amount;
    }

    double totalIncome = incomeByCategory.values.fold(0.0, (s, a) => s + a);
    double totalExpense = expenseByCategory.values.fold(0.0, (s, a) => s + a);
    double netBalance = totalIncome - totalExpense;

    final sortedExpense = expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedIncome = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // MONTH SELECTOR HEADER
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth > 1) {
                      _selectedDetailMonth--;
                    } else {
                      _selectedDetailMonth = 12;
                      _selectedYear--;
                    }
                  });
                },
              ),
              Column(
                children: [
                  const Text(
                    'CATEGORY-WISE REPORT',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
                        style: const TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 20),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth < 12) {
                      _selectedDetailMonth++;
                    } else {
                      _selectedDetailMonth = 1;
                      _selectedYear++;
                    }
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // OVERVIEW SUMMARY CARD: TOTAL INCOME, TOTAL EXPENSE, NET BALANCE
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'INCOME'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL INCOME',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${_formatInteger(totalIncome)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFCBD5E1)),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'EXPENSE'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL EXPENSE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${_formatInteger(totalExpense)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFCBD5E1)),
              InkWell(
                onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'ALL'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      const Text(
                        'NET BALANCE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${_formatInteger(netBalance)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: netBalance < 0 ? const Color(0xFFB91C1C) : const Color(0xFF1F4E3D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // EXPENSE CATEGORIES CARD WITH PROGRESS BARS
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB91C1C), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Center(
                  child: Text(
                    'EXPENSE CATEGORIES',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              if (sortedExpense.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No expense categories for this month.', style: TextStyle(color: Colors.grey)),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: sortedExpense.map((entry) {
                      final catName = entry.key;
                      final amt = entry.value;
                      final pct = totalExpense > 0 ? (amt / totalExpense) : 0.0;
                      final pctStr = '${(pct * 100).toStringAsFixed(0)}%';

                      final catObj = _categories.firstWhere(
                        (c) => c.name == catName,
                        orElse: () => CategoryItem(
                          id: 'def',
                          name: catName,
                          type: 'EXPENSE',
                          icon: Icons.label_outlined,
                          bgColor: const Color(0xFFB91C1C),
                        ),
                      );

                      return InkWell(
                        onTap: () => _showCategoryBreakdownDialog(catName, 'EXPENSE'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14.0, top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: catObj.bgColor,
                                        child: Icon(catObj.icon, size: 14, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        catName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1F4E3D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${_formatInteger(amt)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 10,
                                        backgroundColor: const Color(0xFFFEE2E2),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB91C1C)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      pctStr,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // INCOME CATEGORIES CARD WITH PROGRESS BARS
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF166534), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Center(
                  child: Text(
                    'INCOME CATEGORIES',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              if (sortedIncome.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No income categories for this month.', style: TextStyle(color: Colors.grey)),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: sortedIncome.map((entry) {
                      final catName = entry.key;
                      final amt = entry.value;
                      final pct = totalIncome > 0 ? (amt / totalIncome) : 0.0;
                      final pctStr = '${(pct * 100).toStringAsFixed(0)}%';

                      final catObj = _categories.firstWhere(
                        (c) => c.name == catName,
                        orElse: () => CategoryItem(
                          id: 'def',
                          name: catName,
                          type: 'INCOME',
                          icon: Icons.payments_rounded,
                          bgColor: const Color(0xFF166534),
                        ),
                      );

                      return InkWell(
                        onTap: () => _showCategoryBreakdownDialog(catName, 'INCOME'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14.0, top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: catObj.bgColor,
                                        child: Icon(catObj.icon, size: 14, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        catName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1F4E3D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${_formatInteger(amt)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 10,
                                        backgroundColor: const Color(0xFFDCFCE7),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF166534)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      pctStr,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================================================
  // ACCOUNT-WISE REPORT VIEW MATCHING USER ASCII DIAGRAM EXACTLY
  // ==========================================================================
  Widget _buildAccountWiseReportView() {
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final activeAccounts = _accounts.where((a) => !a.isIgnored).toList();

    double totalMonthIncome = 0.0;
    double totalMonthExpense = 0.0;

    List<Map<String, dynamic>> accountSummaries = [];

    for (var acc in activeAccounts) {
      final summary = _getAccountMonthSummary(acc, _selectedYear, _selectedDetailMonth);
      totalMonthIncome += summary.income;
      totalMonthExpense += summary.expense;
      accountSummaries.add({
        'account': acc,
        'summary': summary,
      });
    }

    double totalBalance = activeAccounts.fold(0.0, (s, a) => s + a.balance);

    return Column(
      children: [
        // MONTH SELECTOR HEADER
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth > 1) {
                      _selectedDetailMonth--;
                    } else {
                      _selectedDetailMonth = 12;
                      _selectedYear--;
                    }
                  });
                },
              ),
              Column(
                children: [
                  const Text(
                    'ACCOUNT-WISE REPORT',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
                        style: const TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 20),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 24),
                onPressed: () {
                  setState(() {
                    if (_selectedDetailMonth < 12) {
                      _selectedDetailMonth++;
                    } else {
                      _selectedDetailMonth = 1;
                      _selectedYear++;
                    }
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // TOP OVERVIEW CARD (TOTAL BALANCE, TOTAL INCOME, TOTAL EXPENSE)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Color(0xFF52796F),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_formatCurrency(totalBalance)}',
                style: const TextStyle(
                  color: Color(0xFF1F4E3D),
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Total Income: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      Text(
                        '₹${_formatInteger(totalMonthIncome)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Total Expense: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      Text(
                        '₹${_formatInteger(totalMonthExpense)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // PER-ACCOUNT CARDS (MATCHING USER ASCII DIAGRAM)
        if (accountSummaries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No active accounts available.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...accountSummaries.map((item) {
            final AccountItem acc = item['account'];
            final AccountMonthSummary summary = item['summary'];
            final bool isCreditCard = acc.name.toLowerCase().contains('credit') || acc.name.toLowerCase().contains('card');

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // CARD HEADER (ICON + NAME)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDF6D8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border(bottom: BorderSide(color: Color(0xFF1F4E3D), width: 1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: acc.iconBgColor,
                          child: Icon(acc.icon, size: 18, color: acc.iconColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            acc.name,
                            style: const TextStyle(
                              color: Color(0xFF1F4E3D),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _openAccountDetailsScreen(acc),
                          child: const Text('Details', style: TextStyle(color: Color(0xFF1F4E3D), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // CARD BODY
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isCreditCard
                      ? Column(
                          children: [
                            _buildSummaryRow('Opening Due', summary.openingBalance.abs(), color: const Color(0xFFB91C1C)),
                            const SizedBox(height: 8),
                            _buildSummaryRow('New Expenses', summary.expense, color: const Color(0xFFB91C1C)),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Payment', summary.income, color: const Color(0xFF166534)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(height: 1),
                            ),
                            _buildSummaryRow('Current Due', summary.closingBalance.abs(), isBold: true, color: const Color(0xFFB91C1C)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildSummaryRow('Opening Balance', summary.openingBalance, color: const Color(0xFF1F4E3D)),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Income', summary.income, color: const Color(0xFF166534)),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Expense', summary.expense, color: const Color(0xFFB91C1C)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(height: 1),
                            ),
                            _buildSummaryRow('Closing Balance', summary.closingBalance, isBold: true, color: const Color(0xFF1F4E3D)),
                          ],
                        ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: MONTHLY BUDGETS MANAGER (MATCHING USER SCREENSHOT EXACTLY)
  // ==========================================================================
  Widget _buildBudgetsTab() {
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final currentMonthBudgets = _budgets.where((b) =>
      b.month == _selectedDetailMonth && b.year == _selectedYear
    ).toList();

    double totalBudget = currentMonthBudgets.fold(0.0, (sum, b) => sum + b.limitAmount);
    
    double totalSpent = 0.0;
    for (var b in currentMonthBudgets) {
      final categorySpent = _records.where((r) =>
        r.type == 'EXPENSE' &&
        r.category == b.categoryName &&
        r.dateTime.month == _selectedDetailMonth &&
        r.dateTime.year == _selectedYear &&
        _activeAccountNames.contains(r.accountName)
      ).fold(0.0, (sum, r) => sum + r.amount);
      totalSpent += categorySpent;
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. TOP MONTH SELECTOR WITH ARROWS: < August 2026 >
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 28),
              onPressed: () {
                setState(() {
                  if (_selectedDetailMonth > 1) {
                    _selectedDetailMonth--;
                  } else {
                    _selectedDetailMonth = 12;
                    _selectedYear--;
                  }
                });
              },
            ),
            const SizedBox(width: 12),
            Text(
              '${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
              style: const TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 28),
              onPressed: () {
                setState(() {
                  if (_selectedDetailMonth < 12) {
                    _selectedDetailMonth++;
                  } else {
                    _selectedDetailMonth = 1;
                    _selectedYear++;
                  }
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 2. TOTAL BUDGET & TOTAL SPENT SUMMARY ROW
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text(
                  'TOTAL BUDGET',
                  style: TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatCurrency(totalBudget)}',
                  style: const TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text(
                  'TOTAL SPENT',
                  style: TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatCurrency(totalSpent)}',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 3. TITLE & SOLID DIVIDER LINE
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budgeted categories: ${shortMonths[_selectedDetailMonth - 1]} $_selectedYear',
              style: const TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFF1F4E3D), thickness: 1.5, height: 1),
          ],
        ),

        const SizedBox(height: 16),

        // 4. BUDGETED CATEGORY CARDS LIST
        if (currentMonthBudgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6D8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
            ),
            child: Column(
              children: [
                const Icon(Icons.calculate_outlined, size: 48, color: Color(0xFF1F4E3D)),
                const SizedBox(height: 12),
                Text(
                  'No Budgets Set for ${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F4E3D)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap "+ ADD CATEGORY BUDGET" below to set your monthly budget limits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...currentMonthBudgets.map((budgetItem) {
            final category = _categories.firstWhere(
              (c) => c.name == budgetItem.categoryName,
              orElse: () => CategoryItem(
                id: 'c_custom',
                name: budgetItem.categoryName,
                type: 'EXPENSE',
                icon: Icons.shopping_bag_rounded,
                bgColor: const Color(0xFF0369A1),
              ),
            );

            double spentAmount = _records.where((r) =>
              r.type == 'EXPENSE' &&
              r.category == budgetItem.categoryName &&
              r.dateTime.month == _selectedDetailMonth &&
              r.dateTime.year == _selectedYear &&
              _activeAccountNames.contains(r.accountName)
            ).fold(0.0, (sum, r) => sum + r.amount);

            double remainingAmount = (budgetItem.limitAmount - spentAmount);
            if (remainingAmount < 0) remainingAmount = 0.0;
            bool isOverspent = spentAmount > budgetItem.limitAmount;
            double progressRatio = budgetItem.limitAmount > 0
                ? (spentAmount / budgetItem.limitAmount).clamp(0.0, 1.0)
                : 1.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: category.bgColor,
                        child: Icon(category.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  budgetItem.categoryName,
                                  style: const TextStyle(
                                    color: Color(0xFF1F4E3D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz, color: Color(0xFF1F4E3D)),
                                  color: const Color(0xFFFAF7E6),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _showEditBudgetDialog(budgetItem);
                                    } else if (val == 'delete') {
                                      _showDeleteBudgetDialog(budgetItem);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, color: Color(0xFF0369A1), size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Limit', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Color(0xFFB91C1C), size: 18),
                                          SizedBox(width: 8),
                                          Text('Delete Budget', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Limit: ₹${_formatCurrency(budgetItem.limitAmount)}',
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Spent: ₹${_formatCurrency(spentAmount)}',
                              style: TextStyle(
                                color: isOverspent ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remaining: ₹${_formatCurrency(remainingAmount)}',
                              style: TextStyle(
                                color: isOverspent ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '(${shortMonths[_selectedDetailMonth - 1]} $_selectedYear)',
                            style: const TextStyle(
                              color: Color(0xFF52796F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF166534),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '₹${_formatInteger(budgetItem.limitAmount)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: const Color(0xFF1F4E3D), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: isOverspent ? 1.0 : progressRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isOverspent ? const Color(0xFFB91C1C) : const Color(0xFF1F4E3D),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: InkWell(
            onTap: _showAddBudgetDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1F4E3D),
                  width: 1.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF1F4E3D),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ADD CATEGORY BUDGET',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  void _showAddBudgetDialog() {
    final expenseCategories = _categories.where((c) => c.type == 'EXPENSE').toList();
    if (expenseCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expense categories found. Please add a category first!')),
      );
      return;
    }

    String selectedCategory = expenseCategories.first.name;
    final limitController = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF7E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
            ),
            title: const Text(
              'Set Category Budget',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: expenseCategories.map((c) {
                      return DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 20, color: c.bgColor),
                            const SizedBox(width: 8),
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Monthly Limit Amount (₹):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '5000',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E3D),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final limit = double.tryParse(limitController.text) ?? 0.0;
                  if (limit > 0) {
                    setState(() {
                      _budgets.removeWhere((b) =>
                        b.categoryName == selectedCategory &&
                        b.month == _selectedDetailMonth &&
                        b.year == _selectedYear
                      );
                      _budgets.add(BudgetItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        categoryName: selectedCategory,
                        limitAmount: limit,
                        month: _selectedDetailMonth,
                        year: _selectedYear,
                      ));
                    });
                    _saveDataToLocalStorage();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Budget of ₹${_formatCurrency(limit)} set for $selectedCategory!'),
                        backgroundColor: const Color(0xFF166534),
                      ),
                    );
                  }
                },
                child: const Text('SAVE BUDGET', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditBudgetDialog(BudgetItem budget) {
    final limitController = TextEditingController(text: budget.limitAmount.toInt().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
        ),
        title: Text(
          'Edit ${budget.categoryName} Budget',
          style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Budget Limit Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E3D), foregroundColor: Colors.white),
            onPressed: () {
              final newLimit = double.tryParse(limitController.text) ?? budget.limitAmount;
              setState(() {
                budget.limitAmount = newLimit;
              });
              _saveDataToLocalStorage();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${budget.categoryName} budget updated to ₹${_formatCurrency(newLimit)}!'), backgroundColor: const Color(0xFF166534)),
              );
            },
            child: const Text('UPDATE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteBudgetDialog(BudgetItem budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Budget?', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove the budget limit for ${budget.categoryName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _budgets.removeWhere((b) => b.id == budget.id);
              });
              _saveDataToLocalStorage();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${budget.categoryName} budget deleted.')),
              );
            },
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  // TAB 4: ACCOUNTS
  Widget _buildAccountsTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              Text(
                '[ All Accounts ₹${_formatCurrency(_totalBalance)} ]',
                style: const TextStyle(
                  color: Color(0xFF1F4E3D),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'EXPENSE SO FAR',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatCurrency(_totalExpense)}',
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'INCOME SO FAR',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatCurrency(_totalIncome)}',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Accounts',
            style: TextStyle(
              color: Color(0xFF1F4E3D),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (_accounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6D8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
            ),
            child: const Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 48, color: Color(0xFF1F4E3D)),
                SizedBox(height: 12),
                Text(
                  'No Accounts Added Yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F4E3D)),
                ),
                SizedBox(height: 6),
                Text(
                  'Tap "ADD NEW ACCOUNT" below to create your first account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...(_accounts.toList()..sort((a, b) => a.priority.compareTo(b.priority))).map((account) => _buildAccountCard(account)),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: InkWell(
            onTap: _showAddAccountDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1F4E3D),
                  width: 1.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF1F4E3D),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ADD NEW ACCOUNT',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildAccountCard(AccountItem account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: account.isIgnored
            ? Colors.grey[200]
            : const Color(0xFFFDF6D8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: account.isIgnored ? Colors.grey : const Color(0xFF1F4E3D),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openAccountDetailsScreen(account),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: account.isIgnored ? Colors.grey[300] : account.iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (account.isIgnored ? Colors.grey : account.iconColor).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      account.icon,
                      color: account.isIgnored ? Colors.grey[600] : account.iconColor,
                      size: 28,
                    ),
                    if (account.badgeText != null)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: account.isIgnored ? Colors.grey[600] : account.iconColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            account.badgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.name,
                          style: TextStyle(
                            color: account.isIgnored ? Colors.grey[700] : const Color(0xFF1F4E3D),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            decoration: account.isIgnored ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (account.isIgnored) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'IGNORED',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance:  ₹${_formatCurrency(account.balance)}',
                      style: TextStyle(
                        color: account.isIgnored ? Colors.grey[600] : const Color(0xFF1F4E3D),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Color(0xFF1F4E3D)),
                color: const Color(0xFFFAF7E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.2),
                ),
                onSelected: (value) {
                  if (value == 'details') {
                    _openAccountDetailsScreen(account);
                  } else if (value == 'edit') {
                    _showEditAccountDialog(account);
                  } else if (value == 'ignore') {
                    setState(() {
                      account.isIgnored = !account.isIgnored;
                    });
                    _saveDataToLocalStorage();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          account.isIgnored
                              ? '${account.name} is now Ignored'
                              : '${account.name} is now Included',
                        ),
                      ),
                    );
                  } else if (value == 'delete') {
                    _showDeleteAccountConfirm(account);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.list_alt_rounded, color: Color(0xFF1F4E3D), size: 20),
                        SizedBox(width: 10),
                        Text('Account Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, color: Color(0xFF0369A1), size: 20),
                        const SizedBox(width: 10),
                        Text('Edit', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ignore',
                    child: Row(
                      children: [
                        Icon(
                          account.isIgnored ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                          color: account.isIgnored ? const Color(0xFF166534) : const Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          account.isIgnored ? 'Include' : 'Ignore',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Color(0xFFB91C1C), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 2: FINANCIAL ANALYSIS (MATCHING USER SCREENSHOT EXACTLY)
  // ==========================================================================
  Widget _buildAnalysisTab() {
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final activeNames = _activeAccountNames;
    final monthRecords = _records.where((r) =>
      r.dateTime.year == _selectedYear &&
      r.dateTime.month == _selectedDetailMonth &&
      activeNames.contains(r.accountName)
    ).toList();

    double monthExpense = monthRecords.where((r) => r.type == 'EXPENSE').fold(0.0, (s, r) => s + r.amount);
    double monthIncome = monthRecords.where((r) => r.type == 'INCOME').fold(0.0, (s, r) => s + r.amount);
    double monthTotal = monthIncome - monthExpense;

    final isExpenseMode = _analysisOverviewType == 'EXPENSE OVERVIEW';
    final targetType = isExpenseMode ? 'EXPENSE' : 'INCOME';

    final Map<String, double> categoryTotals = {};
    for (var r in monthRecords.where((r) => r.type == targetType)) {
      categoryTotals[r.category] = (categoryTotals[r.category] ?? 0.0) + r.amount;
    }

    final sortedEntries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double overviewTotal = isExpenseMode ? monthExpense : monthIncome;

    final palette = [
      const Color(0xFFEF4444), // Red (Google Pay)
      const Color(0xFFFACC15), // Yellow (Educational)
      const Color(0xFF8B5CF6), // Purple (Rashan)
      const Color(0xFF84CC16), // Lime Green (Shopping)
      const Color(0xFFEC4899), // Pink (Vegetable)
      const Color(0xFF0D9488), // Teal (Transportation)
      const Color(0xFF06B6D4), // Cyan (Health)
      const Color(0xFFF97316), // Orange
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF64748B), // Slate
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. TOP MONTH NAVIGATION HEADER: < August 2026 > ≡
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F4E3D), size: 28),
              onPressed: () {
                setState(() {
                  if (_selectedDetailMonth > 1) {
                    _selectedDetailMonth--;
                  } else {
                    _selectedDetailMonth = 12;
                    _selectedYear--;
                  }
                });
              },
            ),
            Text(
              '${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
              style: const TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 28),
                  onPressed: () {
                    setState(() {
                      if (_selectedDetailMonth < 12) {
                        _selectedDetailMonth++;
                      } else {
                        _selectedDetailMonth = 1;
                        _selectedYear++;
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF1F4E3D), size: 24),
                  onPressed: _showYearPicker,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 2. THREE-COLUMN SUMMARY ROW: EXPENSE | INCOME | TOTAL
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'EXPENSE'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Column(
                  children: [
                    const Text(
                      'EXPENSE',
                      style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_formatCurrency(monthExpense)}',
                      style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => _showMonthBreakdownDialog(monthsNames[_selectedDetailMonth - 1], _selectedDetailMonth, filterType: 'INCOME'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Column(
                  children: [
                    const Text(
                      'INCOME',
                      style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_formatCurrency(monthIncome)}',
                      style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 16.5),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatCurrency(monthTotal)}',
                  style: TextStyle(
                    color: monthTotal >= 0 ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 3. DROPDOWN OVERVIEW SWITCHER BOX: v EXPENSE OVERVIEW
        Center(
          child: InkWell(
            onTap: () {
              setState(() {
                _analysisOverviewType = isExpenseMode ? 'INCOME OVERVIEW' : 'EXPENSE OVERVIEW';
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1F4E3D), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    _analysisOverviewType,
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 4. DONUT PIE CHART & LEGEND ROW MATCHING SCREENSHOT
        if (sortedEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6D8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
            ),
            child: Column(
              children: [
                const Icon(Icons.donut_large_outlined, size: 48, color: Color(0xFF1F4E3D)),
                const SizedBox(height: 12),
                Text(
                  'No ${isExpenseMode ? "Expenses" : "Income"} Recorded for ${monthsNames[_selectedDetailMonth - 1]} $_selectedYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F4E3D)),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(170, 170),
                      painter: DonutChartPainter(
                        values: sortedEntries.map((e) => e.value).toList(),
                        colors: List.generate(sortedEntries.length, (i) => palette[i % palette.length]),
                        centerLabel: isExpenseMode ? 'Expenses' : 'Income',
                      ),
                    ),
                    Text(
                      isExpenseMode ? 'Expenses' : 'Income',
                      style: const TextStyle(
                        color: Color(0xFF1F4E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(sortedEntries.length, (index) {
                    final entry = sortedEntries[index];
                    final color = palette[index % palette.length];
                    return InkWell(
                      onTap: () => _showCategoryBreakdownDialog(entry.key, targetType),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Color(0xFF1F4E3D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
        const SizedBox(height: 16),

        // 5. CATEGORY PROGRESS BARS LIST WITH PERCENTAGES MATCHING SCREENSHOT (CLICKABLE FOR DETAILS)
        ...sortedEntries.map((entry) {
          final catName = entry.key;
          final amt = entry.value;
          final pct = overviewTotal > 0 ? (amt / overviewTotal) : 0.0;
          final pctStr = '${(pct * 100).toStringAsFixed(2)}%';

          final catObj = _categories.firstWhere(
            (c) => c.name == catName,
            orElse: () => CategoryItem(
              id: 'c_custom',
              name: catName,
              type: targetType,
              icon: isExpenseMode ? Icons.shopping_cart_rounded : Icons.payments_rounded,
              bgColor: const Color(0xFF0369A1),
            ),
          );

          return InkWell(
            onTap: () => _showCategoryBreakdownDialog(catName, targetType),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: catObj.bgColor,
                    child: Icon(catObj.icon, color: Colors.white, size: 22),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              catName,
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${isExpenseMode ? '-' : '+'}₹${_formatCurrency(amt)}',
                              style: TextStyle(
                                color: isExpenseMode ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border.all(color: const Color(0xFF1F4E3D), width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: pct.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F4E3D),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  SizedBox(
                    width: 58,
                    child: Text(
                      pctStr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1F4E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 80),
      ],
    );
  }

  // TAB 5: CATEGORIES
  Widget _buildCategoriesTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Categories',
          style: TextStyle(color: Color(0xFF1F4E3D), fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        ..._categories.map((cat) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.bgColor,
                  radius: 20,
                  child: Icon(cat.icon, color: Colors.white, size: 20),
                ),
                title: Text(
                  cat.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1F4E3D),
                  ),
                ),
                subtitle: Text(
                  cat.type,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cat.type == 'INCOME' ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF1F4E3D)),
                  color: const Color(0xFFFAF7E6),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditCategoryDialog(cat);
                    } else if (val == 'delete') {
                      setState(() {
                        _categories.removeWhere((c) => c.id == cat.id);
                      });
                      _saveDataToLocalStorage();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Category "${cat.name}" deleted & saved.')),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Category')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Category', style: TextStyle(color: Color(0xFFB91C1C))),
                    ),
                  ],
                ),
              ),
            )),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: InkWell(
            onTap: _showAddCategoryDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1F4E3D),
                  width: 1.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF1F4E3D),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ADD NEW CATEGORY',
                    style: TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final regEx = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(regEx, (Match m) => '${m[1]},');
    return '$formattedInt.$decPart';
  }

  String _formatInteger(double amount) {
    final intPart = amount.toStringAsFixed(0);
    final regEx = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    return intPart.replaceAllMapped(regEx, (Match m) => '${m[1]},');
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}



// ============================================================================
// ACCOUNT DETAILS SCREEN (MATCHING USER SCREENSHOT EXACTLY)
// ============================================================================
class AccountDetailsScreen extends StatefulWidget {
  final AccountItem account;
  final List<AccountItem>? accounts;
  final List<TransactionRecord> allRecords;
  final List<CategoryItem> categories;
  final Function(TransactionRecord)? onDeleteRecord;
  final Function(TransactionRecord)? onEditRecord;
  final Function(TransactionRecord)? onDuplicateRecord;
  final Function(TransactionRecord, String, String)? onUpdateRecord;

  const AccountDetailsScreen({
    super.key,
    required this.account,
    this.accounts,
    required this.allRecords,
    required this.categories,
    this.onDeleteRecord,
    this.onEditRecord,
    this.onDuplicateRecord,
    this.onUpdateRecord,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountSummaryItem {
  final String title;
  final String type;
  final List<TransactionRecord> records;
  final double totalAmount;
  final DateTime latestDate;

  _AccountSummaryItem({
    required this.title,
    required this.type,
    required this.records,
    required this.totalAmount,
    required this.latestDate,
  });
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  bool _showSummary = true; // Defaults to Summary view first

  List<_AccountSummaryItem> _getSummaryItems(List<TransactionRecord> records) {
    final Map<String, List<TransactionRecord>> map = {};
    for (var r in records) {
      final title = _getRecordSummaryTitle(r);
      map.putIfAbsent(title, () => []).add(r);
    }

    final List<_AccountSummaryItem> items = [];
    map.forEach((title, recs) {
      recs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final double total = recs.fold(0.0, (sum, r) => sum + r.amount);
      items.add(_AccountSummaryItem(
        title: title,
        type: recs.first.type,
        records: recs,
        totalAmount: total,
        latestDate: recs.first.dateTime,
      ));
    });

    items.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return items;
  }

  String _getRecordSummaryTitle(TransactionRecord rec) {
    if (rec.type == 'TRANSFER') {
      if (rec.notes.contains('Transfer from') && rec.notes.contains('to')) {
        return '[${rec.notes.split('•').first.trim().replaceAll('Transfer from ', '').replaceAll(' to ', ' > ')}]';
      } else {
        return '[${rec.accountName} > ${rec.category.replaceAll('Transfer to ', '')}]';
      }
    }
    return rec.category;
  }

  @override
  Widget build(BuildContext context) {
    final accNameLower = widget.account.name.trim().toLowerCase();
    final accountRecords = widget.allRecords.where((r) {
      if (r.accountName.trim().toLowerCase() == accNameLower) return true;
      if (r.type == 'TRANSFER') {
        if (isTransferToAccountGlobal(r, widget.account.name)) return true;
      }
      if (r.notes.toLowerCase().contains(accNameLower)) return true;
      return false;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final Map<String, List<TransactionRecord>> groupedRecords = {};
    for (var rec in accountRecords) {
      final key = '${_monthName(rec.dateTime.month)} ${rec.dateTime.year}';
      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = [];
      }
      groupedRecords[key]!.add(rec);
    }

    final Map<String, List<_AccountSummaryItem>> groupedSummary = {};
    groupedRecords.forEach((monthKey, recs) {
      groupedSummary[monthKey] = _getSummaryItems(recs);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1F4E3D), size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.account.name} Details',
              style: const TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              _showSummary ? 'Summary: Month-wise' : 'Records: All time',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: accountRecords.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFF1F4E3D)),
                    const SizedBox(height: 14),
                    Text(
                      'No records for "${widget.account.name}".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Any income, expense, or transfer for this account will automatically appear here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Top Tab Switcher: Summary vs All Transactions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E4D0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showSummary = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _showSummary ? const Color(0xFF1F4E3D) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pie_chart_outline_rounded,
                                      size: 17,
                                      color: _showSummary ? Colors.white : const Color(0xFF1F4E3D)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Summary',
                                    style: TextStyle(
                                      color: _showSummary ? Colors.white : const Color(0xFF1F4E3D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showSummary = false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: !_showSummary ? const Color(0xFF1F4E3D) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.list_alt_rounded,
                                      size: 17,
                                      color: !_showSummary ? Colors.white : const Color(0xFF1F4E3D)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'All Transactions',
                                    style: TextStyle(
                                      color: !_showSummary ? Colors.white : const Color(0xFF1F4E3D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _showSummary
                      ? _buildSummaryView(groupedSummary)
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: groupedRecords.entries.map((entry) {
                            final monthYearStr = entry.key;
                            final monthRecs = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        monthYearStr,
                                        style: const TextStyle(
                                          color: Color(0xFF1F4E3D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(height: 1.5, color: const Color(0xFF1F4E3D)),
                                    ],
                                  ),
                                ),
                                ...monthRecs.map((rec) => _buildTransactionRow(context, rec)),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryView(Map<String, List<_AccountSummaryItem>> groupedSummary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        // Month-wise Summary Sections (matching detail screen)
        ...groupedSummary.entries.map((entry) {
          final monthYearStr = entry.key;
          final monthItems = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          monthYearStr,
                          style: const TextStyle(
                            color: Color(0xFF1F4E3D),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${monthItems.length} categories/transfers',
                          style: const TextStyle(
                            color: Color(0xFF52796F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(height: 1.5, color: const Color(0xFF1F4E3D)),
                  ],
                ),
              ),
              ...monthItems.map((item) => _buildSummaryItemCard(item)),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSummaryItemCard(_AccountSummaryItem item) {
    final isTransfer = item.type == 'TRANSFER';
    final isIncome = item.type == 'INCOME';

    Color avatarBg;
    Color iconColor;
    IconData icon;
    Color amountColor;
    String sign;

    if (isTransfer) {
      avatarBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF1E40AF);
      icon = Icons.swap_horiz_rounded;
      amountColor = const Color(0xFF1E3A8A);
      sign = '';
    } else if (isIncome) {
      avatarBg = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF166534);
      icon = Icons.attach_money_rounded;
      amountColor = const Color(0xFF166534);
      sign = '+';
    } else {
      avatarBg = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFB91C1C);
      icon = Icons.shopping_bag_rounded;
      amountColor = const Color(0xFFB91C1C);
      sign = '-';
    }

    if (!isTransfer) {
      final cat = widget.categories.firstWhere(
        (c) => c.name == item.title,
        orElse: () => CategoryItem(id: '', name: item.title, type: item.type, icon: icon, bgColor: avatarBg),
      );
      if (cat.id.isNotEmpty) {
        icon = cat.icon;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AccountGroupDetailsScreen(
                  title: item.title,
                  accountName: widget.account.name,
                  records: item.records,
                  categories: widget.categories,
                  accounts: widget.accounts,
                  onDeleteRecord: (rec) {
                    if (widget.onDeleteRecord != null) widget.onDeleteRecord!(rec);
                    setState(() {});
                  },
                  onEditRecord: (rec) async {
                    if (widget.onEditRecord != null) await widget.onEditRecord!(rec);
                    if (mounted) setState(() {});
                  },
                  onDuplicateRecord: (rec) {
                    if (widget.onDuplicateRecord != null) widget.onDuplicateRecord!(rec);
                    setState(() {});
                  },
                  onUpdateRecord: (rec, acc, cat) {
                    if (widget.onUpdateRecord != null) widget.onUpdateRecord!(rec, acc, cat);
                    setState(() {});
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarBg,
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isTransfer ? const Color(0xFF1E3A8A) : const Color(0xFF1F4E3D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.records.length} transaction${item.records.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign₹${_formatCurrency(item.totalAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Details', style: TextStyle(color: Color(0xFF1F4E3D), fontSize: 11, fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF1F4E3D), size: 16),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, TransactionRecord rec) {
    final isTransfer = rec.type == 'TRANSFER';
    final isIncome = rec.type == 'INCOME';
    final dayStr = rec.dateTime.day.toString().padLeft(2, '0');

    String titleText = rec.category;
    if (isTransfer) {
      if (rec.notes.contains('Transfer from') && rec.notes.contains('to')) {
        titleText = '[${rec.notes.split('•').first.trim().replaceAll('Transfer from ', '').replaceAll(' to ', ' > ')}]';
      } else {
        titleText = '[${rec.accountName} > ${rec.category.replaceAll('Transfer to ', '')}]';
      }
    }

    Color amountColor;
    String sign;
    if (isTransfer) {
      amountColor = const Color(0xFF1E3A8A); // Blue for Transfer matching screenshot
      sign = '';
    } else if (isIncome) {
      amountColor = const Color(0xFF166534); // Green for Income
      sign = '';
    } else {
      amountColor = const Color(0xFFB91C1C); // Red for Expense
      sign = '-';
    }

    return InkWell(
      onTap: () {
        _showTransactionDetailModal(context, rec);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                dayStr,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: isTransfer
                  ? const Color(0xFFDBEAFE)
                  : (isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz_rounded
                    : (isIncome ? Icons.attach_money_rounded : Icons.shopping_bag_rounded),
                color: isTransfer
                    ? const Color(0xFF1E40AF)
                    : (isIncome ? const Color(0xFF166534) : const Color(0xFFB91C1C)),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isTransfer ? const Color(0xFF1E3A8A) : const Color(0xFF1F4E3D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign₹${_formatCurrency(rec.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPickerForRecord(BuildContext context, TransactionRecord rec, StateSetter setModalState) {
    final accountsList = widget.accounts ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (accountsList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No accounts available.', style: TextStyle(color: Color(0xFF1F4E3D))),
              )
            else
              ...accountsList.map(
                (acc) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: acc.iconBgColor,
                    child: Icon(acc.icon, color: acc.iconColor, size: 20),
                  ),
                  title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: acc.name == rec.accountName
                      ? const Icon(Icons.check_circle, color: Color(0xFF1F4E3D))
                      : null,
                  onTap: () {
                    if (widget.onUpdateRecord != null) {
                      widget.onUpdateRecord!(rec, acc.name, rec.category);
                    } else {
                      rec.accountName = acc.name;
                    }
                    setModalState(() {});
                    setState(() {});
                    Navigator.pop(sheetCtx);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPickerForRecord(BuildContext context, TransactionRecord rec, StateSetter setModalState) {
    final filteredCategories = widget.categories.where((c) => c.type == rec.type).toList();
    final categoriesList = filteredCategories.isNotEmpty ? filteredCategories : widget.categories;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...categoriesList.map(
              (cat) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.bgColor,
                  radius: 16,
                  child: Icon(cat.icon, color: Colors.white, size: 16),
                ),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: cat.name == rec.category
                    ? const Icon(Icons.check_circle, color: Color(0xFF1F4E3D))
                    : null,
                onTap: () {
                  if (widget.onUpdateRecord != null) {
                    widget.onUpdateRecord!(rec, rec.accountName, cat.name);
                  } else {
                    rec.category = cat.name;
                  }
                  setModalState(() {});
                  setState(() {});
                  Navigator.pop(sheetCtx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailModal(BuildContext context, TransactionRecord rec) {
    final isExpense = rec.type == 'EXPENSE';
    final isIncome = rec.type == 'INCOME';
    final headerColor = isExpense
        ? const Color(0xFFDC2626)
        : (isIncome ? const Color(0xFF166534) : const Color(0xFF0369A1));

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mStr = months[rec.dateTime.month - 1];
    final dStr = rec.dateTime.day.toString().padLeft(2, '0');
    final yStr = rec.dateTime.year;
    final hour = rec.dateTime.hour > 12 ? rec.dateTime.hour - 12 : (rec.dateTime.hour == 0 ? 12 : rec.dateTime.hour);
    final ampm = rec.dateTime.hour >= 12 ? 'PM' : 'AM';
    final minStr = rec.dateTime.minute.toString().padLeft(2, '0');
    final dateTimeFormatted = '$mStr $dStr, $yStr $hour:$minStr $ampm';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final catObj = widget.categories.firstWhere(
              (c) => c.name == rec.category,
              orElse: () => CategoryItem(
                id: 'cat_def',
                name: rec.category,
                type: rec.type,
                icon: isExpense ? Icons.school_rounded : Icons.payments_rounded,
                bgColor: headerColor,
              ),
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7E6),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. TOP HEADER CONTAINER
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDeleteRecord != null) {
                                        widget.onDeleteRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.post_add_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDuplicateRecord != null) {
                                        widget.onDuplicateRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      if (widget.onEditRecord != null) {
                                        await widget.onEditRecord!(rec);
                                        if (mounted) setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            rec.type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            '${isExpense ? '-' : (isIncome ? '+' : '')}₹${_formatCurrency(rec.amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              dateTimeFormatted,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. BOTTOM BODY SECTION
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Account',
                                style: TextStyle(
                                  color: Color(0xFF1F4E3D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              InkWell(
                                onTap: () => _showAccountPickerForRecord(context, rec, setModalState),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7E6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_outlined, color: Color(0xFF1F4E3D), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        rec.accountName,
                                        style: const TextStyle(
                                          color: Color(0xFF1F4E3D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(
                                  color: Color(0xFF1F4E3D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              InkWell(
                                onTap: () => _showCategoryPickerForRecord(context, rec, setModalState),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7E6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: catObj.bgColor,
                                        child: Icon(catObj.icon, size: 12, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        rec.category,
                                        style: const TextStyle(
                                          color: Color(0xFF1F4E3D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          if (rec.notes.isNotEmpty)
                            Text(
                              rec.notes,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF52796F),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final regEx = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(regEx, (Match m) => '${m[1]},');
    return '$formattedInt.$decPart';
  }
}

// ============================================================================
// ACCOUNT GROUP DETAILS DRILL-DOWN SCREEN (SUMMARY CLICK DETAIL VIEW)
// ============================================================================
class AccountGroupDetailsScreen extends StatefulWidget {
  final String title;
  final String accountName;
  final List<TransactionRecord> records;
  final List<CategoryItem> categories;
  final List<AccountItem>? accounts;
  final Function(TransactionRecord)? onDeleteRecord;
  final Function(TransactionRecord)? onEditRecord;
  final Function(TransactionRecord)? onDuplicateRecord;
  final Function(TransactionRecord, String, String)? onUpdateRecord;

  const AccountGroupDetailsScreen({
    super.key,
    required this.title,
    required this.accountName,
    required this.records,
    required this.categories,
    this.accounts,
    this.onDeleteRecord,
    this.onEditRecord,
    this.onDuplicateRecord,
    this.onUpdateRecord,
  });

  @override
  State<AccountGroupDetailsScreen> createState() => _AccountGroupDetailsScreenState();
}

class _AccountGroupDetailsScreenState extends State<AccountGroupDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final double totalAmount = widget.records.fold(0.0, (s, r) => s + r.amount);

    final Map<String, List<TransactionRecord>> groupedRecords = {};
    for (var rec in widget.records) {
      final key = '${_monthName(rec.dateTime.month)} ${rec.dateTime.year}';
      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = [];
      }
      groupedRecords[key]!.add(rec);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F4E3D), size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Total: ₹${_formatCurrency(totalAmount)} (${widget.records.length} transactions)',
              style: const TextStyle(
                color: Color(0xFF52796F),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: widget.records.isEmpty
          ? const Center(
              child: Text('No transactions found in this category.', style: TextStyle(color: Color(0xFF1F4E3D))),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: groupedRecords.entries.map((entry) {
                final monthYearStr = entry.key;
                final monthRecs = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthYearStr,
                            style: const TextStyle(
                              color: Color(0xFF1F4E3D),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(height: 1.5, color: const Color(0xFF1F4E3D)),
                        ],
                      ),
                    ),
                    ...monthRecs.map((rec) => _buildTransactionRow(context, rec)),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, TransactionRecord rec) {
    final isTransfer = rec.type == 'TRANSFER';
    final isIncome = rec.type == 'INCOME';
    final dayStr = rec.dateTime.day.toString().padLeft(2, '0');

    String titleText = rec.category;
    if (isTransfer) {
      if (rec.notes.contains('Transfer from') && rec.notes.contains('to')) {
        titleText = '[${rec.notes.split('•').first.trim().replaceAll('Transfer from ', '').replaceAll(' to ', ' > ')}]';
      } else {
        titleText = '[${rec.accountName} > ${rec.category.replaceAll('Transfer to ', '')}]';
      }
    }

    Color amountColor;
    String sign;
    if (isTransfer) {
      amountColor = const Color(0xFF1E3A8A);
      sign = '';
    } else if (isIncome) {
      amountColor = const Color(0xFF166534);
      sign = '';
    } else {
      amountColor = const Color(0xFFB91C1C);
      sign = '-';
    }

    return InkWell(
      onTap: () => _showTransactionDetailModal(context, rec),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                dayStr,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: isTransfer
                  ? const Color(0xFFDBEAFE)
                  : (isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz_rounded
                    : (isIncome ? Icons.attach_money_rounded : Icons.shopping_bag_rounded),
                color: isTransfer
                    ? const Color(0xFF1E40AF)
                    : (isIncome ? const Color(0xFF166534) : const Color(0xFFB91C1C)),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isTransfer ? const Color(0xFF1E3A8A) : const Color(0xFF1F4E3D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign₹${_formatCurrency(rec.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailModal(BuildContext context, TransactionRecord rec) {
    final isExpense = rec.type == 'EXPENSE';
    final isIncome = rec.type == 'INCOME';
    final headerColor = isExpense
        ? const Color(0xFFDC2626)
        : (isIncome ? const Color(0xFF166534) : const Color(0xFF0369A1));

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mStr = months[rec.dateTime.month - 1];
    final dStr = rec.dateTime.day.toString().padLeft(2, '0');
    final yStr = rec.dateTime.year;
    final hour = rec.dateTime.hour > 12 ? rec.dateTime.hour - 12 : (rec.dateTime.hour == 0 ? 12 : rec.dateTime.hour);
    final ampm = rec.dateTime.hour >= 12 ? 'PM' : 'AM';
    final minStr = rec.dateTime.minute.toString().padLeft(2, '0');
    final dateTimeFormatted = '$mStr $dStr, $yStr $hour:$minStr $ampm';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7E6),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDeleteRecord != null) {
                                        widget.onDeleteRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.post_add_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDuplicateRecord != null) {
                                        widget.onDuplicateRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      if (widget.onEditRecord != null) {
                                        await widget.onEditRecord!(rec);
                                        if (mounted) setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rec.type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${isExpense ? '-' : (isIncome ? '+' : '')}₹${_formatCurrency(rec.amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              dateTimeFormatted,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Account', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(rec.accountName, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Category', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(rec.category, style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          if (rec.notes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(rec.notes, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF52796F), fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final regEx = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(regEx, (Match m) => '${m[1]},');
    return '$formattedInt.$decPart';
  }
}

// ============================================================================
// CATEGORY DETAILS FULL SCREEN (MATCHING USER SCREENSHOT EXACTLY)
// ============================================================================
class CategoryDetailsScreen extends StatefulWidget {
  final String categoryName;
  final String type; // 'EXPENSE' or 'INCOME' or 'ALL'
  final int month;
  final int year;
  final List<AccountItem>? accounts;
  final List<TransactionRecord> allRecords;
  final List<CategoryItem> categories;
  final Function(TransactionRecord)? onDeleteRecord;
  final Function(TransactionRecord)? onEditRecord;
  final Function(TransactionRecord)? onDuplicateRecord;
  final Function(TransactionRecord, String, String)? onUpdateRecord;

  const CategoryDetailsScreen({
    super.key,
    required this.categoryName,
    required this.type,
    required this.month,
    required this.year,
    this.accounts,
    required this.allRecords,
    required this.categories,
    this.onDeleteRecord,
    this.onEditRecord,
    this.onDuplicateRecord,
    this.onUpdateRecord,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final filteredRecords = widget.allRecords.where((r) {
      bool matchesType = (widget.type == 'ALL') || (r.type == widget.type);
      bool matchesCategory = (widget.categoryName.contains('Records')) || (r.category == widget.categoryName);
      return matchesType && matchesCategory && r.dateTime.month == widget.month && r.dateTime.year == widget.year;
    }).toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final catObj = widget.categories.firstWhere(
      (c) => c.name == widget.categoryName,
      orElse: () => CategoryItem(
        id: 'c_custom',
        name: widget.categoryName,
        type: widget.type == 'ALL' ? 'EXPENSE' : widget.type,
        icon: widget.type == 'INCOME' ? Icons.school_rounded : Icons.school_rounded,
        bgColor: const Color(0xFF1E293B),
      ),
    );

    final totalMonthExpenses = widget.allRecords
        .where((r) => r.type == 'EXPENSE' && r.dateTime.month == widget.month && r.dateTime.year == widget.year)
        .fold(0.0, (s, r) => s + r.amount);

    final categoryExpenseSum = filteredRecords
        .where((r) => r.type == 'EXPENSE')
        .fold(0.0, (s, r) => s + r.amount);

    final pctValue = totalMonthExpenses > 0 ? (categoryExpenseSum / totalMonthExpenses) * 100 : 0.0;
    final pctStr = '${pctValue.toStringAsFixed(2)}%';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1F4E3D), size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category details',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Time selected: ${_monthName(widget.month)} ${widget.year}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Icon(catObj.icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: const TextStyle(
                        color: Color(0xFF1F4E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.type == 'ALL' ? 'Expense' : widget.type.toLowerCase()} category',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F4E3D).withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  '${_monthName(widget.month)} ${widget.year}',
                  style: const TextStyle(
                    color: Color(0xFF1F4E3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: DonutChartPainter(
                          values: [pctValue, 100 - pctValue],
                          colors: const [Color(0xFF1F4E3D), Color(0xFFE2E8F0)],
                          centerLabel: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      pctStr,
                      style: const TextStyle(
                        color: Color(0xFF1F4E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F4E3D), thickness: 1.2, height: 1),
          if (filteredRecords.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF1F4E3D)),
                  const SizedBox(height: 12),
                  Text(
                    'No entries for "${widget.categoryName}" in ${_monthName(widget.month)} ${widget.year}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            ...filteredRecords.map((rec) {
              final dayStr = rec.dateTime.day.toString().padLeft(2, '0');
              final isExpense = rec.type == 'EXPENSE';
              final isIncome = rec.type == 'INCOME';

              return InkWell(
                onTap: () {
                  _showTransactionDetailModal(context, rec);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          dayStr,
                          style: const TextStyle(
                            color: Color(0xFF52796F),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isExpense
                            ? const Color(0xFFFEE2E2)
                            : (isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE)),
                        child: Icon(
                          isExpense
                              ? Icons.shopping_bag_rounded
                              : (isIncome ? Icons.attach_money_rounded : Icons.swap_horiz_rounded),
                          color: isExpense
                              ? const Color(0xFFB91C1C)
                              : (isIncome ? const Color(0xFF166534) : const Color(0xFF1E40AF)),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.category,
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontWeight: FontWeight.bold,
                                fontSize: 16.5,
                              ),
                            ),
                            if (rec.notes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  rec.notes,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${isExpense ? '-' : (isIncome ? '+' : '')}₹${_formatCurrency(rec.amount)}',
                        style: TextStyle(
                          color: isExpense
                              ? const Color(0xFFB91C1C)
                              : (isIncome ? const Color(0xFF166534) : const Color(0xFF1E3A8A)),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAccountPickerForRecord(BuildContext context, TransactionRecord rec, StateSetter setModalState) {
    final accountsList = widget.accounts ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (accountsList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No accounts available.', style: TextStyle(color: Color(0xFF1F4E3D))),
              )
            else
              ...accountsList.map(
                (acc) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: acc.iconBgColor,
                    child: Icon(acc.icon, color: acc.iconColor, size: 20),
                  ),
                  title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: acc.name == rec.accountName
                      ? const Icon(Icons.check_circle, color: Color(0xFF1F4E3D))
                      : null,
                  onTap: () {
                    if (widget.onUpdateRecord != null) {
                      widget.onUpdateRecord!(rec, acc.name, rec.category);
                    } else {
                      rec.accountName = acc.name;
                    }
                    setModalState(() {});
                    setState(() {});
                    Navigator.pop(sheetCtx);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPickerForRecord(BuildContext context, TransactionRecord rec, StateSetter setModalState) {
    final filteredCategories = widget.categories.where((c) => c.type == rec.type).toList();
    final categoriesList = filteredCategories.isNotEmpty ? filteredCategories : widget.categories;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...categoriesList.map(
              (cat) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.bgColor,
                  radius: 16,
                  child: Icon(cat.icon, color: Colors.white, size: 16),
                ),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: cat.name == rec.category
                    ? const Icon(Icons.check_circle, color: Color(0xFF1F4E3D))
                    : null,
                onTap: () {
                  if (widget.onUpdateRecord != null) {
                    widget.onUpdateRecord!(rec, rec.accountName, cat.name);
                  } else {
                    rec.category = cat.name;
                  }
                  setModalState(() {});
                  setState(() {});
                  Navigator.pop(sheetCtx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailModal(BuildContext context, TransactionRecord rec) {
    final isExpense = rec.type == 'EXPENSE';
    final isIncome = rec.type == 'INCOME';
    final headerColor = isExpense
        ? const Color(0xFFDC2626)
        : (isIncome ? const Color(0xFF166534) : const Color(0xFF0369A1));

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mStr = months[rec.dateTime.month - 1];
    final dStr = rec.dateTime.day.toString().padLeft(2, '0');
    final yStr = rec.dateTime.year;
    final hour = rec.dateTime.hour > 12 ? rec.dateTime.hour - 12 : (rec.dateTime.hour == 0 ? 12 : rec.dateTime.hour);
    final ampm = rec.dateTime.hour >= 12 ? 'PM' : 'AM';
    final minStr = rec.dateTime.minute.toString().padLeft(2, '0');
    final dateTimeFormatted = '$mStr $dStr, $yStr $hour:$minStr $ampm';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final catObj = widget.categories.firstWhere(
              (c) => c.name == rec.category,
              orElse: () => CategoryItem(
                id: 'cat_def',
                name: rec.category,
                type: rec.type,
                icon: isExpense ? Icons.school_rounded : Icons.payments_rounded,
                bgColor: headerColor,
              ),
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7E6),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. TOP HEADER CONTAINER (RED FOR EXPENSE, GREEN FOR INCOME)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDeleteRecord != null) {
                                        widget.onDeleteRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.post_add_rounded, color: Colors.white, size: 22),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (widget.onDuplicateRecord != null) {
                                        widget.onDuplicateRecord!(rec);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      if (widget.onEditRecord != null) {
                                        await widget.onEditRecord!(rec);
                                        if (mounted) setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            rec.type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            '${isExpense ? '-' : (isIncome ? '+' : '')}₹${_formatCurrency(rec.amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              dateTimeFormatted,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. BOTTOM BODY SECTION (CREAM BACKGROUND)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Account',
                                style: TextStyle(
                                  color: Color(0xFF1F4E3D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              InkWell(
                                onTap: () => _showAccountPickerForRecord(context, rec, setModalState),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7E6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_outlined, color: Color(0xFF1F4E3D), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        rec.accountName,
                                        style: const TextStyle(
                                          color: Color(0xFF1F4E3D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(
                                  color: Color(0xFF1F4E3D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              InkWell(
                                onTap: () => _showCategoryPickerForRecord(context, rec, setModalState),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7E6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: catObj.bgColor,
                                        child: Icon(catObj.icon, size: 12, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        rec.category,
                                        style: const TextStyle(
                                          color: Color(0xFF1F4E3D),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1F4E3D), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          if (rec.notes.isNotEmpty)
                            Text(
                              rec.notes,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF52796F),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final regEx = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(regEx, (Match m) => '${m[1]},');
    return '$formattedInt.$decPart';
  }
}

class ContainerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const ContainerIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================
class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleTheme;
  final String selectedCurrency;
  final Function(String) onCurrencyChanged;
  final bool isPasscodeEnabled;
  final Function(bool) onPasscodeToggled;
  final bool isDailyReminder;
  final Function(bool) onReminderToggled;
  final int reminderHour;
  final int reminderMinute;
  final Function(int, int) onReminderTimeChanged;
  final List<AccountItem> accounts;
  final List<TransactionRecord> records;
  final List<CategoryItem> categories;
  final Function(List<AccountItem>, List<TransactionRecord>, List<CategoryItem>) onRestoreBackup;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.isPasscodeEnabled,
    required this.onPasscodeToggled,
    required this.isDailyReminder,
    required this.onReminderToggled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.onReminderTimeChanged,
    required this.accounts,
    required this.records,
    required this.categories,
    required this.onRestoreBackup,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDark;
  late String _currency;
  late bool _passcode;
  late bool _dailyReminder;
  late int _remHour;
  late int _remMin;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _currency = widget.selectedCurrency;
    _passcode = widget.isPasscodeEnabled;
    _dailyReminder = widget.isDailyReminder;
    _remHour = widget.reminderHour;
    _remMin = widget.reminderMinute;
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final Color cardBg = _isDark ? const Color(0xFF1A2622) : const Color(0xFFFDF6D8);
    final Color cardBorder = _isDark ? const Color(0xFF2E483E) : const Color(0xFF1F4E3D);
    final Color primaryTextColor = _isDark ? Colors.white : const Color(0xFF1F4E3D);
    final Color secondaryTextColor = _isDark ? const Color(0xFF94A3B8) : Colors.black54;
    final Color iconColor = _isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D);
    final Color sectionHeaderColor = _isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D);
    final Color dividerColor = _isDark ? const Color(0xFF2E483E) : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0F1715) : const Color(0xFFFAF7E6),
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF0F1715) : const Color(0xFFFAF7E6),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings & Preferences',
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('GENERAL PREFERENCES', sectionHeaderColor),
          _settingsCard([
            ListTile(
              leading: Icon(Icons.dark_mode_outlined, color: iconColor),
              title: Text('Dark Mode Theme', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              trailing: Switch(
                value: _isDark,
                activeColor: _isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D),
                onChanged: (val) {
                  setState(() => _isDark = val);
                  widget.onToggleTheme(val);
                },
              ),
            ),
            Divider(height: 1, color: dividerColor),
            ListTile(
              leading: Icon(Icons.attach_money_rounded, color: iconColor),
              title: Text('Main Currency', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              subtitle: Text(_currency, style: TextStyle(color: secondaryTextColor)),
              trailing: Icon(Icons.chevron_right, color: iconColor),
              onTap: () => _showCurrencyPicker(context, _isDark, cardBg, primaryTextColor),
            ),
          ], cardBg, cardBorder),
          const SizedBox(height: 20),
          _sectionTitle('SECURITY & BACKUP', sectionHeaderColor),
          _settingsCard([
            ListTile(
              leading: Icon(Icons.lock_outline_rounded, color: iconColor),
              title: Text('Passcode Protection', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              subtitle: Text('Require passcode on launch', style: TextStyle(color: secondaryTextColor)),
              trailing: Switch(
                value: _passcode,
                activeColor: _isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D),
                onChanged: (val) {
                  setState(() => _passcode = val);
                  widget.onPasscodeToggled(val);
                },
              ),
            ),
            Divider(height: 1, color: dividerColor),
            ListTile(
              leading: Icon(Icons.cloud_upload_outlined, color: iconColor),
              title: Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              subtitle: Text('Cloud backup & local export', style: TextStyle(color: secondaryTextColor)),
              trailing: Icon(Icons.chevron_right, color: iconColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BackupRestoreScreen(
                      accounts: widget.accounts,
                      records: widget.records,
                      categories: widget.categories,
                      onRestoreBackup: widget.onRestoreBackup,
                      isDarkMode: _isDark,
                    ),
                  ),
                );
              },
            ),
          ], cardBg, cardBorder),
          const SizedBox(height: 20),
          _sectionTitle('NOTIFICATIONS', sectionHeaderColor),
          _settingsCard([
            ListTile(
              leading: Icon(Icons.notifications_active_outlined, color: iconColor),
              title: Text('Daily Reminders', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              subtitle: Text(
                _dailyReminder
                    ? 'Reminds daily at ${_formatTime(_remHour, _remMin)}'
                    : 'Reminders turned off',
                style: TextStyle(color: secondaryTextColor),
              ),
              trailing: Switch(
                value: _dailyReminder,
                activeColor: _isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D),
                onChanged: (val) {
                  setState(() => _dailyReminder = val);
                  widget.onReminderToggled(val);
                  if (val) {
                    NotificationService().scheduleDailyNotification(_remHour, _remMin);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Daily reminder scheduled for ${_formatTime(_remHour, _remMin)}!'),
                        backgroundColor: const Color(0xFF166534),
                      ),
                    );
                  } else {
                    NotificationService().cancelDailyNotification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily reminders disabled.')),
                    );
                  }
                },
              ),
            ),
            if (_dailyReminder) ...[
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: Icon(Icons.access_time_rounded, color: iconColor),
                title: Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                subtitle: Text('Set time: ${_formatTime(_remHour, _remMin)}', style: TextStyle(color: secondaryTextColor)),
                trailing: Icon(Icons.edit_calendar_rounded, color: iconColor),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _remHour, minute: _remMin),
                  );
                  if (picked != null) {
                    setState(() {
                      _remHour = picked.hour;
                      _remMin = picked.minute;
                    });
                    widget.onReminderTimeChanged(picked.hour, picked.minute);
                    NotificationService().scheduleDailyNotification(picked.hour, picked.minute);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Daily reminder time set to ${_formatTime(picked.hour, picked.minute)}!'),
                        backgroundColor: const Color(0xFF166534),
                      ),
                    );
                  }
                },
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: Icon(Icons.send_rounded, color: _isDark ? const Color(0xFF34D399) : const Color(0xFF166534)),
                title: Text(
                  'Test Notification Now',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isDark ? const Color(0xFF34D399) : const Color(0xFF166534)),
                ),
                subtitle: Text('Send a live test reminder to your phone', style: TextStyle(color: secondaryTextColor)),
                trailing: Icon(Icons.chevron_right, color: _isDark ? const Color(0xFF34D399) : const Color(0xFF166534)),
                onTap: () async {
                  await NotificationService().showTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent to your phone!'),
                      backgroundColor: Color(0xFF166534),
                    ),
                  );
                },
              ),
            ],
          ], cardBg, cardBorder),
          const SizedBox(height: 20),
          _sectionTitle('ABOUT APP', sectionHeaderColor),
          _settingsCard([
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: iconColor),
              title: Text('App Version', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              subtitle: Text('MyFinances v1.0.0 (Local Memory Active)', style: TextStyle(color: secondaryTextColor)),
            ),
            Divider(height: 1, color: dividerColor),
            ListTile(
              leading: Icon(Icons.star_outline_rounded, color: iconColor),
              title: Text('Rate MyFinances', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
              trailing: Icon(Icons.chevron_right, color: iconColor),
              onTap: () {},
            ),
          ], cardBg, cardBorder),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children, Color bg, Color border) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(children: children),
    );
  }

  void _showCurrencyPicker(BuildContext context, bool isDark, Color dialogBg, Color textColor) {
    final currencies = ['₹ INR', r'$ USD', '€ EUR', '£ GBP', '¥ JPY', r'A$ AUD'];
    showModalBottomSheet(
      context: context,
      backgroundColor: dialogBg,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: currencies
            .map(
              (c) => ListTile(
                title: Text(c, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                trailing: _currency == c ? Icon(Icons.check, color: isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D)) : null,
                onTap: () {
                  setState(() => _currency = c);
                  widget.onCurrencyChanged(c);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================================
// DEDICATED BACKUP & RESTORE SCREEN (MATCHING USER SCREENSHOT EXACTLY)
// ============================================================================
class BackupRestoreScreen extends StatefulWidget {
  final List<AccountItem> accounts;
  final List<TransactionRecord> records;
  final List<CategoryItem> categories;
  final Function(List<AccountItem>, List<TransactionRecord>, List<CategoryItem>) onRestoreBackup;
  final bool isDarkMode;

  const BackupRestoreScreen({
    super.key,
    required this.accounts,
    required this.records,
    required this.categories,
    required this.onRestoreBackup,
    this.isDarkMode = false,
  });

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  String? _selectedDirectoryPath;

  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
  }

  Future<void> _loadSavedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDirectoryPath = prefs.getString('backup_directory_path') ?? '/storage/emulated/0/Download';
    });
  }

  Future<void> _selectDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Directory Path',
      );
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backup_directory_path', selectedDirectory);
        setState(() {
          _selectedDirectoryPath = selectedDirectory;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup directory path updated to: $selectedDirectory'),
            backgroundColor: const Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      _showManualDirectoryDialog();
    }
  }

  void _showManualDirectoryDialog() {
    final textController = TextEditingController(text: _selectedDirectoryPath ?? '/storage/emulated/0/Download');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Backup Directory Path', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter local phone folder or Google Drive path:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '/storage/emulated/0/Download',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E3D), foregroundColor: Colors.white),
            onPressed: () async {
              if (textController.text.trim().isNotEmpty) {
                final newPath = textController.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('backup_directory_path', newPath);
                setState(() {
                  _selectedDirectoryPath = newPath;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backup Path set to: $newPath'), backgroundColor: const Color(0xFF166534)),
                );
              }
            },
            child: const Text('SAVE PATH', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackupNow() async {
    try {
      final backupData = {
        'app': 'MyFinances',
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'accounts': widget.accounts.map((a) => a.toJson()).toList(),
        'records': widget.records.map((r) => r.toJson()).toList(),
        'categories': widget.categories.map((c) => c.toJson()).toList(),
      };

      final jsonEncoder = const JsonEncoder.withIndent('  ');
      final jsonString = jsonEncoder.convert(backupData);
      
      // Also generate CSV string
      final csvString = _generateCsvBackupString();

      final now = DateTime.now();
      final dateSuffix = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final mbakFileName = 'MyFinances_Backup_$dateSuffix.mbak';
      final jsonFileName = 'MyFinances_Backup_$dateSuffix.json';
      final csvFileName = 'MyFinances_Backup_$dateSuffix.csv';

      List<String> savedLocations = [];

      // List of target directories to write to so files are guaranteed visible
      List<String> targetDirs = [];
      if (_selectedDirectoryPath != null && _selectedDirectoryPath!.isNotEmpty) {
        targetDirs.add(_selectedDirectoryPath!);
      }
      targetDirs.addAll([
        '/storage/emulated/0/Download/MyFinances',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents/MyFinances',
        '/storage/emulated/0/Documents',
      ]);

      for (var dirPath in targetDirs) {
        if (kIsWeb) break;
        try {
          final dir = Directory(dirPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          // Write .mbak file
          final mbakFile = File('${dir.path}/$mbakFileName');
          await mbakFile.writeAsString(jsonString);

          // Write .json file (easy to see in file managers)
          final jsonFile = File('${dir.path}/$jsonFileName');
          await jsonFile.writeAsString(jsonString);

          // Write .csv file (easy to view in Excel / Sheets)
          final csvFile = File('${dir.path}/$csvFileName');
          await csvFile.writeAsString(csvString);

          if (!savedLocations.contains(dir.path)) {
            savedLocations.add(dir.path);
          }
        } catch (_) {}
      }

      String finalPathDisplay = savedLocations.isNotEmpty
          ? savedLocations.first
          : (_selectedDirectoryPath ?? '/storage/emulated/0/Download');

      _showBackupCreatedDialog(finalPathDisplay, mbakFileName, jsonString);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup error: $e'), backgroundColor: const Color(0xFFB91C1C)),
      );
    }
  }

  String _generateCsvBackupString() {
    StringBuffer sb = StringBuffer();
    sb.writeln('RecordType,AccountName,Category,Amount,Notes,Date,Id');
    for (var acc in widget.accounts) {
      sb.writeln('ACCOUNT,"${acc.name}",ACCOUNT,${acc.balance},"","${DateTime.now().toIso8601String()}","${acc.id}"');
    }
    for (var cat in widget.categories) {
      sb.writeln('CATEGORY,"${cat.name}","${cat.type}",0,"","${DateTime.now().toIso8601String()}","${cat.id}"');
    }
    for (var rec in widget.records) {
      String escapedNotes = rec.notes.replaceAll('"', '""');
      sb.writeln('${rec.type},"${rec.accountName}","${rec.category}",${rec.amount},"$escapedNotes","${rec.dateTime.toIso8601String()}","${rec.id}"');
    }
    return sb.toString();
  }

  void _showBackupCreatedDialog(String folderPath, String fileName, String jsonContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 28),
            SizedBox(width: 10),
            Text('Backup Created!', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your backup files have been created in 3 formats (.mbak, .json, .csv):',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF1F4E3D)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF6D8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁 File Location:', style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    folderPath,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D), fontSize: 13),
                  ),
                  const Divider(height: 16),
                  const Text('📄 Saved Files:', style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('• $fileName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1F4E3D))),
                  Text('• ${fileName.replaceAll('.mbak', '.json')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1F4E3D))),
                  Text('• ${fileName.replaceAll('.mbak', '.csv')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1F4E3D))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '💡 Tip: Open your phone\'s "My Files" or "Files" app -> go to Internal Storage -> Download or Documents folder.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: folderPath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Folder path copied to clipboard!'), backgroundColor: Color(0xFF166534)),
              );
            },
            child: const Text('COPY PATH', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E3D), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK GOT IT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _processImportJson(String jsonStr) {
    try {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      List<AccountItem> newAccounts = [];
      if (jsonMap.containsKey('accounts') && jsonMap['accounts'] is List) {
        final list = jsonMap['accounts'] as List;
        newAccounts = list.map((a) => AccountItem.fromJson(Map<String, dynamic>.from(a))).toList();
      }

      List<TransactionRecord> newRecords = [];
      if (jsonMap.containsKey('records') && jsonMap['records'] is List) {
        final list = jsonMap['records'] as List;
        newRecords = list.map((r) => TransactionRecord.fromJson(Map<String, dynamic>.from(r))).toList();
      }

      List<CategoryItem> newCategories = [];
      if (jsonMap.containsKey('categories') && jsonMap['categories'] is List) {
        final list = jsonMap['categories'] as List;
        newCategories = list.map((c) => CategoryItem.fromJson(Map<String, dynamic>.from(c))).toList();
      }

      if (newAccounts.isEmpty && newRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid backup file! No accounts or records found.'), backgroundColor: Color(0xFFB91C1C)),
        );
        return;
      }

      widget.onRestoreBackup(
        newAccounts.isNotEmpty ? newAccounts : widget.accounts,
        newRecords.isNotEmpty ? newRecords : widget.records,
        newCategories.isNotEmpty ? newCategories : widget.categories,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup Restored Successfully! ${newAccounts.length} accounts & ${newRecords.length} transactions loaded.'),
          backgroundColor: const Color(0xFF166534),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring backup file: $e'), backgroundColor: const Color(0xFFB91C1C)),
      );
    }
  }

  void _processImportCsv(String csvStr) {
    try {
      final lines = csvStr.split(RegExp(r'\r?\n'));
      if (lines.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty!'), backgroundColor: Color(0xFFB91C1C)),
        );
        return;
      }

      List<AccountItem> newAccounts = [];
      List<TransactionRecord> newRecords = [];
      List<CategoryItem> newCategories = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.startsWith('RecordType')) continue;

        final cols = _parseCsvLine(line);
        if (cols.length < 4) continue;

        String type = cols[0].trim().toUpperCase();
        String col1 = cols[1].trim();
        String col2 = cols[2].trim();
        double amount = double.tryParse(cols[3].trim()) ?? 0.0;
        String notes = cols.length > 4 ? cols[4].trim() : '';
        String dateStr = cols.length > 5 ? cols[5].trim() : '';
        String idStr = cols.length > 6 ? cols[6].trim() : DateTime.now().millisecondsSinceEpoch.toString();

        DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();

        if (type == 'ACCOUNT') {
          if (col1.isNotEmpty && !newAccounts.any((a) => a.name == col1)) {
            newAccounts.add(
              AccountItem(
                id: idStr.isNotEmpty ? idStr : DateTime.now().millisecondsSinceEpoch.toString(),
                name: col1,
                balance: amount,
                icon: Icons.account_balance_wallet_rounded,
                iconBgColor: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0369A1),
              ),
            );
          }
        } else if (type == 'CATEGORY') {
          if (col1.isNotEmpty && !newCategories.any((c) => c.name == col1)) {
            newCategories.add(
              CategoryItem(
                id: idStr.isNotEmpty ? idStr : DateTime.now().millisecondsSinceEpoch.toString(),
                name: col1,
                type: col2 == 'INCOME' ? 'INCOME' : 'EXPENSE',
                icon: col2 == 'INCOME' ? Icons.payments_rounded : Icons.shopping_bag_rounded,
                bgColor: col2 == 'INCOME' ? const Color(0xFF166534) : const Color(0xFFB91C1C),
              ),
            );
          }
        } else if (['INCOME', 'EXPENSE', 'TRANSFER'].contains(type)) {
          newRecords.add(
            TransactionRecord(
              id: idStr.isNotEmpty ? idStr : DateTime.now().millisecondsSinceEpoch.toString(),
              type: type,
              accountName: col1,
              category: col2,
              amount: amount,
              notes: notes,
              dateTime: dt,
            ),
          );
        }
      }

      if (newAccounts.isEmpty && newRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No records parsed from CSV file!'), backgroundColor: Color(0xFFB91C1C)),
        );
        return;
      }

      widget.onRestoreBackup(
        newAccounts.isNotEmpty ? newAccounts : widget.accounts,
        newRecords.isNotEmpty ? newRecords : widget.records,
        newCategories.isNotEmpty ? newCategories : widget.categories,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV Backup Restored! Loaded ${newAccounts.length} accounts & ${newRecords.length} transactions.'),
          backgroundColor: const Color(0xFF166534),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing CSV file: $e'), backgroundColor: const Color(0xFFB91C1C)),
      );
    }
  }

  List<String> _parseCsvLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      String c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }

  void _showManualPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Paste Backup File Content', style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: textController,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste .mbak, JSON, or CSV text here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E3D), foregroundColor: Colors.white),
            onPressed: () {
              final txt = textController.text.trim();
              if (txt.isNotEmpty) {
                Navigator.pop(context);
                if (txt.startsWith('{') || txt.contains('"accounts"')) {
                  _processImportJson(txt);
                } else {
                  _processImportCsv(txt);
                }
              }
            },
            child: const Text('RESTORE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Backup File (.mbak, .json, .csv)',
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content = '';

        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          final f = File(file.path!);
          content = await f.readAsString();
        }

        if (content.isNotEmpty) {
          final txt = content.trim();
          if (txt.startsWith('{') || txt.contains('"accounts"')) {
            _processImportJson(txt);
          } else {
            _processImportCsv(txt);
          }
        }
      }
    } catch (e) {
      _showManualPasteDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1F4E3D);
    final Color iconColor = isDark ? const Color(0xFF34D399) : const Color(0xFF1F4E3D);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Backup & Restore',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // TOP GRAPHIC BANNER MATCHING SCREENSHOT
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.article_outlined, color: Color(0xFF1F4E3D), size: 38),
                    SizedBox(height: 4),
                    Text(
                      '.mbak',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D), fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.sync_alt_rounded, color: Color(0xFF1F4E3D), size: 30),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5, style: BorderStyle.solid),
                ),
                child: const Text(
                  'MyFinances',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E3D),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // BULLET POINTS INSTRUCTION BOX (MATCHING SCREENSHOT)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6D8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletItem(
                  text: 'A backup file contains all your records, categories, accounts & budgets (at the time of backup). Using this file, you can restore the saved data later in case your device is lost or you accidentally uninstall the app.',
                ),
                SizedBox(height: 12),
                _BulletItem(
                  text: 'Select a backup directory where you want MyFinances to create backup files and search for backup files to restore.',
                ),
                SizedBox(height: 12),
                _BulletItem(
                  text: 'To make a backup, press BACKUP NOW, and MyFinances will create a single backup file (.mbak) inside your backup directory.',
                ),
                SizedBox(height: 12),
                _BulletItem(
                  text: 'To restore a backup file, make sure that the file (.mbak) exists inside your selected backup directory.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // SELECTED BACKUP DIRECTORY DISPLAY BOX
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: Color(0xFF1F4E3D), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Backup Directory:',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF52796F), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedDirectoryPath ?? '/storage/emulated/0/Download',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F4E3D)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // THREE PILL BUTTONS (MATCHING SCREENSHOT EXACTLY)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
            ),
            onPressed: _handleBackupNow,
            child: const Text(
              'BACKUP NOW',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 14),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
            ),
            onPressed: _handleRestore,
            child: const Text(
              'RESTORE',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 14),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF1F4E3D), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
            ),
            onPressed: _selectDirectory,
            child: const Text(
              'SELECT/CHANGE DIRECTORY',
              style: TextStyle(
                color: Color(0xFF1F4E3D),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // FOOTER NOTE WITH INFO ICON
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF52796F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MyFinances will create new backup files in your selected directory.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF52796F), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F4E3D))),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF1F4E3D),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ADD TRANSACTION MODAL / KEYPAD SHEET (MATCHING USER SCREENSHOTS)
// ============================================================================
class AddTransactionSheet extends StatefulWidget {
  final List<AccountItem> accounts;
  final List<CategoryItem> categories;
  final Function(TransactionRecord, {String? toAccountName}) onSaveWithToAccount;

  const AddTransactionSheet({
    super.key,
    required this.accounts,
    required this.categories,
    required this.onSaveWithToAccount,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  String _selectedType = 'EXPENSE';
  late String _selectedAccount;
  late String _toAccount;
  String _selectedCategory = 'Category';
  final TextEditingController _notesController = TextEditingController();
  String _amountString = '0';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedAccount = widget.accounts.isNotEmpty ? widget.accounts.first.name : 'Account';
    if (widget.accounts.length > 1) {
      _toAccount = widget.accounts[1].name;
    } else if (widget.accounts.isNotEmpty) {
      _toAccount = widget.accounts.first.name;
    } else {
      _toAccount = 'Select Account';
    }

    final expenseCats = widget.categories.where((c) => c.type == 'EXPENSE').toList();
    if (expenseCats.isNotEmpty) {
      _selectedCategory = expenseCats.first.name;
    }
  }

  void _onKeyPress(String val) {
    setState(() {
      if (val == 'BACK') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = '0';
        }
      } else if (val == '=') {
        try {
          String evalStr = _amountString.replaceAll('×', '*').replaceAll('÷', '/');
          _amountString = _evaluateSimpleExpression(evalStr);
        } catch (_) {}
      } else {
        if (_amountString == '0' && val != '.') {
          _amountString = val;
        } else {
          _amountString += val;
        }
      }
    });
  }

  String _evaluateSimpleExpression(String expr) {
    if (expr.contains('+')) {
      final parts = expr.split('+');
      final double sum = parts.fold(0.0, (s, p) => s + (double.tryParse(p.trim()) ?? 0.0));
      return sum.toStringAsFixed(0);
    } else if (expr.contains('-')) {
      final parts = expr.split('-');
      double result = double.tryParse(parts[0].trim()) ?? 0.0;
      for (int i = 1; i < parts.length; i++) {
        result -= (double.tryParse(parts[i].trim()) ?? 0.0);
      }
      return result.toStringAsFixed(0);
    } else if (expr.contains('*')) {
      final parts = expr.split('*');
      double result = 1.0;
      for (var p in parts) {
        result *= (double.tryParse(p.trim()) ?? 1.0);
      }
      return result.toStringAsFixed(0);
    }
    return expr;
  }

  void _handleSave() {
    final double amount = double.tryParse(_amountString) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    if (_selectedType == 'TRANSFER') {
      if (_toAccount == 'Category' || _toAccount == 'Select Account' || _toAccount.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid "To" Account for money transfer!')),
        );
        return;
      }
      if (_selectedAccount == _toAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source "From" and Destination "To" accounts cannot be the same!')),
        );
        return;
      }

      widget.onSaveWithToAccount(
        TransactionRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'TRANSFER',
          accountName: _selectedAccount,
          category: 'Transfer to $_toAccount',
          amount: amount,
          notes: _notesController.text.isNotEmpty
              ? 'Transfer from $_selectedAccount to $_toAccount • ${_notesController.text}'
              : 'Transfer from $_selectedAccount to $_toAccount',
          dateTime: _selectedDate,
        ),
        toAccountName: _toAccount,
      );
      Navigator.pop(context);
    } else {
      widget.onSaveWithToAccount(
        TransactionRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: _selectedType,
          accountName: _selectedAccount,
          category: _selectedCategory == 'Category' ? 'General' : _selectedCategory,
          amount: amount,
          notes: _notesController.text.isNotEmpty ? _notesController.text : '',
          dateTime: _selectedDate,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickTransactionDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7E6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // TOP BAR: CANCEL & SAVE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    children: [
                      Icon(Icons.close, color: Color(0xFF1F4E3D), size: 22),
                      SizedBox(width: 4),
                      Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _handleSave,
                  child: const Row(
                    children: [
                      Icon(Icons.check, color: Color(0xFF1F4E3D), size: 22),
                      SizedBox(width: 4),
                      Text(
                        'SAVE',
                        style: TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // TYPE SWITCHER: INCOME | EXPENSE | TRANSFER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeTab('INCOME'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('|', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
              ),
              _buildTypeTab('EXPENSE'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('|', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
              ),
              _buildTypeTab('TRANSFER'),
            ],
          ),

          const SizedBox(height: 14),

          // LABELS ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedType == 'TRANSFER' ? 'From Account' : 'Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedType == 'TRANSFER' ? 'To Account' : 'Category',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // TWO SELECTION BOXES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showAccountPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1F4E3D), size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedAccount,
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectedType == 'TRANSFER' ? _showToAccountPicker : _showCategoryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedType == 'TRANSFER' ? Icons.account_balance_wallet_outlined : Icons.label_outlined,
                            color: const Color(0xFF1F4E3D),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedType == 'TRANSFER' ? _toAccount : _selectedCategory,
                              style: const TextStyle(
                                color: Color(0xFF1F4E3D),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // NOTES INPUT FIELD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF6D8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add notes',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // CALCULATOR DISPLAY BOX
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _amountString,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1F4E3D),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _onKeyPress('BACK'),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1F4E3D), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.backspace_outlined, color: Color(0xFF1F4E3D), size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // CALCULATOR KEYPAD GRID
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Expanded(child: _buildKeypadRow(['+', '7', '8', '9'])),
                  const SizedBox(height: 8),
                  Expanded(child: _buildKeypadRow(['-', '4', '5', '6'])),
                  const SizedBox(height: 8),
                  Expanded(child: _buildKeypadRow(['×', '1', '2', '3'])),
                  const SizedBox(height: 8),
                  Expanded(child: _buildKeypadRow(['÷', '0', '.', '='])),
                ],
              ),
            ),
          ),

          // DATE & TIME FOOTER
          GestureDetector(
            onTap: _pickTransactionDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1F4E3D), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF1F4E3D)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(
                          color: Color(0xFF1F4E3D),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1.5, height: 18, color: const Color(0xFF1F4E3D)),
                  Text(
                    _formatTime(_selectedDate),
                    style: const TextStyle(
                      color: Color(0xFF1F4E3D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type) {
    final bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (type == 'TRANSFER') {
            if (_toAccount == 'Category' || _toAccount.isEmpty) {
              if (widget.accounts.length > 1) {
                _toAccount = widget.accounts.firstWhere(
                  (a) => a.name != _selectedAccount,
                  orElse: () => widget.accounts.first,
                ).name;
              } else {
                _toAccount = 'Select Account';
              }
            }
          } else {
            final validCats = widget.categories.where((c) => c.type == type).toList();
            if (validCats.isNotEmpty) {
              _selectedCategory = validCats.first.name;
            } else {
              _selectedCategory = 'Category';
            }
          }
        });
      },
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check_circle, color: Color(0xFF1F4E3D), size: 18),
          if (isSelected) const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(
              color: const Color(0xFF1F4E3D),
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final bool isOperator = ['+', '-', '×', '÷', '='].contains(key);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => _onKeyPress(key),
              child: Container(
                decoration: BoxDecoration(
                  color: isOperator
                      ? const Color(0xFF4B7B6E)
                      : const Color(0xFFFDF6D8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F4E3D), width: 1.2),
                ),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      color: isOperator ? Colors.white : const Color(0xFF1F4E3D),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _selectedType == 'TRANSFER' ? 'Select "From" Account' : 'Select Account',
              style: const TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...widget.accounts.map(
              (acc) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: acc.iconBgColor,
                  child: Icon(acc.icon, color: acc.iconColor, size: 20),
                ),
                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Balance: ₹${acc.balance.toStringAsFixed(2)}'),
                onTap: () {
                  setState(() {
                    _selectedAccount = acc.name;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Select "To" Account',
              style: TextStyle(color: Color(0xFF1F4E3D), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...widget.accounts.map(
              (acc) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: acc.iconBgColor,
                  child: Icon(acc.icon, color: acc.iconColor, size: 20),
                ),
                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Balance: ₹${acc.balance.toStringAsFixed(2)}'),
                onTap: () {
                  setState(() {
                    _toAccount = acc.name;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    final filteredCategories = widget.categories
        .where((c) => c.type == _selectedType)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7E6),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: (filteredCategories.isNotEmpty ? filteredCategories : widget.categories)
            .map(
              (cat) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.bgColor,
                  radius: 16,
                  child: Icon(cat.icon, color: Colors.white, size: 16),
                ),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(cat.type, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  setState(() {
                    _selectedCategory = cat.name;
                  });
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
