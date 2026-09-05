import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SalonManagerApp());
}

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
  @override
  String toString() => '$day $monthName $year';
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
    (dayOfYear / 30).floor() + 1,
    (dayOfYear % 30) + 1,
  );
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

bool isEthiopianLeapYear(int year) => (year + 1) % 4 == 0;

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

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    final income = map['isIncome'] == true;
    var expenseClass = map['expenseClass']?.toString() ?? '';

    if (!income && expenseClass.isEmpty) {
      const fixed = ['ኪራይ', 'ውሃ', 'መብራት', 'ስልክ', 'ደመወዝ', 'ጥበቃ'];
      expenseClass =
          fixed.contains(map['category']) ? 'ቋሚ ወጪ' : 'መደበኛ ወጪ';
    }

    return TransactionItem(
      id: map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      staffName: map['staffName']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isIncome: income,
      category: map['category']?.toString() ?? '',
      expenseClass: expenseClass,
      dateTime:
          DateTime.tryParse(map['dateTime']?.toString() ?? '') ?? DateTime.now(),
    );
  }
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => darkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
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
        onDarkModeChanged: _setDarkMode,
      ),
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

  final List<TransactionItem> transactions = [];
  final List<String> photos = [];
  final List<String> deletedPhotos = [];
  final ImagePicker picker = ImagePicker();

  bool showMoney = true;
  String searchText = '';
  String filterType = 'all';

  String salonName = 'የእኔ ሳሎን';
  String phoneNumber = '';
  String salonPhoto = '';
  String calendarMode = 'ethiopian';

  int selectedReportYear = 0;
  int selectedReportMonth = 0;

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
    final prefs = await SharedPreferences.getInstance();

    try {
      final raw = prefs.getString('transactions');
      if (raw != null) {
        final data = jsonDecode(raw) as List;
        transactions
          ..clear()
          ..addAll(data.map((e) =>
              TransactionItem.fromMap(Map<String, dynamic>.from(e))));
      }
    } catch (_) {}

    try {
      final raw = prefs.getString('photos');
      if (raw != null) {
        photos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(raw)));
      }
    } catch (_) {}

    try {
      final raw = prefs.getString('deletedPhotos');
      if (raw != null) {
        deletedPhotos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(raw)));
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      salonName = prefs.getString('salonName') ?? 'የእኔ ሳሎን';
      phoneNumber = prefs.getString('phoneNumber') ?? '';
      salonPhoto = prefs.getString('salonPhoto') ?? '';
      calendarMode = prefs.getString('calendarMode') ?? 'ethiopian';
      _ensureReportSelection();
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'transactions',
      jsonEncode(transactions.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photos', jsonEncode(photos));
    await prefs.setString('deletedPhotos', jsonEncode(deletedPhotos));
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('salonName', salonName);
    await prefs.setString('phoneNumber', phoneNumber);
    await prefs.setString('salonPhoto', salonPhoto);
    await prefs.setString('calendarMode', calendarMode);
  }

  // ==========================================================
  // CALENDAR / DATE HELPERS
  // ==========================================================

  EthiopianDate _eth(DateTime date) => gregorianToEthiopian(date);

  String _formatDate(DateTime date) {
    if (calendarMode == 'ethiopian') {
      final e = _eth(date);
      return '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayKey(DateTime date) {
    if (calendarMode == 'ethiopian') {
      final e = _eth(date);
      return '${e.year}-${e.month}-${e.day}';
    }
    return '${date.year}-${date.month}-${date.day}';
  }

  String _dayLabel(DateTime date) {
    if (calendarMode == 'ethiopian') {
      final e = _eth(date);
      return 'ቀን ${e.day} ${e.monthName} ${e.year}';
    }
    return 'ቀን ${date.day}/${date.month}/${date.year}';
  }

  String _monthKey(DateTime date) {
    if (calendarMode == 'ethiopian') {
      final e = _eth(date);
      return '${e.year}-${e.month}';
    }
    return '${date.year}-${date.month}';
  }

  String _monthLabel(int year, int month) {
    if (calendarMode == 'ethiopian') {
      return '${EthiopianDate.monthNames[month]} $year';
    }
    const names = [
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
      'ኦክቶበር',
      'ኖቬምበር',
      'ዲሴምበር',
    ];
    return '${names[month]} $year';
  }

  void _ensureReportSelection() {
    if (calendarMode == 'ethiopian') {
      final now = _eth(DateTime.now());
      if (selectedReportYear == 0) selectedReportYear = now.year;
      if (selectedReportMonth == 0) selectedReportMonth = now.month;
    } else {
      final now = DateTime.now();
      if (selectedReportYear == 0) selectedReportYear = now.year;
      if (selectedReportMonth == 0) selectedReportMonth = now.month;
    }
  }

  int get _currentCalendarYear {
    if (calendarMode == 'ethiopian') return _eth(DateTime.now()).year;
    return DateTime.now().year;
  }

  List<int> get _reportYears {
    final years = <int>{_currentCalendarYear};
    for (final t in transactions) {
      if (calendarMode == 'ethiopian') {
        years.add(_eth(t.dateTime).year);
      } else {
        years.add(t.dateTime.year);
      }
    }
    final result = years.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  int get _monthCount => calendarMode == 'ethiopian' ? 13 : 12;

  int _daysInReportMonth(int year, int month) {
    if (calendarMode == 'ethiopian') {
      if (month == 13) return isEthiopianLeapYear(year) ? 6 : 5;
      return 30;
    }
    return DateTime(year, month + 1, 0).day;
  }

  DateTime? _dateForReportDay(int year, int month, int day) {
    if (calendarMode == 'gregorian') {
      return DateTime(year, month, day, 12);
    }

    // Find a Gregorian date belonging to the requested Ethiopian date.
    // Searching around the expected Gregorian year keeps this local and safe.
    final approx = DateTime(year + 7, month == 13 ? 9 : month + 8, 15, 12);
    for (var offset = -45; offset <= 45; offset++) {
      final d = approx.add(Duration(days: offset));
      final e = _eth(d);
      if (e.year == year && e.month == month && e.day == day) return d;
    }
    return null;
  }

  List<DateTime> _reportDays(int year, int month) {
    final days = _daysInReportMonth(year, month);
    final result = <DateTime>[];
    for (var day = 1; day <= days; day++) {
      final date = _dateForReportDay(year, month, day);
      if (date != null) result.add(date);
    }
    return result;
  }

  // ==========================================================
  // TOTALS
  // ==========================================================

  double _sumIncome(Iterable<TransactionItem> list) =>
      list.where((e) => e.isIncome).fold(0, (s, e) => s + e.amount);

  double _sumExpense(Iterable<TransactionItem> list) =>
      list.where((e) => !e.isIncome).fold(0, (s, e) => s + e.amount);

  double _sumFixed(Iterable<TransactionItem> list) => list
      .where((e) => !e.isIncome && e.expenseClass == 'ቋሚ ወጪ')
      .fold(0, (s, e) => s + e.amount);

  double _sumRegular(Iterable<TransactionItem> list) => list
      .where((e) => !e.isIncome && e.expenseClass == 'መደበኛ ወጪ')
      .fold(0, (s, e) => s + e.amount);

  String _formatMoney(double amount) =>
      showMoney ? '${amount.toStringAsFixed(2)} ብር' : '••••';

  Iterable<TransactionItem> _recordsForReportDay(DateTime day) =>
      transactions.where((t) => _dayKey(t.dateTime) == _dayKey(day));

  Iterable<TransactionItem> _recordsForReportMonth(int year, int month) =>
      transactions.where((t) {
        if (calendarMode == 'ethiopian') {
          final e = _eth(t.dateTime);
          return e.year == year && e.month == month;
        }
        return t.dateTime.year == year && t.dateTime.month == month;
      });

  // ==========================================================
  // TRANSACTION ENTRY
  // ==========================================================

  void _openTransactionSheet({bool income = true}) {
    final titleController = TextEditingController();
    final staffController = TextEditingController();
    final amountController = TextEditingController();

    var isIncome = income;
    var expenseClass = 'ቋሚ ወጪ';
    var category = isIncome
        ? incomeCategories.first
        : fixedExpenseCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = isIncome
                ? incomeCategories
                : (expenseClass == 'ቋሚ ወጪ'
                    ? fixedExpenseCategories
                    : regularExpenseCategories);

            if (!categories.contains(category)) category = categories.first;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isIncome ? '💰 ገቢ መመዝገቢያ' : '💸 ወጪ መመዝገቢያ',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
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
                              : (expenseClass == 'ቋሚ ወጪ'
                                  ? fixedExpenseCategories.first
                                  : regularExpenseCategories.first);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (!isIncome)
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'ቋሚ ወጪ', label: Text('ቋሚ ወጪ')),
                          ButtonSegment(
                              value: 'መደበኛ ወጪ',
                              label: Text('መደበኛ ወጪ')),
                        ],
                        selected: {expenseClass},
                        onSelectionChanged: (v) {
                          setModalState(() {
                            expenseClass = v.first;
                            category = expenseClass == 'ቋሚ ወጪ'
                                ? fixedExpenseCategories.first
                                : regularExpenseCategories.first;
                          });
                        },
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText:
                            isIncome ? 'የአገልግሎቱ አይነት' : 'የወጪው ምክንያት',
                        prefixIcon: const Icon(Icons.edit_note),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: staffController,
                      decoration: const InputDecoration(
                        labelText: 'የሰው/ሰራተኛ ስም',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                        final title = titleController.text.trim();
                        final staff = staffController.text.trim();
                        final amount =
                            double.tryParse(amountController.text.trim());

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('እባክዎ አይነቱን ያስገቡ'),
                            ),
                          );
                          return;
                        }

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ትክክለኛ የገንዘብ መጠን ያስገቡ'),
                            ),
                          );
                          return;
                        }

                        transactions.add(
                          TransactionItem(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: title,
                            staffName: staff,
                            amount: amount,
                            isIncome: isIncome,
                            category: category,
                            expenseClass: isIncome ? '' : expenseClass,
                            dateTime: DateTime.now(),
                          ),
                        );

                        await _saveTransactions();
                        if (!mounted) return;
                        setState(() {});
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
        );
      },
    );
  }

  // ==========================================================
  // HOME
  // ==========================================================

  void _showTodayDetails(bool income) {
    final today = DateTime.now();
    final records = transactions
        .where((t) => t.isIncome == income && _sameDay(t.dateTime, today))
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
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(income
                            ? Icons.arrow_downward
                            : Icons.arrow_upward),
                      ),
                      title: Text(income
                          ? 'የዛሬ ጠቅላላ ገቢ'
                          : 'የዛሬ ጠቅላላ ወጪ'),
                      trailing: Text(
                        _formatMoney(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
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
                      itemBuilder: (_, index) {
                        final t = records[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName} • '
                            '${t.category} • ${_formatTime(t.dateTime)}',
                          ),
                          trailing: Text(
                            _formatMoney(t.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: income ? Colors.blue : Colors.red,
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

  Widget _buildHome() {
    final today = DateTime.now();
    final todayRecords = transactions.where((t) => _sameDay(t.dateTime, today));
    final income = _sumIncome(todayRecords);
    final expense = _sumExpense(todayRecords);
    final profit = income - expense;

    final recent = [...transactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(salonName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'ገንዘብ አሳይ/ደብቅ',
            onPressed: () => setState(() => showMoney = !showMoney),
            icon: Icon(showMoney ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            right: -30,
            top: 20,
            child: Icon(
              Icons.content_cut,
              size: 150,
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(.035),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 120,
            child: Icon(
              Icons.spa,
              size: 180,
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(.035),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'የዛሬ አጠቃላይ ሁኔታ',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _todayCard(
                      'የዛሬ ገቢ',
                      income,
                      Icons.arrow_downward,
                      Colors.blue,
                      () => _showTodayDetails(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _todayCard(
                      'የዛሬ ወጪ',
                      expense,
                      Icons.arrow_upward,
                      Colors.red,
                      () => _showTodayDetails(false),
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
                    _formatMoney(profit),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openTransactionSheet(income: true),
                      icon: const Icon(Icons.add),
                      label: const Text('ገቢ መመዝገቢያ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openTransactionSheet(income: false),
                      icon: const Icon(Icons.remove),
                      label: const Text('ወጪ መመዝገቢያ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'የገቢና ወጪ ግራፍ',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildSimpleChart(income, expense),
              const SizedBox(height: 24),
              Text(
                'የቅርብ ጊዜ መዝገቦች',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: Center(child: Text('እስካሁን ምንም መዝገብ የለም')),
                  ),
                )
              else
                ...recent.take(5).map(_transactionTile),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _todayCard(
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
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                _formatMoney(amount),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              const SizedBox(height: 6),
              const Text('ዝርዝሩን ለማየት ይንኩ',
                  style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleChart(double income, double expense) {
    final max = income > expense ? income : expense;
    if (max == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: Center(child: Text('ግራፉን ለማሳየት መዝገብ ያስገቡ')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _chartBar('ገቢ', income, max, Icons.arrow_downward, Colors.blue),
            const SizedBox(height: 18),
            _chartBar('ወጪ', expense, max, Icons.arrow_upward, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _chartBar(
    String label,
    double amount,
    double max,
    IconData icon,
    Color color,
  ) {
    final ratio = max == 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Text(_formatMoney(amount),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 14,
            color: color,
            backgroundColor: color.withOpacity(.12),
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

  Widget _buildHistory() {
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
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('ምንም መዝገብ አልተገኘም'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _transactionTile(list[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _transactionTile(TransactionItem t) {
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
          '${t.category} • ${_formatDate(t.dateTime)} • ${_formatTime(t.dateTime)}'
          '${t.isIncome ? '' : '\n${t.expenseClass}'}',
        ),
        isThreeLine: true,
        trailing: Text(
          _formatMoney(t.amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // ==========================================================
  // REPORTS
  // ==========================================================

  Widget _buildReports() {
    _ensureReportSelection();

    final today = DateTime.now();
    final todayRecords =
        transactions.where((t) => _sameDay(t.dateTime, today));
    final todayIncome = _sumIncome(todayRecords);
    final todayExpense = _sumExpense(todayRecords);

    final monthRecords =
        _recordsForReportMonth(selectedReportYear, selectedReportMonth).toList();
    final monthIncome = _sumIncome(monthRecords);
    final monthExpense = _sumExpense(monthRecords);
    final fixed = _sumFixed(monthRecords);
    final regular = _sumRegular(monthRecords);
    final monthProfit = monthIncome - monthExpense;

    final annual = _annualTotals(selectedReportYear);

    return Scaffold(
      appBar: AppBar(title: const Text('ሪፖርት')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('የቀን ሪፖርት'),
          const SizedBox(height: 8),
          _reportCard('የዛሬ ገቢ', todayIncome, Icons.arrow_downward,
              Colors.blue),
          _reportCard('የዛሬ ወጪ', todayExpense, Icons.arrow_upward,
              Colors.red),
          _reportCard('የዛሬ ንጹህ ትርፍ',
              todayIncome - todayExpense, Icons.account_balance_wallet, null),
          const SizedBox(height: 25),

          _sectionTitle('የወር ሪፖርት'),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _reportYears.contains(selectedReportYear)
                      ? selectedReportYear
                      : _currentCalendarYear,
                  decoration: const InputDecoration(
                    labelText: 'ዓመት',
                    border: OutlineInputBorder(),
                  ),
                  items: _reportYears
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedReportYear = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedReportMonth,
                  decoration: const InputDecoration(
                    labelText: 'ወር',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    _monthCount,
                    (i) => i + 1,
                  ).map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        calendarMode == 'ethiopian'
                            ? EthiopianDate.monthNames[m]
                            : _monthLabel(selectedReportYear, m),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedReportMonth = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.calendar_month),
              ),
              title: Text(
                  _monthLabel(selectedReportYear, selectedReportMonth)),
              subtitle: const Text('የተመረጠው ወር'),
            ),
          ),
          _reportCard('የወሩ ገቢ', monthIncome, Icons.trending_up,
              Colors.blue),
          _reportCard('የወሩ ጠቅላላ ወጪ', monthExpense,
              Icons.trending_down, Colors.red),
          _reportCard('ቋሚ ወጪ', fixed, Icons.home_work, Colors.red),
          _reportCard('መደበኛ ወጪ', regular, Icons.shopping_bag,
              Colors.red),
          _reportCard('የወሩ ንጹህ ትርፍ', monthProfit,
              Icons.account_balance, null),

          const SizedBox(height: 18),
          _sectionTitle('የወሩ ግራፍ'),
          const SizedBox(height: 8),
          _buildReportChart(monthIncome, monthExpense, fixed, regular),

          const SizedBox(height: 22),
          _sectionTitle('የወሩ ዕለታዊ ሪፖርት'),
          const SizedBox(height: 8),
          _buildDailyMonthReport(selectedReportYear, selectedReportMonth),

          const SizedBox(height: 28),
          _sectionTitle('የዓመት ሪፖርት'),
          const SizedBox(height: 8),
          _buildAnnualReport(selectedReportYear, annual),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _reportCard(
      String title, double amount, IconData icon, Color? color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color?.withOpacity(.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          _formatMoney(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildReportChart(
      double income, double expense, double fixed, double regular) {
    final max = [income, expense, fixed, regular]
        .reduce((a, b) => a > b ? a : b);

    if (max == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: Text('የወሩ መረጃ የለም')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _chartBar('ገቢ', income, max, Icons.arrow_downward, Colors.blue),
            const SizedBox(height: 14),
            _chartBar('ጠቅላላ ወጪ', expense, max, Icons.arrow_upward,
                Colors.red),
            const SizedBox(height: 14),
            _chartBar('ቋሚ ወጪ', fixed, max, Icons.home_work, Colors.red),
            const SizedBox(height: 14),
            _chartBar(
                'መደበኛ ወጪ', regular, max, Icons.shopping_bag, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMonthReport(int year, int month) {
    final days = _reportDays(year, month);

    return Column(
      children: days.map((day) {
        final records = _recordsForReportDay(day).toList();
        final income = _sumIncome(records);
        final expense = _sumExpense(records);
        final hasRecords = records.isNotEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  (hasRecords ? Colors.teal : Colors.grey).withOpacity(.12),
              child: Text(
                calendarMode == 'ethiopian'
                    ? '${_eth(day).day}'
                    : '${day.day}',
              ),
            ),
            title: Text(
              _dayLabel(day),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: hasRecords
                ? Text(
                    'ገቢ ${_formatMoney(income)} • ወጪ ${_formatMoney(expense)}',
                  )
                : const Text(
                    'ያልተመዘገበበት ቀን • ሥራ ያልተሰራበት ቀን',
                  ),
            children: hasRecords
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          ...records.map(
                            (t) => ListTile(
                              dense: true,
                              leading: Icon(
                                t.isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color:
                                    t.isIncome ? Colors.blue : Colors.red,
                              ),
                              title: Text(t.title),
                              subtitle: Text(
                                  '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName} • ${_formatTime(t.dateTime)}'),
                              trailing: Text(
                                _formatMoney(t.amount),
                                style: TextStyle(
                                  color:
                                      t.isIncome ? Colors.blue : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('የቀኑ ትርፍ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                _formatMoney(income - expense),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ]
                : const [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'በዚህ ቀን ምንም ገቢ ወይም ወጪ አልተመዘገበም።',
                        ),
                      ),
                    ),
                  ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, double> _annualTotals(int year) {
    double income = 0;
    double expense = 0;
    double fixed = 0;
    double regular = 0;

    for (final t in transactions) {
      final matches = calendarMode == 'ethiopian'
          ? _eth(t.dateTime).year == year
          : t.dateTime.year == year;

      if (!matches) continue;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
        if (t.expenseClass == 'ቋሚ ወጪ') {
          fixed += t.amount;
        } else {
          regular += t.amount;
        }
      }
    }

    return {
      'income': income,
      'expense': expense,
      'fixed': fixed,
      'regular': regular,
      'profit': income - expense,
    };
  }

  Widget _buildAnnualReport(int year, Map<String, double> totals) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.calendar_view_month),
            ),
            title: Text('ዓመት $year'),
            subtitle: const Text('የዓመቱ አጠቃላይ ውጤት'),
            trailing: Text(
              _formatMoney(totals['profit'] ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        _reportCard('የዓመቱ ገቢ', totals['income'] ?? 0,
            Icons.trending_up, Colors.blue),
        _reportCard('የዓመቱ ወጪ', totals['expense'] ?? 0,
            Icons.trending_down, Colors.red),
        _reportCard('የዓመቱ ቋሚ ወጪ', totals['fixed'] ?? 0,
            Icons.home_work, Colors.red),
        _reportCard('የዓመቱ መደበኛ ወጪ', totals['regular'] ?? 0,
            Icons.shopping_bag, Colors.red),
        _reportCard('የዓመቱ ንጹህ ትርፍ', totals['profit'] ?? 0,
            Icons.account_balance, null),
        const SizedBox(height: 8),
        ...List.generate(_monthCount, (i) {
          final month = i + 1;
          final records = _recordsForReportMonth(year, month).toList();
          final income = _sumIncome(records);
          final expense = _sumExpense(records);
          final profit = income - expense;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('$month'),
              ),
              title: Text(_monthLabel(year, month)),
              subtitle: records.isEmpty
                  ? const Text('ምንም መዝገብ የለም')
                  : Text(
                      'ገቢ ${_formatMoney(income)} • ወጪ ${_formatMoney(expense)}'),
              trailing: Text(
                _formatMoney(profit),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================
  // PHOTOS
  // ==========================================================

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final picked =
          await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final name =
          'salon_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destination = File('${dir.path}/$name');

      await File(picked.path).copy(destination.path);
      if (!mounted) return;
      setState(() => photos.add(destination.path));
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

  Future<void> _deletePhoto(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ፎቶ ሰርዝ'),
        content: const Text(
            'ፎቶው ወደ Recycle Bin ይወሰዳል።\nበኋላ Restore ማድረግ ይችላሉ።'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('አይ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ወደ Recycle Bin ላክ')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      photos.remove(path);
      deletedPhotos.add(path);
    });
    await _savePhotos();
  }

  Future<void> _restorePhoto(String path) async {
    setState(() {
      deletedPhotos.remove(path);
      if (!photos.contains(path)) photos.add(path);
    });
    await _savePhotos();
  }

  Future<void> _permanentlyDeletePhoto(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('በቋሚነት ሰርዝ'),
        content: const Text('ይህ ፎቶ በቋሚነት ይሰረዛል። መመለስ አይቻልም።'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ተወው')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ሰርዝ')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    setState(() => deletedPhotos.remove(path));
    await _savePhotos();
  }

  void _openPhotoViewer(String path) {
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

  Widget _buildPhotos() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ፎቶዎች'),
        actions: [
          IconButton(
            tooltip: 'Recycle Bin',
            onPressed: _openRecycleBin,
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
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: photos.length,
              itemBuilder: (_, index) {
                final path = photos[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _openPhotoViewer(path),
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
                          onPressed: () => _deletePhoto(path),
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
            onPressed: () => _addPhoto(ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () => _addPhoto(ImageSource.gallery),
            child: const Icon(Icons.photo),
          ),
        ],
      ),
    );
  }

  void _openRecycleBin() {
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
                      itemBuilder: (_, index) {
                        final path = deletedPhotos[index];
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
                                    size: 50),
                              ),
                              Positioned(
                                bottom: 5,
                                left: 5,
                                right: 5,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => _restorePhoto(path),
                                        icon: const Icon(Icons.restore),
                                        label: const Text('Restore'),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    IconButton.filledTonal(
                                      onPressed: () =>
                                          _permanentlyDeletePhoto(path),
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

  Future<void> _pickSalonPhoto() async {
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final name =
        'salon_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destination = File('${dir.path}/$name');

    await File(picked.path).copy(destination.path);

    setState(() => salonPhoto = destination.path);
    await _saveProfile();
  }

  void _editProfile() {
    final nameController = TextEditingController(text: salonName);
    final phoneController = TextEditingController(text: phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('የሳሎን መረጃ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'የሳሎን ስም'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ስልክ ቁጥር'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ይቅር'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                salonName = nameController.text.trim().isEmpty
                    ? 'የእኔ ሳሎን'
                    : nameController.text.trim();
                phoneNumber = phoneController.text.trim();
              });
              await _saveProfile();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('አስቀምጥ'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
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
                    onTap: _pickSalonPhoto,
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (phoneNumber.isNotEmpty) Text(phoneNumber),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _editProfile,
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
                      selectedReportYear = 0;
                      selectedReportMonth = 0;
                      _ensureReportSelection();
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
                      selectedReportYear = 0;
                      selectedReportMonth = 0;
                      _ensureReportSelection();
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
          Card(
            child: const ListTile(
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _currentPage() {
    switch (currentIndex) {
      case 0:
        return _buildHome();
      case 1:
        return _buildHistory();
      case 2:
        return _buildReports();
      case 3:
        return _buildPhotos();
      case 4:
        return _buildProfile();
      default:
        return _buildHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            setState(() => currentIndex = index),
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
