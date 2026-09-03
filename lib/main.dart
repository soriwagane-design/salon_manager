import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SalonManagerApp());
}

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

    if (!mounted) return;

    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', value);

    if (!mounted) return;

    setState(() {
      _darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salon Manager',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: MainScreen(
        darkMode: _darkMode,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}

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
    final category = map['category']?.toString() ?? 'ሌላ';

    final oldExpenseClass =
        map['expenseClass']?.toString() ?? '';

    String expenseClass = oldExpenseClass;

    // ከዚህ በፊት የተመዘገቡ ወጪዎችንም
    // በራሱ እንዲመድብ ያደርጋል።
    if (expenseClass.isEmpty && map['isIncome'] != true) {
      const fixed = [
        'ኪራይ',
        'ውሃ',
        'መብራት',
        'ስልክ',
        'ደመወዝ',
        'ጥበቃ',
      ];

      expenseClass = fixed.contains(category)
          ? 'ቋሚ ወጪ'
          : 'መደበኛ ወጪ';
    }

    if (map['isIncome'] == true) {
      expenseClass = '';
    }

    return TransactionItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      staffName:
          map['staffName']?.toString() ?? 'ያልተጠቀሰ',
      amount:
          double.tryParse(map['amount'].toString()) ?? 0,
      isIncome: map['isIncome'] == true,
      category: category,
      expenseClass: expenseClass,
      dateTime:
          DateTime.tryParse(
                map['dateTime']?.toString() ?? '',
              ) ??
              DateTime.now(),
    );
  }
}

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

  final ImagePicker _picker = ImagePicker();

  bool _showMoney = true;

  String _searchText = '';
  String _filterType = 'all';

  String _salonName = 'የእኔ ሳሎን';
  String _phoneNumber = '';
  String _salonPhoto = '';

  String _selectedMonth = 'all';

  final List<String> _fixedExpenseCategories = [
    'ኪራይ',
    'ውሃ',
    'መብራት',
    'ስልክ',
    'ደመወዝ',
    'ጥበቃ',
  ];

  final List<String> _regularExpenseCategories = [
    'እቃ ግዢ',
    'መጓጓዣ',
    'ጥገና',
    'ሌላ',
  ];

  final List<String> _incomeCategories = [
    'ፀጉር ስራ',
    'ካንቲስ',
    'ማስተካከያ',
    'ማቅለም',
    'ምርት ሽያጭ',
    'ሌላ',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions =
        prefs.getString('transactions');

    if (savedTransactions != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(savedTransactions);

        _transactions.clear();

        for (final item in decoded) {
          _transactions.add(
            TransactionItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'Transactions load error: $e',
        );
      }
    }

    final savedPhotos =
        prefs.getStringList('photos');

    if (savedPhotos != null) {
      _photos.clear();
      _photos.addAll(savedPhotos);
    }

    _salonName =
        prefs.getString('salonName') ??
            'የእኔ ሳሎን';

    _phoneNumber =
        prefs.getString('phoneNumber') ?? '';

    _salonPhoto =
        prefs.getString('salonPhoto') ?? '';

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _saveTransactions() async {
    final prefs =
        await SharedPreferences.getInstance();

    final data =
        _transactions.map((item) => item.toMap()).toList();

    await prefs.setString(
      'transactions',
      jsonEncode(data),
    );
  }

  Future<void> _savePhotos() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      'photos',
      _photos,
    );
  }

  Future<void> _saveProfile() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'salonName',
      _salonName,
    );

    await prefs.setString(
      'phoneNumber',
      _phoneNumber,
    );

    await prefs.setString(
      'salonPhoto',
      _salonPhoto,
    );
  }

  List<TransactionItem> get visibleTransactions {
    return _transactions.where((item) {
      final search =
          _searchText.toLowerCase();

      final matchesSearch =
          item.title
                  .toLowerCase()
                  .contains(search) ||
              item.staffName
                  .toLowerCase()
                  .contains(search) ||
              item.category
                  .toLowerCase()
                  .contains(search) ||
              item.expenseClass
                  .toLowerCase()
                  .contains(search);

      final matchesType =
          _filterType == 'all' ||
          (_filterType == 'income' &&
              item.isIncome) ||
          (_filterType == 'expense' &&
              !item.isIncome);

      final matchesMonth =
          _selectedMonth == 'all' ||
          '${item.dateTime.year}-'
                  '${item.dateTime.month.toString().padLeft(2, '0')}' ==
              _selectedMonth;

      return matchesSearch &&
          matchesType &&
          matchesMonth;
    }).toList()
      ..sort(
        (a, b) =>
            b.dateTime.compareTo(a.dateTime),
      );
  }

  double _sumIncome(
    Iterable<TransactionItem> list,
  ) {
    return list
        .where((item) => item.isIncome)
        .fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
  }

  double _sumExpense(
    Iterable<TransactionItem> list,
  ) {
    return list
        .where((item) => !item.isIncome)
        .fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
  }

  double _sumFixedExpense(
    Iterable<TransactionItem> list,
  ) {
    return list
        .where(
          (item) =>
              !item.isIncome &&
              item.expenseClass == 'ቋሚ ወጪ',
        )
        .fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
  }

  double _sumRegularExpense(
    Iterable<TransactionItem> list,
  ) {
    return list
        .where(
          (item) =>
              !item.isIncome &&
              item.expenseClass == 'መደበኛ ወጪ',
        )
        .fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
  }

  double get totalIncome =>
      _sumIncome(_transactions);

  double get totalExpense =>
      _sumExpense(_transactions);

  double get totalFixedExpense =>
      _sumFixedExpense(_transactions);

  double get totalRegularExpense =>
      _sumRegularExpense(_transactions);

  double get totalProfit =>
      totalIncome - totalExpense;

  double get selectedIncome =>
      _sumIncome(visibleTransactions);

  double get selectedExpense =>
      _sumExpense(visibleTransactions);

  double get selectedFixedExpense =>
      _sumFixedExpense(visibleTransactions);

  double get selectedRegularExpense =>
      _sumRegularExpense(visibleTransactions);

  double get selectedProfit =>
      selectedIncome - selectedExpense;

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ብር';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  List<String> get _availableMonths {
    final months = <String>{};

    for (final item in _transactions) {
      months.add(
        '${item.dateTime.year}-'
        '${item.dateTime.month.toString().padLeft(2, '0')}',
      );
    }

    final result = months.toList()
      ..sort(
        (a, b) => b.compareTo(a),
      );

    return result;
  }

  String _monthLabel(String value) {
    if (value == 'all') {
      return 'ሁሉንም ወራት';
    }

    final parts = value.split('-');

    if (parts.length != 2) {
      return value;
    }

    final year = parts[0];
    final month =
        int.tryParse(parts[1]) ?? 1;

    const names = [
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

    return '${names[month - 1]} $year';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showTransactionDialog({
    bool? defaultIsIncome,
  }) {
    final workController =
        TextEditingController();

    final staffController =
        TextEditingController();

    final amountController =
        TextEditingController();

    bool isIncome =
        defaultIsIncome ?? true;

    String expenseClass =
        'ቋሚ ወጪ';

    String selectedCategory =
        isIncome
            ? _incomeCategories.first
            : _fixedExpenseCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder:
              (context, setModalState) {
            final categories = isIncome
                ? _incomeCategories
                : expenseClass == 'ቋሚ ወጪ'
                    ? _fixedExpenseCategories
                    : _regularExpenseCategories;

            if (!categories
                .contains(selectedCategory)) {
              selectedCategory =
                  categories.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context)
                            .viewInsets
                            .bottom +
                        20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      isIncome
                          ? '🟢 አዲስ ገቢ መዝግብ'
                          : '🔴 አዲስ ወጪ መዝግብ',
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              RadioListTile<
                                  bool>(
                            title:
                                const Text(
                              '🟢 ገቢ',
                            ),
                            value: true,
                            groupValue:
                                isIncome,
                            onChanged:
                                (value) {
                              setModalState(() {
                                isIncome =
                                    true;

                                selectedCategory =
                                    _incomeCategories
                                        .first;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child:
                              RadioListTile<
                                  bool>(
                            title:
                                const Text(
                              '🔴 ወጪ',
                            ),
                            value: false,
                            groupValue:
                                isIncome,
                            onChanged:
                                (value) {
                              setModalState(() {
                                isIncome =
                                    false;

                                expenseClass =
                                    'ቋሚ ወጪ';

                                selectedCategory =
                                    _fixedExpenseCategories
                                        .first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // የገቢ ማስገቢያ
                    TextField(
                      controller:
                          workController,
                      decoration:
                          InputDecoration(
                        labelText: isIncome
                            ? 'የሥራ አይነት'
                            : 'የወጪ መግለጫ',
                        hintText: isIncome
                            ? 'ለምሳሌ፦ ፀጉር ስራ'
                            : 'ለምሳሌ፦ የሳሎን እቃ',
                        prefixIcon:
                            Icon(
                          isIncome
                              ? Icons
                                  .content_cut
                              : Icons
                                  .description,
                        ),
                        border:
                            const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          staffController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'የሰራተኛ / የሰው ስም',
                        prefixIcon:
                            Icon(Icons.person),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          amountController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'የገንዘብ መጠን (ብር)',
                        prefixIcon:
                            Icon(Icons.money),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    if (!isIncome)
                      Column(
                        children: [
                          const Align(
                            alignment:
                                Alignment.centerLeft,
                            child: Text(
                              'የወጪ አይነት',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          SegmentedButton<
                              String>(
                            segments: const [
                              ButtonSegment(
                                value:
                                    'ቋሚ ወጪ',
                                label:
                                    Text(
                                  'ቋሚ ወጪ',
                                ),
                                icon:
                                    Icon(
                                  Icons
                                      .lock,
                                ),
                              ),
                              ButtonSegment(
                                value:
                                    'መደበኛ ወጪ',
                                label:
                                    Text(
                                  'መደበኛ ወጪ',
                                ),
                                icon:
                                    Icon(
                                  Icons
                                      .repeat,
                                ),
                              ),
                            ],
                            selected: {
                              expenseClass
                            },
                            onSelectionChanged:
                                (value) {
                              setModalState(() {
                                expenseClass =
                                    value
                                        .first;

                                selectedCategory =
                                    expenseClass ==
                                            'ቋሚ ወጪ'
                                        ? _fixedExpenseCategories
                                            .first
                                        : _regularExpenseCategories
                                            .first;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ),
                        ],
                      ),

                    DropdownButtonFormField<
                        String>(
                      value: selectedCategory,
                      decoration:
                          InputDecoration(
                        labelText: isIncome
                            ? 'የሥራ / የገቢ ምድብ'
                            : 'የወጪ ምድብ',
                        prefixIcon:
                            Icon(
                          isIncome
                              ? Icons
                                  .trending_up
                              : Icons.category,
                        ),
                        border:
                            const OutlineInputBorder(),
                      ),
                      items:
                          categories.map(
                        (category) {
                          return DropdownMenuItem<
                              String>(
                            value: category,
                            child:
                                Text(
                              category,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setModalState(() {
                          selectedCategory =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                      child:
                          const Row(
                        children: [
                          Icon(Icons.lock),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ከተመዘገበ በኋላ ይህ የሂሳብ መዝገብ Edit ወይም Delete አይደረግም።',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton.icon(
                        icon: const Icon(
                          Icons.lock,
                        ),
                        label:
                            const Text(
                          'ቋሚ ሆኖ መዝግብ',
                        ),
                        onPressed:
                            () async {
                          final title =
                              workController
                                  .text
                                  .trim();

                          final staff =
                              staffController
                                  .text
                                  .trim();

                          final amount =
                              double.tryParse(
                            amountController
                                .text
                                .trim()
                                .replaceAll(
                                  ',',
                                  '',
                                ),
                          );

                          if (title.isEmpty) {
                            _showMessage(
                              isIncome
                                  ? 'የሥራ አይነት ያስገቡ'
                                  : 'የወጪ መግለጫ ያስገቡ',
                            );
                            return;
                          }

                          if (amount ==
                                  null ||
                              amount <= 0) {
                            _showMessage(
                              'ትክክለኛ የገንዘብ መጠን ያስገቡ',
                            );
                            return;
                          }

                          final newItem =
                              TransactionItem(
                            id: DateTime
                                .now()
                                .microsecondsSinceEpoch
                                .toString(),
                            title: title,
                            staffName:
                                staff.isEmpty
                                    ? 'ያልተጠቀሰ'
                                    : staff,
                            amount: amount,
                            isIncome:
                                isIncome,
                            category:
                                selectedCategory,
                            expenseClass:
                                isIncome
                                    ? ''
                                    : expenseClass,
                            dateTime:
                                DateTime.now(),
                          );

                          setState(() {
                            _transactions
                                .add(
                              newItem,
                            );
                          });

                          await _saveTransactions();

                          if (sheetContext
                              .mounted) {
                            Navigator.pop(
                              sheetContext,
                            );
                          }

                          _showMessage(
                            isIncome
                                ? 'ገቢው በቋሚነት ተመዝግቧል'
                                : 'ወጪው በቋሚነት ተመዝግቧል',
                          );
                        },
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

  Widget _moneyText(
    double amount, {
    required Color color,
  }) {
    return Text(
      _showMoney
          ? _formatMoney(amount)
          : '******',
      style: TextStyle(
        color: color,
        fontWeight:
            FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _summaryRow(
    String title,
    double amount,
    Color color,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        _moneyText(
          amount,
          color: color,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      color: Colors.teal.shade800,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'የሳሎን ሂሳብ ማጠቃለያ',
                    style:
                        TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showMoney =
                          !_showMoney;
                    });
                  },
                  icon: Icon(
                    _showMoney
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const Divider(
              color: Colors.white54,
            ),

            _summaryRow(
              '🟢 ጠቅላላ ገቢ',
              selectedIncome,
              Colors.greenAccent,
            ),

            const SizedBox(
              height: 12,
            ),

            _summaryRow(
              '🔴 ጠቅላላ ወጪ',
              selectedExpense,
              Colors.redAccent,
            ),

            const SizedBox(
              height: 8,
            ),

            _summaryRow(
              '🏠 ቋሚ ወጪ',
              selectedFixedExpense,
              Colors.orangeAccent,
            ),

            const SizedBox(
              height: 8,
            ),

            _summaryRow(
              '🔄 መደበኛ ወጪ',
              selectedRegularExpense,
              Colors.yellowAccent,
            ),

            const Divider(
              color: Colors.white54,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  '💰 የተጣራ ትርፍ',
                  style:
                      TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                _moneyText(
                  selectedProfit,
                  color:
                      selectedProfit >= 0
                          ? Colors.greenAccent
                          : Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTypeCard({
    required String title,
    required double amount,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle:
            const Text(
          'ከጠቅላላ ወጪ ውስጥ',
        ),
        trailing:
            _moneyText(
          amount,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadAllData();
      },
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),

          const SizedBox(
            height: 18,
          ),

          if (_availableMonths
              .isNotEmpty)
            DropdownButtonFormField<
                String>(
              value: _selectedMonth,
              decoration:
                  const InputDecoration(
                labelText:
                    'የሂሳብ ወር ምረጥ',
                prefixIcon: Icon(
                  Icons.calendar_month,
                ),
                border:
                    OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'ሁሉንም ወራት',
                  ),
                ),
                ..._availableMonths
                    .map(
                  (month) =>
                      DropdownMenuItem(
                    value: month,
                    child: Text(
                      _monthLabel(
                        month,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged:
                  (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  _selectedMonth =
                      value;
                });
              },
            ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            'የወጪ ክፍፍል',
            style:
                TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          _buildExpenseTypeCard(
            title:
                '🏠 ቋሚ ወጪ',
            amount:
                selectedFixedExpense,
            icon:
                Icons.lock,
          ),

          _buildExpenseTypeCard(
            title:
                '🔄 መደበኛ ወጪ',
            amount:
                selectedRegularExpense,
            icon:
                Icons.repeat,
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'ፈጣን መዝገብ',
            style:
                TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              Expanded(
                child:
                    ElevatedButton.icon(
                  icon: const Icon(
                    Icons.add_circle,
                  ),
                  label:
                      const Text(
                    'ገቢ ጨምር',
                  ),
                  onPressed: () {
                    _showTransactionDialog(
                      defaultIsIncome:
                          true,
                    );
                  },
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    ElevatedButton.icon(
                  icon: const Icon(
                    Icons.remove_circle,
                  ),
                  label:
                      const Text(
                    'ወጪ ጨምር',
                  ),
                  onPressed: () {
                    _showTransactionDialog(
                      defaultIsIncome:
                          false,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          _buildCharts(),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'የቅርብ ጊዜ መዝገቦች',
            style:
                TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          if (visibleTransactions
              .isEmpty)
            const Padding(
              padding:
                  EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons
                          .receipt_long,
                      size: 60,
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Text(
                      'እስካሁን የተመዘገበ ሂሳብ የለም',
                    ),
                  ],
                ),
              ),
            )
          else
            ...visibleTransactions
                .take(5)
                .map(
                  _transactionCard,
                ),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    final incomeByCategory =
        <String, double>{};

    final expenseByCategory =
        <String, double>{};

    for (final item
        in visibleTransactions) {
      if (item.isIncome) {
        incomeByCategory[item.category] =
            (incomeByCategory[
                    item.category] ??
                0) +
            item.amount;
      } else {
        expenseByCategory[item.category] =
            (expenseByCategory[
                    item.category] ??
                0) +
            item.amount;
      }
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 የገቢ እና ወጪ ግራፍ',
          style:
              TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        _buildCategoryChart(
          title:
              '🟢 ገቢ በሥራ አይነት',
          data:
              incomeByCategory,
          positive: true,
        ),

        const SizedBox(
          height: 14,
        ),

        _buildCategoryChart(
          title:
              '🔴 ወጪ በምድብ',
          data:
              expenseByCategory,
          positive: false,
        ),
      ],
    );
  }

  Widget _buildCategoryChart({
    required String title,
    required Map<String, double> data,
    required bool positive,
  }) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Text(
            '$title\n\nለማሳየት መረጃ የለም።',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final entries =
        data.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    final maxValue =
        entries.first.value;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            ...entries.map(
              (entry) {
                final ratio =
                    maxValue <= 0
                        ? 0.0
                        : entry.value /
                            maxValue;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatMoney(
                              entry.value,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                        child:
                            LinearProgressIndicator(
                          value:
                              ratio,
                          minHeight:
                              10,
                          color: positive
                              ? Colors
                                  .green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionCard(
    TransactionItem item,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              item.isIncome
                  ? Colors.green
                  : Colors.red,
          child: Icon(
            item.isIncome
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color:
                Colors.white,
          ),
        ),
        title: Text(
          item.title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${item.isIncome ? 'የሥራ አይነት' : item.expenseClass}\n'
          '${item.category}\n'
          '${item.staffName}\n'
          '${_formatDate(item.dateTime)}  '
          '${_formatTime(item.dateTime)}',
        ),
        isThreeLine: true,
        trailing:
            SizedBox(
          width: 105,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            crossAxisAlignment:
                CrossAxisAlignment
                    .end,
            children: [
              Text(
                '${item.isIncome ? '+' : '-'}'
                '${item.amount.toStringAsFixed(2)}',
                style:
                    TextStyle(
                  color:
                      item.isIncome
                          ? Colors.green
                          : Colors.red,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock,
                    size: 15,
                  ),
                  SizedBox(
                    width: 3,
                  ),
                  Text(
                    'ቋሚ',
                    style:
                        TextStyle(
                      fontSize: 11,
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

  Widget _buildHistory() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchText =
                    value;
              });
            },
            decoration:
                const InputDecoration(
              labelText:
                  'ሂሳብ ፈልግ',
              prefixIcon:
                  Icon(Icons.search),
              border:
                  OutlineInputBorder(),
            ),
          ),
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child:
              DropdownButtonFormField<
                  String>(
            value: _filterType,
            decoration:
                const InputDecoration(
              border:
                  OutlineInputBorder(),
              labelText:
                  'የሂሳብ አይነት',
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child:
                    Text('ሁሉንም'),
              ),
              DropdownMenuItem(
                value: 'income',
                child:
                    Text('🟢 ገቢ'),
              ),
              DropdownMenuItem(
                value: 'expense',
                child:
                    Text('🔴 ወጪ'),
              ),
            ],
            onChanged:
                (value) {
              if (value ==
                  null) {
                return;
              }

              setState(() {
                _filterType =
                    value;
              });
            },
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child:
              DropdownButtonFormField<
                  String>(
            value:
                _selectedMonth,
            decoration:
                const InputDecoration(
              border:
                  OutlineInputBorder(),
              labelText: 'ወር',
              prefixIcon: Icon(
                Icons.calendar_month,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text(
                  'ሁሉንም ወራት',
                ),
              ),
              ..._availableMonths
                  .map(
                (month) =>
                    DropdownMenuItem(
                  value: month,
                  child: Text(
                    _monthLabel(
                      month,
                    ),
                  ),
                ),
              ),
            ],
            onChanged:
                (value) {
              if (value ==
                  null) {
                return;
              }

              setState(() {
                _selectedMonth =
                    value;
              });
            },
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ገቢ',
                        ),
                        _moneyText(
                          selectedIncome,
                          color:
                              Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ወጪ',
                        ),
                        _moneyText(
                          selectedExpense,
                          color:
                              Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ትርፍ',
                        ),
                        _moneyText(
                          selectedProfit,
                          color:
                              selectedProfit >=
                                      0
                                  ? Colors
                                      .green
                                  : Colors
                                      .red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Expanded(
          child:
              visibleTransactions
                      .isEmpty
                  ? const Center(
                      child: Text(
                        'ምንም መረጃ አልተገኘም',
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets
                              .all(
                        10,
                      ),
                      itemCount:
                          visibleTransactions
                              .length,
                      itemBuilder:
                          (context,
                              index) {
                        return _transactionCard(
                          visibleTransactions[
                              index],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildExcelView() {
    final items =
        visibleTransactions;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'ለExcel View የሚታይ መረጃ የለም',
        ),
      );
    }

    return Card(
      margin:
          const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text(
                'ቀን',
              ),
            ),
            DataColumn(
              label: Text(
                'ሰዓት',
              ),
            ),
            DataColumn(
              label: Text(
                'የሰው ስም',
              ),
            ),
            DataColumn(
              label: Text(
                'የሥራ/ወጪ አይነት',
              ),
            ),
            DataColumn(
              label: Text(
                'ምድብ',
              ),
            ),
            DataColumn(
              label: Text(
                'ገቢ',
              ),
            ),
            DataColumn(
              label: Text(
                'ወጪ',
              ),
            ),
            DataColumn(
              label: Text(
                'የወጪ ክፍል',
              ),
            ),
          ],
          rows: items.map(
            (item) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      _formatDate(
                        item.dateTime,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatTime(
                        item.dateTime,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.staffName,
                    ),
                  ),
                  DataCell(
                    Text(
                      item.title,
                    ),
                  ),
                  DataCell(
                    Text(
                      item.category,
                    ),
                  ),
                  DataCell(
                    Text(
                      item.isIncome
                          ? item.amount
                              .toStringAsFixed(
                              2,
                            )
                          : '-',
                      style:
                          const TextStyle(
                        color:
                            Colors.green,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      !item.isIncome
                          ? item.amount
                              .toStringAsFixed(
                              2,
                            )
                          : '-',
                      style:
                          const TextStyle(
                        color:
                            Colors.red,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.isIncome
                          ? '-'
                          : item.expenseClass,
                    ),
                  ),
                ],
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildReports() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        const Text(
          '📊 ሪፖርት እና ትንታኔ',
          style:
              TextStyle(
            fontSize: 22,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        _buildSummaryCard(),

        const SizedBox(
          height: 16,
        ),

        _buildCharts(),

        const SizedBox(
          height: 20,
        ),

        const Text(
          '📋 Excel-style የሂሳብ ሰንጠረዥ',
          style:
              TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        SizedBox(
          height: 500,
          child: _buildExcelView(),
        ),
      ],
    );
  }

  Future<void> _addGalleryPhoto() async {
    final source =
        await showModalBottomSheet<
            ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'ፎቶ ምረጥ',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.camera_alt,
                ),
                title: const Text(
                  'ካሜራ',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.photo,
                ),
                title: const Text(
                  'Gallery',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final XFile? picked =
          await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      final directory =
          await getApplicationDocumentsDirectory();

      final fileName =
          'salon_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final savedFile = File(
        '${directory.path}/$fileName',
      );

      await File(picked.path)
          .copy(savedFile.path);

      setState(() {
        _photos.add(
          savedFile.path,
        );
      });

      await _savePhotos();

      _showMessage(
        'ፎቶው በቋሚነት ተቀምጧል',
      );
    } catch (e) {
      _showMessage(
        'ፎቶ ማስቀመጥ አልተቻለም',
      );

      debugPrint(
        'Photo error: $e',
      );
    }
  }

  Future<void> _deletePhoto(
    int index,
  ) async {
    _showMessage(
      'የተቀመጠ ፎቶ መሰረዝ አይቻልም',
    );
  }

  Widget _buildGallery() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        const Text(
          '📷 የሳሎን ስራዎች ፎቶ',
          style:
              TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'ከCamera ወይም Gallery ፎቶ ጨምር።',
        ),

        const SizedBox(
          height: 18,
        ),

        SizedBox(
          height: 52,
          width:
              double.infinity,
          child:
              ElevatedButton.icon(
            onPressed:
                _addGalleryPhoto,
            icon: const Icon(
              Icons.add_a_photo,
            ),
            label:
                const Text(
              'ፎቶ ጨምር',
            ),
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        if (_photos.isEmpty)
          const Padding(
            padding:
                EdgeInsets.all(35),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons
                        .photo_library_outlined,
                    size: 65,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    'እስካሁን ፎቶ የለም',
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                _photos.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder:
                (context, index) {
              final path =
                  _photos[index];

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                    child:
                        Image.file(
                      File(path),
                      width:
                          double.infinity,
                      height:
                          double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stack,
                      ) {
                        return Container(
                          color: Colors
                              .grey
                              .shade300,
                          child:
                              const Center(
                            child:
                                Icon(
                              Icons
                                  .broken_image,
                              size: 45,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Positioned(
                    left: 7,
                    top: 7,
                    child:
                        Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.black54,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child:
                          const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock,
                            color:
                                Colors.white,
                            size: 14,
                          ),
                          SizedBox(
                            width: 3,
                          ),
                          Text(
                            'ቋሚ',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    right: 5,
                    top: 5,
                    child:
                        CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Colors.black54,
                      child:
                          IconButton(
                        padding:
                            EdgeInsets.zero,
                        icon:
                            const Icon(
                          Icons.lock,
                          color:
                              Colors.white,
                          size: 18,
                        ),
                        onPressed:
                            () {
                          _deletePhoto(
                            index,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _changeSalonPhoto() async {
    final source =
        await showModalBottomSheet<
            ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'የሳሎን ፎቶ',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.camera_alt,
                ),
                title: const Text(
                  'ካሜራ',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.photo,
                ),
                title: const Text(
                  'Gallery',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final XFile? picked =
          await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      final directory =
          await getApplicationDocumentsDirectory();

      final fileName =
          'salon_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final savedFile = File(
        '${directory.path}/$fileName',
      );

      await File(picked.path)
          .copy(savedFile.path);

      setState(() {
        _salonPhoto =
            savedFile.path;
      });

      await _saveProfile();

      _showMessage(
        'የሳሎን ፎቶ ተቀምጧል',
      );
    } catch (e) {
      _showMessage(
        'የሳሎን ፎቶ ማስቀመጥ አልተቻለም',
      );
    }
  }

  Future<void> _editProfileInfo() async {
    final nameController =
        TextEditingController(
      text: _salonName,
    );

    final phoneController =
        TextEditingController(
      text: _phoneNumber,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'የሳሎን መረጃ',
          ),
          content:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'የሳሎን ስም',
                  prefixIcon:
                      Icon(
                    Icons.business,
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              TextField(
                controller:
                    phoneController,
                keyboardType:
                    TextInputType.phone,
                decoration:
                    const InputDecoration(
                  labelText:
                      'ስልክ ቁጥር',
                  prefixIcon:
                      Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'ይቅር',
              ),
            ),
            ElevatedButton(
              onPressed:
                  () async {
                final name =
                    nameController
                        .text
                        .trim();

                setState(() {
                  _salonName =
                      name.isEmpty
                          ? 'የእኔ ሳሎን'
                          : name;

                  _phoneNumber =
                      phoneController
                          .text
                          .trim();
                });

                await _saveProfile();

                if (dialogContext
                    .mounted) {
                  Navigator.pop(
                    dialogContext,
                  );
                }

                _showMessage(
                  'የሳሎን መረጃ ተቀምጧል',
                );
              },
              child:
                  const Text(
                'አስቀምጥ',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfile() {
    return ListView(
      padding:
          const EdgeInsets.all(20),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 65,
                backgroundColor:
                    Colors.teal,
                backgroundImage:
                    _salonPhoto
                                .isNotEmpty &&
                            File(
                              _salonPhoto,
                            ).existsSync()
                        ? FileImage(
                            File(
                              _salonPhoto,
                            ),
                          )
                        : null,
                child:
                    _salonPhoto.isEmpty
                        ? const Icon(
                            Icons
                                .content_cut,
                            size: 60,
                            color:
                                Colors.white,
                          )
                        : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child:
                    CircleAvatar(
                  backgroundColor:
                      Colors.teal,
                  child:
                      IconButton(
                    icon:
                        const Icon(
                      Icons.camera_alt,
                      color:
                          Colors.white,
                    ),
                    onPressed:
                        _changeSalonPhoto,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Center(
          child: Text(
            _salonName,
            style:
                const TextStyle(
              fontSize: 25,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        if (_phoneNumber
            .isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 6,
            ),
            child: Center(
              child: Text(
                _phoneNumber,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  )
                      .colorScheme
                      .primary,
                  fontSize: 16,
                ),
              ),
            ),
          ),

        const SizedBox(
          height: 25,
        ),

        Card(
          child:
              ListTile(
            leading:
                const Icon(
              Icons.business,
            ),
            title:
                const Text(
              'የሳሎን መረጃ',
            ),
            subtitle:
                Text(
              'ስም: $_salonName\n'
              'ስልክ: ${_phoneNumber.isEmpty ? 'አልገባም' : _phoneNumber}',
            ),
            trailing:
                const Icon(
              Icons.edit,
            ),
            onTap:
                _editProfileInfo,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              SwitchListTile(
            secondary:
                const Icon(
              Icons.dark_mode,
            ),
            title:
                const Text(
              'Dark Mode',
            ),
            subtitle:
                const Text(
              'የአፑን ገጽታ ወደ ጨለማ ሁኔታ ቀይር',
            ),
            value:
                widget.darkMode,
            onChanged:
                widget
                    .onDarkModeChanged,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              const ListTile(
            leading:
                Icon(
              Icons
                  .admin_panel_settings,
            ),
            title:
                Text(
              'Admin',
            ),
            subtitle:
                Text(
              'የአፑ ባለቤት / አስተዳዳሪ',
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              const ListTile(
            leading:
                Icon(Icons.lock),
            title:
                Text(
              'የሂሳብ መዝገብ ደህንነት',
            ),
            subtitle:
                Text(
              'ገቢና ወጪ ከተመዘገቡ በኋላ Edit/Delete የለም።',
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              const ListTile(
            leading:
                Icon(Icons.info),
            title:
                Text(
              'ስለ Application',
            ),
            subtitle:
                Text(
              'Salon Income & Expense Manager',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final titles = [
      '🏠 $_salonName',
      '📋 የሂሳብ ታሪክ',
      '📊 ሪፖርት',
      '📷 ፎቶዎች',
      '👤 ፕሮፋይል',
    ];

    final pages = [
      _buildDashboard(),
      _buildHistory(),
      _buildReports(),
      _buildGallery(),
      _buildProfile(),
    ];

    return Scaffold(
      appBar:
          AppBar(
        title:
            Text(
          titles[
              _currentIndex],
        ),
        centerTitle:
            true,
      ),

      body:
          pages[_currentIndex],

      floatingActionButton:
          _currentIndex == 0 ||
                  _currentIndex == 1
              ? FloatingActionButton
                  .extended(
                  onPressed: () {
                    _showTransactionDialog();
                  },
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'አዲስ መዝግብ',
                  ),
                )
              : null,

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            _currentIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            _currentIndex =
                index;
          });
        },
        destinations:
            const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon:
                Icon(Icons.home),
            label: 'ዋና',
          ),
          NavigationDestination(
            icon: Icon(
              Icons
                  .receipt_long_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.receipt_long,
            ),
            label: 'ሂሳብ',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.analytics_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.analytics,
            ),
            label: 'ሪፖርት',
          ),
          NavigationDestination(
            icon: Icon(
              Icons
                  .photo_library_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.photo_library,
            ),
            label: 'ፎቶ',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(Icons.person),
            label: 'እኔ',
          ),
        ],
      ),
    );
  }
}
