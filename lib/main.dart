from pathlib import Path

code = r'''import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SalonManagerApp());

// ============================================================
// ETHIOPIAN CALENDAR
// ============================================================

class EthiopianDate {
  final int year;
  final int month;
  final int day;

  const EthiopianDate(this.year, this.month, this.day);

  static const monthNames = [
    '',
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሣሥ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜን',
  ];

  String get monthName => monthNames[month];
}

EthiopianDate gregorianToEthiopian(DateTime date) {
  final jd = _gregorianToJd(date.year, date.month, date.day);
  var year = ((jd - 1723856) / 365.25).floor() + 1;
  var newYear = _ethiopianToJd(year, 1, 1);

  while (jd < newYear) {
    year--;
    newYear = _ethiopianToJd(year, 1, 1);
  }

  final dayOfYear = jd - newYear;
  return EthiopianDate(
    year,
    (dayOfYear ~/ 30) + 1,
    (dayOfYear % 30) + 1,
  );
}

DateTime ethiopianToGregorian(int year, int month, int day) {
  final jd = _ethiopianToJd(year, month, day);
  return _jdToGregorian(jd);
}

int _gregorianToJd(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      ((153 * m + 2) ~/ 5) +
      365 * y +
      (y ~/ 4) -
      (y ~/ 100) +
      (y ~/ 400) -
      32045;
}

int _ethiopianToJd(int year, int month, int day) {
  return 1723856 + 365 * (year - 1) + (year ~/ 4) + 30 * month + day - 31;
}

DateTime _jdToGregorian(int jd) {
  var l = jd + 68569;
  final n = (4 * l) ~/ 146097;
  l = l - (146097 * n + 3) ~/ 4;
  final i = (4000 * (l + 1)) ~/ 1461001;
  l = l - (1461 * i) ~/ 4 + 31;
  final j = (80 * l) ~/ 2447;
  final day = l - (2447 * j) ~/ 80;
  l = j ~/ 11;
  final month = j + 2 - 12 * l;
  final year = 100 * (n - 49) + i + l;
  return DateTime(year, month, day);
}

// ============================================================
// APP
// ============================================================

class SalonManagerApp extends StatefulWidget {
  const SalonManagerApp({super.key});

  @override
  State<SalonManagerApp> createState() => _SalonManagerAppState();
}

class _SalonManagerAppState extends State<SalonManagerApp> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => darkMode = p.getBool('darkMode') ?? false);
  }

  Future<void> _setTheme(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('darkMode', value);
    if (mounted) setState(() => darkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salon Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xfff7f9f9),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(
        darkMode: darkMode,
        onDarkModeChanged: _setTheme,
      ),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class TransactionItem {
  final String id;
  final String title;
  final String staffName;
  final double amount;
  final bool isIncome;
  final String category;
  final String expenseClass;
  final DateTime dateTime;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.staffName,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.expenseClass,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'staffName': staffName,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'expenseClass': expenseClass,
        'dateTime': dateTime.toIso8601String(),
      };

  factory TransactionItem.fromMap(Map<String, dynamic> m) {
    final income = m['isIncome'] == true;
    var cls = m['expenseClass']?.toString() ?? '';

    if (!income && cls.isEmpty) {
      const fixed = ['ኪራይ', 'ደመወዝ', 'መብራት', 'ውሃ', 'ስልክ', 'ጥበቃ'];
      cls = fixed.contains(m['category']) ? 'ቋሚ ወጪ' : 'መደበኛ ወጪ';
    }

    return TransactionItem(
      id: m['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: m['title']?.toString() ?? '',
      staffName: m['staffName']?.toString() ?? '',
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      isIncome: income,
      category: m['category']?.toString() ?? '',
      expenseClass: cls,
      dateTime: DateTime.tryParse(m['dateTime']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const MainScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final transactions = <TransactionItem>[];
  final photos = <String>[];
  final deletedPhotos = <String>[];
  final picker = ImagePicker();

  bool showMoney = true;
  String searchText = '';
  String filterType = 'all';

  String salonName = 'የእኔ ሳሎን';
  String phoneNumber = '';
  String salonPhoto = '';
  String calendarMode = 'ethiopian';

  String selectedMonth = 'all';
  int selectedAnnualYear = 0;

  final fixedExpenseCategories = const [
    'ኪራይ',
    'ደመወዝ',
    'መብራት',
    'ውሃ',
    'ስልክ',
    'ጥበቃ',
    'ትራንስፖርት',
    'ኢንተርኔት',
    'ሌላ',
  ];

  final regularExpenseCategories = const [
    'እቃ ግዢ',
    'መጓጓዣ',
    'ጥገና',
    'ምግብ',
    'ሌላ',
  ];

  final incomeCategories = const [
    'ፀጉር ስራ',
    'ካንቲስ',
    'ማስተካከያ',
    'ማቅለም',
    'ማስዋብ',
    'ምርት ሽያጭ',
    'ሌላ',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ==========================================================
  // STORAGE
  // ==========================================================

  Future<void> _loadAllData() async {
    final p = await SharedPreferences.getInstance();

    try {
      final raw = p.getString('transactions');
      if (raw != null) {
        final List data = jsonDecode(raw);
        transactions
          ..clear()
          ..addAll(data.map((e) =>
              TransactionItem.fromMap(Map<String, dynamic>.from(e))));
      }
    } catch (_) {}

    try {
      final raw = p.getString('photos');
      if (raw != null) {
        photos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(raw)));
      }
    } catch (_) {}

    try {
      final raw = p.getString('deletedPhotos');
      if (raw != null) {
        deletedPhotos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(raw)));
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      salonName = p.getString('salonName') ?? 'የእኔ ሳሎን';
      phoneNumber = p.getString('phoneNumber') ?? '';
      salonPhoto = p.getString('salonPhoto') ?? '';
      calendarMode = p.getString('calendarMode') ?? 'ethiopian';
    });
  }

  Future<void> _saveTransactions() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'transactions',
      jsonEncode(transactions.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> _savePhotos() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('photos', jsonEncode(photos));
    await p.setString('deletedPhotos', jsonEncode(deletedPhotos));
  }

  Future<void> _saveProfile() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('salonName', salonName);
    await p.setString('phoneNumber', phoneNumber);
    await p.setString('salonPhoto', salonPhoto);
    await p.setString('calendarMode', calendarMode);
  }

  // ==========================================================
  // DATE HELPERS
  // ==========================================================

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  EthiopianDate eth(DateTime d) => gregorianToEthiopian(d);

  String formatDate(DateTime d) {
    if (calendarMode == 'ethiopian') {
      final e = eth(d);
      return '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String monthKey(DateTime d) {
    if (calendarMode == 'ethiopian') {
      final e = eth(d);
      return '${e.year}-${e.month}';
    }
    return '${d.year}-${d.month}';
  }

  String monthLabel(String key) {
    if (key == 'all') return 'ሁሉም ወራት';
    final p = key.split('-');
    if (p.length != 2) return key;
    final y = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;

    if (calendarMode == 'ethiopian' && m >= 1 && m <= 13) {
      return '${EthiopianDate.monthNames[m]} $y';
    }

    const g = [
      '',
      'ጃንዩወሪ',
      'ፌብሩወሪ',
      'ማርች',
      'ኤፕሪል',
      'ሜይ',
      'ጁን',
      'ጁላይ',
      'ኦገስት',
      'ሴፕቴምበር',
      'ኦገስት',
      'ኖቬምበር',
      'ዲሴምበር',
    ];
    return m >= 1 && m <= 12 ? '${g[m]} $y' : key;
  }

  List<String> get availableMonths {
    final s = <String>{};
    for (final t in transactions) {
      s.add(monthKey(t.dateTime));
    }
    final list = s.toList()..sort((a, b) => b.compareTo(a));
    return ['all', ...list];
  }

  List<int> get availableYears {
    final s = <int>{};
    for (final t in transactions) {
      final e = eth(t.dateTime);
      s.add(calendarMode == 'ethiopian' ? e.year : t.dateTime.year);
    }
    final now = DateTime.now();
    final current = calendarMode == 'ethiopian' ? eth(now).year : now.year;
    s.add(current);
    final list = s.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  // ==========================================================
  // TOTALS
  // ==========================================================

  double sumIncome(Iterable<TransactionItem> list) =>
      list.where((e) => e.isIncome).fold(0, (s, e) => s + e.amount);

  double sumExpense(Iterable<TransactionItem> list) =>
      list.where((e) => !e.isIncome).fold(0, (s, e) => s + e.amount);

  double sumFixed(Iterable<TransactionItem> list) => list
      .where((e) => !e.isIncome && e.expenseClass == 'ቋሚ ወጪ')
      .fold(0, (s, e) => s + e.amount);

  double sumRegular(Iterable<TransactionItem> list) => list
      .where((e) => !e.isIncome && e.expenseClass == 'መደበኛ ወጪ')
      .fold(0, (s, e) => s + e.amount);

  String money(double v) => showMoney ? '${v.toStringAsFixed(2)} ብር' : '••••';

  // ==========================================================
  // TRANSACTION ENTRY
  // ==========================================================

  void openTransactionSheet({
    bool income = true,
    String? expenseClass,
  }) {
    final title = TextEditingController();
    final staff = TextEditingController();
    final amount = TextEditingController();

    var isIncome = income;
    var selectedClass = expenseClass ?? 'ቋሚ ወጪ';
    var category = isIncome
        ? incomeCategories.first
        : (selectedClass == 'ቋሚ ወጪ'
            ? fixedExpenseCategories.first
            : regularExpenseCategories.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final categories = isIncome
              ? incomeCategories
              : (selectedClass == 'ቋሚ ወጪ'
                  ? fixedExpenseCategories
                  : regularExpenseCategories);

          if (!categories.contains(category)) category = categories.first;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isIncome ? '💰 ገቢ መመዝገቢያ' : '💸 ወጪ መመዝገቢያ',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('ገቢ'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('ወጪ'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                    ],
                    selected: {isIncome},
                    onSelectionChanged: (v) {
                      setModalState(() {
                        isIncome = v.first;
                        category = isIncome
                            ? incomeCategories.first
                            : (selectedClass == 'ቋሚ ወጪ'
                                ? fixedExpenseCategories.first
                                : regularExpenseCategories.first);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!isIncome)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'ቋሚ ወጪ',
                          label: Text('ቋሚ ወጪ'),
                        ),
                        ButtonSegment(
                          value: 'መደበኛ ወጪ',
                          label: Text('መደበኛ ወጪ'),
                        ),
                      ],
                      selected: {selectedClass},
                      onSelectionChanged: (v) {
                        setModalState(() {
                          selectedClass = v.first;
                          category = selectedClass == 'ቋሚ ወጪ'
                              ? fixedExpenseCategories.first
                              : regularExpenseCategories.first;
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: isIncome
                          ? 'የአገልግሎቱ አይነት'
                          : 'የወጪው ምክንያት',
                      prefixIcon: const Icon(Icons.edit_note),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: staff,
                    decoration: const InputDecoration(
                      labelText: 'የሰው/ሰራተኛ ስም',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'የገንዘብ መጠን',
                      prefixIcon: Icon(Icons.payments),
                      suffixText: 'ብር',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'ምድብ',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      final titleText = title.text.trim();
                      final staffText = staff.text.trim();
                      final value = double.tryParse(amount.text.trim());

                      if (titleText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('እባክዎ አይነቱን ያስገቡ'),
                          ),
                        );
                        return;
                      }
                      if (value == null || value <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ትክክለኛ የገንዘብ መጠን ያስገቡ'),
                          ),
                        );
                        return;
                      }

                      final item = TransactionItem(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: titleText,
                        staffName: staffText,
                        amount: value,
                        isIncome: isIncome,
                        category: category,
                        expenseClass: isIncome ? '' : selectedClass,
                        dateTime: DateTime.now(),
                      );

                      setState(() => transactions.add(item));
                      await _saveTransactions();

                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isIncome
                              ? 'ገቢው ተመዝግቧል ✅'
                              : 'ወጪው ተመዝግቧል ✅'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('መዝግብ'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // HOME
  // ==========================================================

  void showTodayDetails(bool income) {
    final today = DateTime.now();
    final records = transactions
        .where((t) => t.isIncome == income && sameDay(t.dateTime, today))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final total = records.fold<double>(0, (s, e) => s + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    income ? 'የዛሬ ገቢዎች' : 'የዛሬ ወጪዎች',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: Text(income
                          ? 'የዛሬ ጠቅላላ ገቢ'
                          : 'የዛሬ ጠቅላላ ወጪ'),
                      trailing: Text(
                        money(total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(child: Text('ዛሬ ምንም መዝገብ የለም'))
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        final t = records[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName} • '
                            '${t.category} • ${formatTime(t.dateTime)}',
                          ),
                          trailing: Text(
                            money(t.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHome() {
    final today = DateTime.now();
    final todayRecords =
        transactions.where((t) => sameDay(t.dateTime, today));
    final income = sumIncome(todayRecords);
    final expense = sumExpense(todayRecords);
    final profit = income - expense;

    final recent = [...transactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          salonName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => showMoney = !showMoney),
            icon: Icon(showMoney ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            right: -25,
            top: 20,
            child: Icon(
              Icons.content_cut,
              size: 150,
              color: Theme.of(context).colorScheme.primary.withOpacity(.035),
            ),
          ),
          Positioned(
            left: -35,
            bottom: 120,
            child: Icon(
              Icons.spa,
              size: 180,
              color: Theme.of(context).colorScheme.primary.withOpacity(.035),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'የዛሬ አጠቃላይ ሁኔታ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: todayCard(
                        'የዛሬ ገቢ',
                        income,
                        Icons.arrow_downward,
                        Colors.blue,
                        () => showTodayDetails(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: todayCard(
                        'የዛሬ ወጪ',
                        expense,
                        Icons.arrow_upward,
                        Colors.red,
                        () => showTodayDetails(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.account_balance_wallet),
                    ),
                    title: const Text('የዛሬ ትርፍ'),
                    subtitle: const Text('ገቢ - ወጪ'),
                    trailing: Text(
                      money(profit),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => openTransactionSheet(income: true),
                  icon: const Icon(Icons.add),
                  label: const Text('ገቢ መመዝገቢያ'),
                ),
                const SizedBox(height: 22),
                Text(
                  'የገቢና ወጪ ግራፍ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                buildChart(
                  income,
                  expense,
                  title: 'የዛሬ ግራፍ',
                ),
                const SizedBox(height: 22),
                Text(
                  'የቅርብ ጊዜ መዝገቦች',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(
                        child: Text('እስካሁን ምንም መዝገብ የለም'),
                      ),
                    ),
                  )
                else
                  ...recent.take(5).map(transactionTile),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openTransactionSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget todayCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                money(amount),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ዝርዝሩን ለማየት ይንኩ',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildChart(
    double income,
    double expense, {
    String title = '',
  }) {
    final max = income > expense ? income : expense;
    if (max == 0) {
      return const Card(
        child: SizedBox(
          height: 170,
          child: Center(child: Text('ግራፉን ለማሳየት መዝገብ ያስገቡ')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (title.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 12),
            chartBar('ገቢ', income, max, Colors.blue, Icons.arrow_downward),
            const SizedBox(height: 18),
            chartBar('ወጪ', expense, max, Colors.red, Icons.arrow_upward),
          ],
        ),
      ),
    );
  }

  Widget chartBar(
    String label,
    double amount,
    double max,
    Color color,
    IconData icon,
  ) {
    final ratio = max == 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              money(amount),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // HISTORY
  // ==========================================================

  List<TransactionItem> get visibleTransactions {
    final q = searchText.trim().toLowerCase();
    final list = transactions.where((t) {
      final searchMatch = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.staffName.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q);
      final typeMatch = filterType == 'all' ||
          (filterType == 'income' && t.isIncome) ||
          (filterType == 'expense' && !t.isIncome);
      return searchMatch && typeMatch;
    }).toList();

    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  Widget buildHistory() {
    final list = visibleTransactions;
    return Scaffold(
      appBar: AppBar(title: const Text('የሂሳብ መዝገብ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => searchText = v),
              decoration: InputDecoration(
                hintText: 'ፈልግ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(() => searchText = ''),
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: filterType,
                    decoration: const InputDecoration(
                      labelText: 'አይነት',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('ሁሉም')),
                      DropdownMenuItem(value: 'income', child: Text('ገቢ')),
                      DropdownMenuItem(value: 'expense', child: Text('ወጪ')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => filterType = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableMonths.contains(selectedMonth)
                        ? selectedMonth
                        : 'all',
                    decoration: const InputDecoration(
                      labelText: 'ወር',
                      border: OutlineInputBorder(),
                    ),
                    items: availableMonths
                        .map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(
                                monthLabel(k),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedMonth = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('ምንም መዝገብ አልተገኘም'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => transactionTile(list[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openTransactionSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget transactionTile(TransactionItem t) {
    final color = t.isIncome ? Colors.blue : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(
            t.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          t.title.isEmpty ? t.category : t.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName}\n'
          '${t.category} • ${formatDate(t.dateTime)} • ${formatTime(t.dateTime)}'
          '${t.isIncome ? '' : '\n${t.expenseClass}'}',
        ),
        isThreeLine: true,
        trailing: Text(
          money(t.amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // REPORTS
  // ==========================================================

  Iterable<TransactionItem> transactionsForMonth(int year, int month) {
    return transactions.where((t) {
      if (calendarMode == 'ethiopian') {
        final e = eth(t.dateTime);
        return e.year == year && e.month == month;
      }
      return t.dateTime.year == year && t.dateTime.month == month;
    });
  }

  int daysInEthiopianMonth(int year, int month) {
    if (month <= 12) return 30;
    final nextYear = year + 1;
    final jdNow = _ethiopianToJd(year, 13, 6);
    final jdNext = _ethiopianToJd(nextYear, 1, 1);
    return jdNow < jdNext ? 6 : 5;
  }

  String annualLabel(int year) =>
      calendarMode == 'ethiopian' ? 'ዓመተ ምህረት $year' : 'ዓመት $year';

  List<TransactionItem> annualTransactions(int year) {
    return transactions.where((t) {
      if (calendarMode == 'ethiopian') {
        return eth(t.dateTime).year == year;
      }
      return t.dateTime.year == year;
    }).toList();
  }

  Widget reportMoneyCard(
    String title,
    double value, {
    Color? color,
    IconData? icon,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color?.withOpacity(.12),
          child: Icon(icon ?? Icons.payments, color: color),
        ),
        title: Text(title),
        trailing: Text(
          money(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget buildReports() {
    final now = DateTime.now();
    final todayRecords = transactions.where((t) => sameDay(t.dateTime, now));
    final todayIncome = sumIncome(todayRecords);
    final todayExpense = sumExpense(todayRecords);

    final years = availableYears;
    if (selectedAnnualYear == 0 || !years.contains(selectedAnnualYear)) {
      selectedAnnualYear = years.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ሪፖርት')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'የቀን ሪፖርት',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          reportMoneyCard(
            'የዛሬ ገቢ',
            todayIncome,
            color: Colors.blue,
            icon: Icons.arrow_downward,
          ),
          reportMoneyCard(
            'የዛሬ ወጪ',
            todayExpense,
            color: Colors.red,
            icon: Icons.arrow_upward,
          ),
          reportMoneyCard(
            'የዛሬ ንጹህ ትርፍ',
            todayIncome - todayExpense,
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 28),

          // MONTH REPORT
          Text(
            'የወር ሪፖርት',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: availableMonths.contains(selectedMonth)
                ? selectedMonth
                : 'all',
            decoration: const InputDecoration(
              labelText: 'ወር ምረጥ',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
            ),
            items: availableMonths
                .map((k) => DropdownMenuItem(
                      value: k,
                      child: Text(monthLabel(k)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedMonth = v);
            },
          ),
          const SizedBox(height: 12),
          if (selectedMonth != 'all')
            buildSelectedMonthReport(selectedMonth)
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'የተወሰነ ወር ለማየት ከላይ ወር ይምረጡ።',
                ),
              ),
            ),

          const SizedBox(height: 28),

          // ANNUAL REPORT
          Text(
            'የዓመት ሪፖርት',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: selectedAnnualYear,
            decoration: const InputDecoration(
              labelText: 'ዓመት ምረጥ',
              prefixIcon: Icon(Icons.event_note),
              border: OutlineInputBorder(),
            ),
            items: years
                .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text(annualLabel(y)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedAnnualYear = v);
            },
          ),
          const SizedBox(height: 12),
          buildAnnualReport(selectedAnnualYear),
        ],
      ),
    );
  }

  Widget buildSelectedMonthReport(String key) {
    final p = key.split('-');
    final year = int.tryParse(p[0]) ?? 0;
    final month = int.tryParse(p[1]) ?? 0;
    final list = transactionsForMonth(year, month).toList();

    final income = sumIncome(list);
    final expense = sumExpense(list);
    final fixed = sumFixed(list);
    final regular = sumRegular(list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'የተመረጠው፦ ${monthLabel(key)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        reportMoneyCard(
          'የወሩ ገቢ',
          income,
          color: Colors.blue,
          icon: Icons.trending_up,
        ),
        reportMoneyCard(
          'የወሩ ወጪ',
          expense,
          color: Colors.red,
          icon: Icons.trending_down,
        ),
        reportMoneyCard(
          'ቋሚ ወጪ',
          fixed,
          color: Colors.red,
          icon: Icons.home_work,
        ),
        reportMoneyCard(
          'መደበኛ ወጪ',
          regular,
          color: Colors.red,
          icon: Icons.shopping_bag,
        ),
        reportMoneyCard(
          'የወሩ ንጹህ ትርፍ',
          income - expense,
          icon: Icons.account_balance,
        ),
        const SizedBox(height: 12),
        buildChart(income, expense, title: 'የወሩ ገቢና ወጪ'),
        const SizedBox(height: 16),
        Text(
          'የዕለት ዝርዝር',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        buildDailyMonthReport(year, month),
      ],
    );
  }

  Widget buildDailyMonthReport(int year, int month) {
    final days = calendarMode == 'ethiopian'
        ? daysInEthiopianMonth(year, month)
        : DateTime(year, month + 1, 0).day;

    return Column(
      children: List.generate(days, (i) {
        final day = i + 1;
        final list = calendarMode == 'ethiopian'
            ? transactionsForMonth(year, month)
                .where((t) => eth(t.dateTime).day == day)
                .toList()
            : transactions.where((t) =>
                t.dateTime.year == year &&
                t.dateTime.month == month &&
                t.dateTime.day == day).toList();

        final income = sumIncome(list);
        final expense = sumExpense(list);
        final hasRecord = list.isNotEmpty;

        final label = calendarMode == 'ethiopian'
            ? '$day ${EthiopianDate.monthNames[month]} $year'
            : '$day/${month.toString().padLeft(2, '0')}/$year';

        return Card(
          margin: const EdgeInsets.only(bottom: 7),
          child: ExpansionTile(
            leading: CircleAvatar(child: Text('$day')),
            title: Text(label),
            subtitle: Text(
              hasRecord
                  ? 'ገቢ: ${money(income)}  •  ወጪ: ${money(expense)}'
                  : 'ያልተመዘገበበት ቀን / ሥራ ያልተሰራበት ቀን',
            ),
            trailing: hasRecord
                ? Text(
                    money(income - expense),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : const Icon(Icons.remove_circle_outline),
            children: hasRecord
                ? list
                    .map(
                      (t) => ListTile(
                        dense: true,
                        leading: Icon(
                          t.isIncome
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: t.isIncome ? Colors.blue : Colors.red,
                        ),
                        title: Text(t.title),
                        subtitle: Text(
                          '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName} • '
                          '${t.category} • ${formatTime(t.dateTime)}',
                        ),
                        trailing: Text(
                          money(t.amount),
                          style: TextStyle(
                            color: t.isIncome ? Colors.blue : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList()
                : const [],
          ),
        );
      }),
    );
  }

  Widget buildAnnualReport(int year) {
    final list = annualTransactions(year);
    final income = sumIncome(list);
    final expense = sumExpense(list);
    final fixed = sumFixed(list);
    final regular = sumRegular(list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              annualLabel(year),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        reportMoneyCard(
          'የዓመቱ ጠቅላላ ገቢ',
          income,
          color: Colors.blue,
          icon: Icons.trending_up,
        ),
        reportMoneyCard(
          'የዓመቱ ጠቅላላ ወጪ',
          expense,
          color: Colors.red,
          icon: Icons.trending_down,
        ),
        reportMoneyCard(
          'የዓመቱ ቋሚ ወጪ',
          fixed,
          color: Colors.red,
          icon: Icons.home_work,
        ),
        reportMoneyCard(
          'የዓመቱ መደበኛ ወጪ',
          regular,
          color: Colors.red,
          icon: Icons.shopping_bag,
        ),
        reportMoneyCard(
          'የዓመቱ ንጹህ ትርፍ',
          income - expense,
          icon: Icons.account_balance,
        ),
        const SizedBox(height: 12),
        buildChart(income, expense, title: 'የዓመቱ ገቢና ወጪ'),
        const SizedBox(height: 18),
        Text(
          'የወራት ዝርዝር',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          calendarMode == 'ethiopian' ? 13 : 12,
          (i) => buildAnnualMonthRow(year, i + 1),
        ),
      ],
    );
  }

  Widget buildAnnualMonthRow(int year, int month) {
    final list = transactionsForMonth(year, month).toList();
    final income = sumIncome(list);
    final expense = sumExpense(list);
    final has = list.isNotEmpty;

    final label = calendarMode == 'ethiopian'
        ? EthiopianDate.monthNames[month]
        : monthLabel('$year-$month');

    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        leading: CircleAvatar(child: Text('$month')),
        title: Text(label),
        subtitle: Text(
          has
              ? 'ገቢ ${money(income)}  •  ወጪ ${money(expense)}'
              : 'ያልተመዘገበ ወር',
        ),
        trailing: Text(
          has ? money(income - expense) : '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: has
            ? () {
                final key = '$year-$month';
                setState(() {
                  selectedMonth = key;
                  currentIndex = 2;
                });
              }
            : null,
      ),
    );
  }

  // ==========================================================
  // PHOTOS
  // ==========================================================

  Future<void> addPhoto(ImageSource source) async {
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final name = 'salon_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = File('${dir.path}/$name');
      await File(picked.path).copy(dest.path);

      setState(() => photos.add(dest.path));
      await _savePhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ፎቶው ተቀምጧል ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ፎቶ ማስገባት አልተቻለም: $e')),
        );
      }
    }
  }

  Future<void> deletePhoto(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ፎቶ ሰርዝ'),
        content: const Text(
          'ፎቶው ወደ Recycle Bin ይሄዳል።\nበኋላ Restore ማድረግ ይችላሉ።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('አይ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ወደ Recycle Bin ላክ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() {
      photos.remove(path);
      deletedPhotos.add(path);
    });
    await _savePhotos();
  }

  Future<void> restorePhoto(String path) async {
    setState(() {
      deletedPhotos.remove(path);
      if (!photos.contains(path)) photos.add(path);
    });
    await _savePhotos();
  }

  Future<void> permanentlyDeletePhoto(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('በቋሚነት ሰርዝ'),
        content: const Text('ይህ ፎቶ በቋሚነት ይሰረዛል።'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ተወው'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ሰርዝ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    setState(() => deletedPhotos.remove(path));
    await _savePhotos();
  }

  void openPhotoViewer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('ፎቶ')),
          body: Center(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('ፎቶው አልተገኘም')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPhotos() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ፎቶዎች'),
        actions: [
          IconButton(
            tooltip: 'Recycle Bin',
            onPressed: openRecycleBin,
            icon: Badge(
              isLabelVisible: deletedPhotos.isNotEmpty,
              label: Text('${deletedPhotos.length}'),
              child: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
      body: photos.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 70),
                  SizedBox(height: 12),
                  Text('እስካሁን ፎቶ የለም'),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final path = photos[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => openPhotoViewer(path),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton.filledTonal(
                          onPressed: () => deletePhoto(path),
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                      const Positioned(
                        bottom: 6,
                        left: 6,
                        child: Icon(Icons.zoom_in, color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'camera',
            onPressed: () => addPhoto(ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () => addPhoto(ImageSource.gallery),
            child: const Icon(Icons.photo),
          ),
        ],
      ),
    );
  }

  void openRecycleBin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '🗑️ Recycle Bin',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: deletedPhotos.isEmpty
                  ? const Center(child: Text('Recycle Bin ባዶ ነው'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: deletedPhotos.length,
                      itemBuilder: (_, i) {
                        final path = deletedPhotos[i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                ),
                              ),
                              Positioned(
                                bottom: 5,
                                left: 5,
                                right: 5,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => restorePhoto(path),
                                        icon: const Icon(Icons.restore),
                                        label: const Text('Restore'),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    IconButton.filledTonal(
                                      onPressed: () =>
                                          permanentlyDeletePhoto(path),
                                      icon: const Icon(Icons.delete_forever),
                                    ),
                                  ],
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
      ),
    );
  }

  // ==========================================================
  // PROFILE / SETTINGS
  // ==========================================================

  Future<void> pickSalonPhoto() async {
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final name =
        'salon_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${dir.path}/$name');
    await File(picked.path).copy(dest.path);

    setState(() => salonPhoto = dest.path);
    await _saveProfile();
  }

  void editProfile() {
    final name = TextEditingController(text: salonName);
    final phone = TextEditingController(text: phoneNumber);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('የሳሎን መረጃ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'የሳሎን ስም'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ስልክ ቁጥር'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('ይቅር'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                salonName = name.text.trim().isEmpty
                    ? 'የእኔ ሳሎን'
                    : name.text.trim();
                phoneNumber = phone.text.trim();
              });
              await _saveProfile();
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('አስቀምጥ'),
          ),
        ],
      ),
    );
  }

  Widget buildProfile() {
    return Scaffold(
      appBar: AppBar(title: const Text('እኔ / Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickSalonPhoto,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundImage:
                          salonPhoto.isNotEmpty ? FileImage(File(salonPhoto)) : null,
                      child: salonPhoto.isEmpty
                          ? const Icon(Icons.storefront, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    salonName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (phoneNumber.isNotEmpty) Text(phoneNumber),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: editProfile,
                    icon: const Icon(Icons.edit),
                    label: const Text('የሳሎን መረጃ ቀይር'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('የቀን አቆጣጠር'),
                  subtitle: Text('ቀንና ወር እንዴት እንዲታይ ይምረጡ'),
                ),
                RadioListTile<String>(
                  value: 'ethiopian',
                  groupValue: calendarMode,
                  title: const Text('🇪🇹 የኢትዮጵያ አቆጣጠር'),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() {
                      calendarMode = v;
                      selectedMonth = 'all';
                      selectedAnnualYear = 0;
                    });
                    await _saveProfile();
                  },
                ),
                RadioListTile<String>(
                  value: 'gregorian',
                  groupValue: calendarMode,
                  title: const Text('🌍 Gregorian'),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() {
                      calendarMode = v;
                      selectedMonth = 'all';
                      selectedAnnualYear = 0;
                    });
                    await _saveProfile();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              value: widget.darkMode,
              onChanged: widget.onDarkModeChanged,
            ),
          ),
          const SizedBox(height: 15),
          const Card(
            child: ListTile(
              leading: Icon(Icons.save),
              title: Text('የመረጃ ማስቀመጫ'),
              subtitle: Text(
                'ገቢ፣ ወጪና ፎቶዎች በስልኩ ውስጥ ይቀመጣሉ።',
              ),
            ),
          ),
          const SizedBox(height: 25),
          Center(
            child: Text(
              'Salon Manager',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(child: Text('የሳሎን ገቢና ወጪ መዝገብ')),
        ],
      ),
    );
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  Widget currentPage() {
    switch (currentIndex) {
      case 0:
        return buildHome();
      case 1:
        return buildHistory();
      case 2:
        return buildReports();
      case 3:
        return buildPhotos();
      case 4:
        return buildProfile();
      default:
        return buildHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'መነሻ',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'መዝገብ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'ሪፖርት',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'ፎቶ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'እኔ',
          ),
        ],
      ),
    );
  }
}
'''

path = Path("/mnt/data/main_updated.dart")
path.write_text(code, encoding="utf-8")
print(f"Created: {path}")
print(f"Lines: {len(code.splitlines())}")
