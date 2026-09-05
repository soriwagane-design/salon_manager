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

  String get monthName {
    const names = [
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
    return names[month];
  }

  String get monthShort => '$year-$month';

  @override
  String toString() => '$day $monthName $year';
}

// Gregorian -> Ethiopian.
// Uses the Ethiopian New Year around September 11/12.
EthiopianDate gregorianToEthiopian(DateTime date) {
  int gYear = date.year;
  int gMonth = date.month;
  int gDay = date.day;

  int jd = _gregorianToJd(gYear, gMonth, gDay);
  int ethYear = ((jd - 1723856) / 365.25).floor() + 1;

  int newYearJd = _ethiopianToJd(ethYear, 1, 1);

  while (jd < newYearJd) {
    ethYear--;
    newYearJd = _ethiopianToJd(ethYear, 1, 1);
  }

  int dayOfYear = jd - newYearJd;
  int month = (dayOfYear / 30).floor() + 1;
  int day = (dayOfYear % 30) + 1;

  return EthiopianDate(ethYear, month, day);
}

int _gregorianToJd(int year, int month, int day) {
  int a = ((14 - month) ~/ 12);
  int y = year + 4800 - a;
  int m = month + 12 * a - 3;

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

// ============================================================
// APP
// ============================================================

class SalonManagerApp extends StatefulWidget {
  const SalonManagerApp({super.key});

  @override
  State<SalonManagerApp> createState() => _SalonManagerAppState();
}

class _SalonManagerAppState extends State<SalonManagerApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);

    setState(() {
      _darkMode = value;
    });
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
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(
        darkMode: _darkMode,
        onDarkModeChanged: _toggleTheme,
      ),
    );
  }
}

// ============================================================
// TRANSACTION MODEL
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

  TransactionItem({
    required this.id,
    required this.title,
    required this.staffName,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.expenseClass,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'staffName': staffName,
      'amount': amount,
      'isIncome': isIncome,
      'category': category,
      'expenseClass': expenseClass,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    final bool income = map['isIncome'] == true;

    String expenseClass =
        map['expenseClass']?.toString() ?? '';

    if (!income && expenseClass.isEmpty) {
      const fixed = [
        'ኪራይ',
        'ውሃ',
        'መብራት',
        'ስልክ',
        'ደመወዝ',
        'ጥበቃ',
      ];

      if (fixed.contains(map['category'])) {
        expenseClass = 'ቋሚ ወጪ';
      } else {
        expenseClass = 'መደበኛ ወጪ';
      }
    }

    return TransactionItem(
      id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      staffName: map['staffName']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isIncome: income,
      category: map['category']?.toString() ?? '',
      expenseClass: expenseClass,
      dateTime: DateTime.tryParse(
            map['dateTime']?.toString() ?? '',
          ) ??
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
  int _currentIndex = 0;

  final List<TransactionItem> _transactions = [];
  final List<String> _photos = [];
  final List<String> _deletedPhotos = [];

  final ImagePicker _picker = ImagePicker();

  bool _showMoney = true;

  String _searchText = '';
  String _filterType = 'all';

  String _salonName = 'የእኔ ሳሎን';
  String _phoneNumber = '';
  String _salonPhoto = '';

  String _calendarMode = 'ethiopian';

  String _selectedMonth = 'all';

  final List<String> _fixedExpenseCategories = [
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

  final List<String> _regularExpenseCategories = [
    'እቃ ግዢ',
    'መጓጓዣ',
    'ጥገና',
    'ምግብ',
    'ሌላ',
  ];

  final List<String> _incomeCategories = [
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

    final transactionsJson = prefs.getString('transactions');
    final photosJson = prefs.getString('photos');
    final deletedPhotosJson = prefs.getString('deletedPhotos');

    if (transactionsJson != null) {
      try {
        final List data = jsonDecode(transactionsJson);
        _transactions
          ..clear()
          ..addAll(
            data.map(
              (e) => TransactionItem.fromMap(
                Map<String, dynamic>.from(e),
              ),
            ),
          );
      } catch (_) {}
    }

    if (photosJson != null) {
      try {
        _photos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(photosJson)));
      } catch (_) {}
    }

    if (deletedPhotosJson != null) {
      try {
        _deletedPhotos
          ..clear()
          ..addAll(List<String>.from(jsonDecode(deletedPhotosJson)));
      } catch (_) {}
    }

    setState(() {
      _salonName = prefs.getString('salonName') ?? 'የእኔ ሳሎን';
      _phoneNumber = prefs.getString('phoneNumber') ?? '';
      _salonPhoto = prefs.getString('salonPhoto') ?? '';
      _calendarMode = prefs.getString('calendarMode') ?? 'ethiopian';
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'transactions',
      jsonEncode(
        _transactions.map((e) => e.toMap()).toList(),
      ),
    );
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'photos',
      jsonEncode(_photos),
    );

    await prefs.setString(
      'deletedPhotos',
      jsonEncode(_deletedPhotos),
    );
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('salonName', _salonName);
    await prefs.setString('phoneNumber', _phoneNumber);
    await prefs.setString('salonPhoto', _salonPhoto);
    await prefs.setString('calendarMode', _calendarMode);
  }

  // ==========================================================
  // DATE
  // ==========================================================

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  EthiopianDate _eth(DateTime date) {
    return gregorianToEthiopian(date);
  }

  String _formatDate(DateTime date) {
    if (_calendarMode == 'ethiopian') {
      final e = _eth(date);
      return '${e.day.toString().padLeft(2, '0')}/'
          '${e.month.toString().padLeft(2, '0')}/'
          '${e.year}';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _monthKey(DateTime date) {
    if (_calendarMode == 'ethiopian') {
      final e = _eth(date);
      return '${e.year}-${e.month}';
    }

    return '${date.year}-${date.month}';
  }

  String _monthLabel(String key) {
    if (key == 'all') return 'ሁሉም ወራት';

    final parts = key.split('-');
    if (parts.length != 2) return key;

    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;

    if (_calendarMode == 'ethiopian') {
      const names = [
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

      if (month >= 1 && month <= 13) {
        return '${names[month]} $year';
      }
    }

    const gregorianNames = [
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

    if (month >= 1 && month <= 12) {
      return '${gregorianNames[month]} $year';
    }

    return key;
  }

  List<String> get _availableMonths {
    final set = <String>{};

    for (final t in _transactions) {
      set.add(_monthKey(t.dateTime));
    }

    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return ['all', ...list];
  }

  bool _matchesMonth(TransactionItem t) {
    if (_selectedMonth == 'all') return true;
    return _monthKey(t.dateTime) == _selectedMonth;
  }

  // ==========================================================
  // TOTALS
  // ==========================================================

  double _sumIncome(Iterable<TransactionItem> list) {
    return list
        .where((e) => e.isIncome)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double _sumExpense(Iterable<TransactionItem> list) {
    return list
        .where((e) => !e.isIncome)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double _sumFixedExpense(Iterable<TransactionItem> list) {
    return list
        .where(
          (e) => !e.isIncome && e.expenseClass == 'ቋሚ ወጪ',
        )
        .fold(0, (sum, e) => sum + e.amount);
  }

  double _sumRegularExpense(Iterable<TransactionItem> list) {
    return list
        .where(
          (e) => !e.isIncome && e.expenseClass == 'መደበኛ ወጪ',
        )
        .fold(0, (sum, e) => sum + e.amount);
  }

  String _formatMoney(double amount) {
    if (!_showMoney) return '••••';

    return '${amount.toStringAsFixed(2)} ብር';
  }

  List<TransactionItem> get _visibleTransactions {
    final query = _searchText.trim().toLowerCase();

    final list = _transactions.where((t) {
      final searchMatch = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.staffName.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);

      final typeMatch = _filterType == 'all' ||
          (_filterType == 'income' && t.isIncome) ||
          (_filterType == 'expense' && !t.isIncome);

      return searchMatch && typeMatch && _matchesMonth(t);
    }).toList();

    list.sort(
      (a, b) => b.dateTime.compareTo(a.dateTime),
    );

    return list;
  }

  // ==========================================================
  // TRANSACTION ENTRY
  // ==========================================================

  void _openTransactionSheet({
    bool income = true,
    String? expenseClass,
  }) {
    final titleController = TextEditingController();
    final staffController = TextEditingController();
    final amountController = TextEditingController();

    bool isIncome = income;
    String selectedExpenseClass =
        expenseClass ?? 'ቋሚ ወጪ';

    String selectedCategory = isIncome
        ? _incomeCategories.first
        : (selectedExpenseClass == 'ቋሚ ወጪ'
            ? _fixedExpenseCategories.first
            : _regularExpenseCategories.first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = isIncome
                ? _incomeCategories
                : (selectedExpenseClass == 'ቋሚ ወጪ'
                    ? _fixedExpenseCategories
                    : _regularExpenseCategories);

            if (!categories.contains(selectedCategory)) {
              selectedCategory = categories.first;
            }

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
                      isIncome
                          ? '💰 ገቢ መመዝገቢያ'
                          : '💸 ወጪ መመዝገቢያ',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 20),

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
                      onSelectionChanged: (value) {
                        setModalState(() {
                          isIncome = value.first;

                          if (isIncome) {
                            selectedCategory =
                                _incomeCategories.first;
                          } else {
                            selectedCategory =
                                selectedExpenseClass ==
                                        'ቋሚ ወጪ'
                                    ? _fixedExpenseCategories.first
                                    : _regularExpenseCategories.first;
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 14),

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
                        selected: {selectedExpenseClass},
                        onSelectionChanged: (value) {
                          setModalState(() {
                            selectedExpenseClass = value.first;

                            selectedCategory =
                                selectedExpenseClass ==
                                        'ቋሚ ወጪ'
                                    ? _fixedExpenseCategories.first
                                    : _regularExpenseCategories.first;
                          });
                        },
                      ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: titleController,
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
                      keyboardType:
                          const TextInputType.numberWithOptions(
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
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'ምድብ',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    FilledButton.icon(
                      onPressed: () async {
                        final title =
                            titleController.text.trim();
                        final staff =
                            staffController.text.trim();
                        final amount =
                            double.tryParse(
                          amountController.text.trim(),
                        );

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content:
                                  Text('እባክዎ አይነቱን ያስገቡ'),
                            ),
                          );
                          return;
                        }

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content:
                                  Text('ትክክለኛ የገንዘብ መጠን ያስገቡ'),
                            ),
                          );
                          return;
                        }

                        final item = TransactionItem(
                          id: DateTime.now()
                              .microsecondsSinceEpoch
                              .toString(),
                          title: title,
                          staffName: staff,
                          amount: amount,
                          isIncome: isIncome,
                          category: selectedCategory,
                          expenseClass:
                              isIncome ? '' : selectedExpenseClass,
                          dateTime: DateTime.now(),
                        );

                        setState(() {
                          _transactions.add(item);
                        });

                        await _saveTransactions();

                        if (context.mounted) {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                isIncome
                                    ? 'ገቢው ተመዝግቧል ✅'
                                    : 'ወጪው ተመዝግቧል ✅',
                              ),
                            ),
                          );
                        }
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
  // TODAY DETAILS
  // ==========================================================

  void _showTodayDetails(bool income) {
    final today = DateTime.now();

    final records = _transactions
        .where(
          (t) => t.isIncome == income && _sameDay(t.dateTime, today),
        )
        .toList()
      ..sort(
        (a, b) => b.dateTime.compareTo(a.dateTime),
      );

    final total = records.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      income
                          ? 'የዛሬ ገቢዎች'
                          : 'የዛሬ ወጪዎች',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            income
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                          ),
                        ),
                        title: Text(
                          income
                              ? 'የዛሬ ጠቅላላ ገቢ'
                              : 'የዛሬ ጠቅላላ ወጪ',
                        ),
                        trailing: Text(
                          _formatMoney(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text('ዛሬ ምንም መዝገብ የለም'),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final t = records[index];

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                '${index + 1}',
                              ),
                            ),
                            title: Text(
                              t.title.isEmpty
                                  ? t.category
                                  : t.title,
                            ),
                            subtitle: Text(
                              '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName} • '
                              '${t.category} • ${_formatTime(t.dateTime)}',
                            ),
                            trailing: Text(
                              _formatMoney(t.amount),
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
        );
      },
    );
  }

  // ==========================================================
  // HOME
  // ==========================================================

  Widget _buildHome() {
    final today = DateTime.now();

    final todayRecords =
        _transactions.where((t) => _sameDay(t.dateTime, today));

    final todayIncome = _sumIncome(todayRecords);
    final todayExpense = _sumExpense(todayRecords);
    final todayProfit = todayIncome - todayExpense;

    final recent = [..._transactions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _salonName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ገንዘብ አሳይ/ደብቅ',
            onPressed: () {
              setState(() {
                _showMoney = !_showMoney;
              });
            },
            icon: Icon(
              _showMoney
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.035),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 120,
            child: Icon(
              Icons.spa,
              size: 180,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.035),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'የዛሬ አጠቃላይ ሁኔታ',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _todayCard(
                        title: 'የዛሬ ገቢ',
                        amount: todayIncome,
                        icon: Icons.arrow_downward,
                        onTap: () =>
                            _showTodayDetails(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _todayCard(
                        title: 'የዛሬ ወጪ',
                        amount: todayExpense,
                        icon: Icons.arrow_upward,
                        onTap: () =>
                            _showTodayDetails(false),
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
                    subtitle: const Text(
                      'ገቢ - ወጪ',
                    ),
                    trailing: Text(
                      _formatMoney(todayProfit),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          _openTransactionSheet(
                            income: true,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('ገቢ መመዝገቢያ'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _openTransactionSheet(
                            income: false,
                            expenseClass: 'ቋሚ ወጪ',
                          );
                        },
                        icon: const Icon(Icons.home_work),
                        label: const Text('ቋሚ ወጪ'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _openTransactionSheet(
                            income: false,
                            expenseClass: 'መደበኛ ወጪ',
                          );
                        },
                        icon: const Icon(Icons.shopping_bag),
                        label: const Text('መደበኛ ወጪ'),
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
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 10),

                _buildSimpleChart(),

                const SizedBox(height: 24),

                Text(
                  'የቅርብ ጊዜ መዝገቦች',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                if (recent.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(
                        child: Text(
                          'እስካሁን ምንም መዝገብ የለም',
                        ),
                      ),
                    ),
                  )
                else
                  ...recent.take(5).map(_transactionTile),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openTransactionSheet();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _todayCard({
    required String title,
    required double amount,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(icon),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatMoney(amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
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

  // ==========================================================
  // SIMPLE CHART
  // ==========================================================

  Widget _buildSimpleChart() {
    final income = _sumIncome(_transactions);
    final expense = _sumExpense(_transactions);

    final max = income > expense ? income : expense;

    if (max == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text('ግራፉን ለማሳየት መዝገብ ያስገቡ'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _chartBar(
              label: 'ገቢ',
              amount: income,
              max: max,
              icon: Icons.arrow_downward,
            ),
            const SizedBox(height: 18),
            _chartBar(
              label: 'ወጪ',
              amount: expense,
              max: max,
              icon: Icons.arrow_upward,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartBar({
    required String label,
    required double amount,
    required double max,
    required IconData icon,
  }) {
    final ratio =
        max == 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(_formatMoney(amount)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 14,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // HISTORY
  // ==========================================================

  Widget _buildHistory() {
    final list = _visibleTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('የሂሳብ መዝገብ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ፈልግ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchText = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterType,
                    decoration: const InputDecoration(
                      labelText: 'አይነት',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('ሁሉም'),
                      ),
                      DropdownMenuItem(
                        value: 'income',
                        child: Text('ገቢ'),
                      ),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('ወጪ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterType = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _availableMonths.contains(_selectedMonth)
                        ? _selectedMonth
                        : 'all',
                    decoration: const InputDecoration(
                      labelText: 'ወር',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableMonths
                        .map(
                          (key) => DropdownMenuItem(
                            value: key,
                            child: Text(
                              _monthLabel(key),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('ምንም መዝገብ አልተገኘም'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return _transactionTile(list[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openTransactionSheet();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _transactionTile(TransactionItem t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            t.isIncome
                ? Icons.arrow_downward
                : Icons.arrow_upward,
          ),
        ),
        title: Text(
          t.title.isEmpty ? t.category : t.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${t.staffName.isEmpty ? 'ስም የለም' : t.staffName}\n'
          '${t.category} • ${_formatDate(t.dateTime)} • ${_formatTime(t.dateTime)}'
          '${t.isIncome ? '' : '\n${t.expenseClass}'}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatMoney(t.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            const Icon(
              Icons.lock_outline,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // REPORTS
  // ==========================================================

  Widget _buildReports() {
    final today = DateTime.now();

    final todayList =
        _transactions.where((t) => _sameDay(t.dateTime, today));

    final monthList = _selectedMonth == 'all'
        ? _transactions
        : _transactions.where(_matchesMonth);

    final todayIncome = _sumIncome(todayList);
    final todayExpense = _sumExpense(todayList);
    final todayProfit = todayIncome - todayExpense;

    final monthIncome = _sumIncome(monthList);
    final monthExpense = _sumExpense(monthList);
    final fixed = _sumFixedExpense(monthList);
    final regular = _sumRegularExpense(monthList);
    final monthProfit = monthIncome - monthExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ሪፖርት'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'የቀን ሪፖርት',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          _reportCard(
            'የዛሬ ገቢ',
            todayIncome,
            Icons.arrow_downward,
          ),
          _reportCard(
            'የዛሬ ወጪ',
            todayExpense,
            Icons.arrow_upward,
          ),
          _reportCard(
            'የዛሬ ትርፍ',
            todayProfit,
            Icons.account_balance_wallet,
          ),

          const SizedBox(height: 25),

          Text(
            'የወር ሪፖርት',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: _availableMonths.contains(_selectedMonth)
                ? _selectedMonth
                : 'all',
            decoration: const InputDecoration(
              labelText: 'ወር ምረጥ',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
            ),
            items: _availableMonths
                .map(
                  (key) => DropdownMenuItem(
                    value: key,
                    child: Text(_monthLabel(key)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMonth = value;
                });
              }
            },
          ),

          const SizedBox(height: 14),

          if (_selectedMonth != 'all')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'የተመረጠው፦ ${_monthLabel(_selectedMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),

          _reportCard(
            'የወሩ ገቢ',
            monthIncome,
            Icons.trending_up,
          ),
          _reportCard(
            'የወሩ ወጪ',
            monthExpense,
            Icons.trending_down,
          ),
          _reportCard(
            'ቋሚ ወጪ',
            fixed,
            Icons.home_work,
          ),
          _reportCard(
            'መደበኛ ወጪ',
            regular,
            Icons.shopping_bag,
          ),
          _reportCard(
            'የወሩ ንጹህ ትርፍ',
            monthProfit,
            Icons.account_balance,
          ),

          const SizedBox(height: 25),

          Text(
            'የወር ግራፍ',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          _buildReportChart(
            income: monthIncome,
            expense: monthExpense,
            fixed: fixed,
            regular: regular,
          ),

          const SizedBox(height: 25),

          Text(
            'የሂሳብ መዝገብ ሰንጠረዥ',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          _buildDataTable(monthList.toList()),
        ],
      ),
    );
  }

  Widget _reportCard(
    String title,
    double amount,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        trailing: Text(
          _formatMoney(amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildReportChart({
    required double income,
    required double expense,
    required double fixed,
    required double regular,
  }) {
    final values = [
      income,
      expense,
      fixed,
      regular,
    ];

    final max = values.reduce(
      (a, b) => a > b ? a : b,
    );

    if (max == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: Text('የወሩ መረጃ የለም'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _chartBar(
              label: 'ገቢ',
              amount: income,
              max: max,
              icon: Icons.arrow_downward,
            ),
            const SizedBox(height: 15),
            _chartBar(
              label: 'ጠቅላላ ወጪ',
              amount: expense,
              max: max,
              icon: Icons.arrow_upward,
            ),
            const SizedBox(height: 15),
            _chartBar(
              label: 'ቋሚ ወጪ',
              amount: fixed,
              max: max,
              icon: Icons.home_work,
            ),
            const SizedBox(height: 15),
            _chartBar(
              label: 'መደበኛ ወጪ',
              amount: regular,
              max: max,
              icon: Icons.shopping_bag,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<TransactionItem> list) {
    if (list.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: Center(
            child: Text('ለዚህ ወር መረጃ የለም'),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ቀን')),
            DataColumn(label: Text('ሰዓት')),
            DataColumn(label: Text('ሰው')),
            DataColumn(label: Text('አይነት')),
            DataColumn(label: Text('ምድብ')),
            DataColumn(label: Text('ገቢ')),
            DataColumn(label: Text('ወጪ')),
          ],
          rows: list.map((t) {
            return DataRow(
              cells: [
                DataCell(Text(_formatDate(t.dateTime))),
                DataCell(Text(_formatTime(t.dateTime))),
                DataCell(
                  Text(
                    t.staffName.isEmpty
                        ? '-'
                        : t.staffName,
                  ),
                ),
                DataCell(Text(t.title)),
                DataCell(Text(t.category)),
                DataCell(
                  Text(
                    t.isIncome
                        ? _formatMoney(t.amount)
                        : '-',
                  ),
                ),
                DataCell(
                  Text(
                    !t.isIncome
                        ? _formatMoney(t.amount)
                        : '-',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================================
  // PHOTOS
  // ==========================================================

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final XFile? picked =
          await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) return;

      final directory =
          await getApplicationDocumentsDirectory();

      final fileName =
          'salon_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final destination =
          File('${directory.path}/$fileName');

      await File(picked.path).copy(destination.path);

      setState(() {
        _photos.add(destination.path);
      });

      await _savePhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ፎቶው ተቀምጧል ✅'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ፎቶ ማስገባት አልተቻለም: $e'),
          ),
        );
      }
    }
  }

  Future<void> _deletePhoto(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ፎቶ ሰርዝ'),
          content: const Text(
            'ፎቶው ወደ Recycle Bin ይወሰዳል።\n'
            'በኋላ Restore ማድረግ ይችላሉ።',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('አይ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ወደ Recycle Bin ላክ'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _photos.remove(path);
      _deletedPhotos.add(path);
    });

    await _savePhotos();
  }

  Future<void> _restorePhoto(String path) async {
    setState(() {
      _deletedPhotos.remove(path);
      if (!_photos.contains(path)) {
        _photos.add(path);
      }
    });

    await _savePhotos();
  }

  Future<void> _permanentlyDeletePhoto(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('በቋሚነት ሰርዝ'),
          content: const Text(
            'ይህ ፎቶ በቋሚነት ይሰረዛል። መመለስ አይቻልም።',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ተወው'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ሰርዝ'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    setState(() {
      _deletedPhotos.remove(path);
    });

    await _savePhotos();
  }

  void _openPhotoViewer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('ፎቶ'),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Text('ፎቶው አልተገኘም'),
                    );
                  },
                ),
              ),
            ),
          );
        },
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
              isLabelVisible: _deletedPhotos.isNotEmpty,
              label: Text(
                '${_deletedPhotos.length}',
              ),
              child: const Icon(
                Icons.delete_outline,
              ),
            ),
          ),
        ],
      ),
      body: _photos.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 70,
                  ),
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
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final path = _photos[index];

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _openPhotoViewer(path),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.broken_image,
                              size: 50,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton.filledTonal(
                          onPressed: () =>
                              _deletePhoto(path),
                          icon: const Icon(
                            Icons.delete,
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 6,
                        left: 6,
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                        ),
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
            onPressed: () =>
                _addPhoto(ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () =>
                _addPhoto(ImageSource.gallery),
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
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '🗑️ Recycle Bin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _deletedPhotos.isEmpty
                    ? const Center(
                        child: Text(
                          'Recycle Bin ባዶ ነው',
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
                        itemCount: _deletedPhotos.length,
                        itemBuilder: (context, index) {
                          final path =
                              _deletedPhotos[index];

                          return Card(
                            clipBehavior:
                                Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) {
                                    return const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 5,
                                  left: 5,
                                  right: 5,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child:
                                            FilledButton.tonalIcon(
                                          onPressed: () {
                                            _restorePhoto(
                                                path);
                                          },
                                          icon: const Icon(
                                            Icons.restore,
                                          ),
                                          label: const Text(
                                            'Restore',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 5),
                                      IconButton.filledTonal(
                                        onPressed: () =>
                                            _permanentlyDeletePhoto(
                                                path),
                                        icon: const Icon(
                                          Icons.delete_forever,
                                        ),
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
        );
      },
    );
  }

  // ==========================================================
  // PROFILE / SETTINGS
  // ==========================================================

  Future<void> _pickSalonPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final directory =
        await getApplicationDocumentsDirectory();

    final fileName =
        'salon_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final destination =
        File('${directory.path}/$fileName');

    await File(picked.path).copy(destination.path);

    setState(() {
      _salonPhoto = destination.path;
    });

    await _saveProfile();
  }

  void _editProfile() {
    final nameController =
        TextEditingController(text: _salonName);

    final phoneController =
        TextEditingController(text: _phoneNumber);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('የሳሎን መረጃ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'የሳሎን ስም',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'ስልክ ቁጥር',
                ),
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
                  _salonName =
                      nameController.text.trim().isEmpty
                          ? 'የእኔ ሳሎን'
                          : nameController.text.trim();

                  _phoneNumber =
                      phoneController.text.trim();
                });

                await _saveProfile();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('አስቀምጥ'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfile() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('እኔ / Settings'),
      ),
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
                          _salonPhoto.isNotEmpty
                              ? FileImage(
                                  File(_salonPhoto),
                                )
                              : null,
                      child: _salonPhoto.isEmpty
                          ? const Icon(
                              Icons.storefront,
                              size: 50,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _salonName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_phoneNumber.isNotEmpty)
                    Text(_phoneNumber),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      'የሳሎን መረጃ ቀይር',
                    ),
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
                  subtitle: Text(
                    'በአፑ ውስጥ ቀንና ወር እንዴት እንዲታይ ይምረጡ',
                  ),
                ),

                RadioListTile<String>(
                  value: 'ethiopian',
                  groupValue: _calendarMode,
                  title: const Text(
                    '🇪🇹 የኢትዮጵያ አቆጣጠር',
                  ),
                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      _calendarMode = value;
                      _selectedMonth = 'all';
                    });

                    await _saveProfile();
                  },
                ),

                RadioListTile<String>(
                  value: 'gregorian',
                  groupValue: _calendarMode,
                  title: const Text(
                    '🌍 Gregorian',
                  ),
                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      _calendarMode = value;
                      _selectedMonth = 'all';
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
              leading: Icon(Icons.lock),
              title: Text('የሂሳብ መዝገቦች'),
              subtitle: Text(
                'የተመዘገቡ ገቢና ወጪዎች በአፑ ውስጥ አይሰረዙም።',
              ),
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
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          const SizedBox(height: 5),

          const Center(
            child: Text(
              'የሳሎን ገቢና ወጪ መዝገብ',
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  Widget _currentPage() {
    switch (_currentIndex) {
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
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
