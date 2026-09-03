import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SalonManagerApp());
}

class SalonManagerApp extends StatelessWidget {
  const SalonManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salon Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const MainScreen(),
    );
  }
}

class TransactionItem {
  String id;
  String title;
  String staffName;
  double amount;
  bool isIncome;
  DateTime dateTime;

  TransactionItem({
    required this.id,
    required this.title,
    required this.staffName,
    required this.amount,
    required this.isIncome,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'staffName': staffName,
      'amount': amount,
      'isIncome': isIncome,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      staffName: map['staffName'] ?? 'ያልተጠቀሰ',
      amount: (map['amount'] ?? 0).toDouble(),
      isIncome: map['isIncome'] ?? true,
      dateTime: DateTime.parse(map['dateTime']),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<TransactionItem> _transactions = [];

  bool _showMoney = true;

  String _searchText = '';
  String _filterType = 'all';

  final List<String> _photos = [
    'https://picsum.photos/500/500?random=11',
    'https://picsum.photos/500/500?random=12',
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('transactions');

    if (savedData == null) return;

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      setState(() {
        _transactions.clear();
        _transactions.addAll(
          decodedData.map(
            (item) => TransactionItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          ),
        );
      });
    } catch (e) {
      debugPrint('መረጃ ሲጫን ስህተት: $e');
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final data = _transactions
        .map((item) => item.toMap())
        .toList();

    await prefs.setString(
      'transactions',
      jsonEncode(data),
    );
  }

  double get totalIncome {
    return _transactions
        .where((item) => item.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalExpense {
    return _transactions
        .where((item) => !item.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalProfit {
    return totalIncome - totalExpense;
  }

  List<TransactionItem> get filteredTransactions {
    return _transactions.where((item) {
      final matchesSearch =
          item.title.toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
          item.staffName.toLowerCase().contains(
                _searchText.toLowerCase(),
              );

      final matchesType =
          _filterType == 'all' ||
          (_filterType == 'income' && item.isIncome) ||
          (_filterType == 'expense' && !item.isIncome);

      return matchesSearch && matchesType;
    }).toList();
  }

  void _showTransactionDialog({
    TransactionItem? item,
    bool? defaultIsIncome,
  }) {
    final titleController = TextEditingController(
      text: item?.title ?? '',
    );

    final staffController = TextEditingController(
      text: item?.staffName ?? '',
    );

    final amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
    );

    bool isIncome = item?.isIncome ?? defaultIsIncome ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 25,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 25,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item == null
                          ? '➕ አዲስ ሂሳብ መዝግብ'
                          : '✏️ ሂሳብ አስተካክል',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'የእቃ / አገልግሎት ስም',
                        prefixIcon: Icon(Icons.content_cut),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: staffController,
                      decoration: const InputDecoration(
                        labelText: 'የሰራተኛ / የሰው ስም',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'የገንዘብ መጠን (ብር)',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('🟢 ገቢ'),
                            value: true,
                            groupValue: isIncome,
                            onChanged: (value) {
                              setModalState(() {
                                isIncome = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('🔴 ወጪ'),
                            value: false,
                            groupValue: isIncome,
                            onChanged: (value) {
                              setModalState(() {
                                isIncome = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(
                          item == null ? 'መዝግብ' : 'አስቀምጥ',
                        ),
                        onPressed: () async {
                          final title =
                              titleController.text.trim();
                          final staff =
                              staffController.text.trim();
                          final amount =
                              double.tryParse(
                            amountController.text,
                          );

                          if (title.isEmpty ||
                              amount == null ||
                              amount <= 0) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'እባክዎ ትክክለኛ መረጃ ያስገቡ',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            if (item == null) {
                              _transactions.add(
                                TransactionItem(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  title: title,
                                  staffName: staff.isEmpty
                                      ? 'ያልተጠቀሰ'
                                      : staff,
                                  amount: amount,
                                  isIncome: isIncome,
                                  dateTime: DateTime.now(),
                                ),
                              );
                            } else {
                              item.title = title;
                              item.staffName = staff.isEmpty
                                  ? 'ያልተጠቀሰ'
                                  : staff;
                              item.amount = amount;
                              item.isIncome = isIncome;
                            }
                          });

                          await _saveTransactions();

                          if (bottomSheetContext.mounted) {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          }
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

  void _deleteTransaction(TransactionItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ማረጋገጫ'),
          content: Text(
            '"${item.title}" ማጥፋት ይፈልጋሉ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ይቅር'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _transactions.remove(item);
                });

                await _saveTransactions();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('አጥፋ'),
            ),
          ],
        );
      },
    );
  }  Widget _moneyText(
    double amount, {
    required Color color,
  }) {
    return Text(
      _showMoney
          ? '${amount.toStringAsFixed(2)} ብር'
          : '******',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(
          const Duration(milliseconds: 500),
        );
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 5,
            color: Colors.teal.shade800,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'የሳሎን ገንዘብ አጠቃላይ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showMoney = !_showMoney;
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
                  const Divider(color: Colors.white54),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🟢 ጠቅላላ ገቢ',
                        style: TextStyle(color: Colors.white),
                      ),
                      _moneyText(
                        totalIncome,
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔴 ጠቅላላ ወጪ',
                        style: TextStyle(color: Colors.white),
                      ),
                      _moneyText(
                        totalExpense,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Colors.white54),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💰 የተጣራ ትርፍ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _moneyText(
                        totalProfit,
                        color: totalProfit >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ፈጣን አገልግሎቶች',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle),
                  label: const Text('ገቢ ጨምር'),
                  onPressed: () {
                    _showTransactionDialog(
                      defaultIsIncome: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.remove_circle),
                  label: const Text('ወጪ ጨምር'),
                  onPressed: () {
                    _showTransactionDialog(
                      defaultIsIncome: false,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'የቅርብ ጊዜ መዝገቦች',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 60,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'እስካሁን የተመዘገበ ሂሳብ የለም',
                    ),
                  ],
                ),
              ),
            )
          else
            ..._transactions.reversed
                .take(5)
                .map((item) => _transactionCard(item)),
        ],
      ),
    );
  }

  Widget _transactionCard(TransactionItem item) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              item.isIncome ? Colors.green : Colors.red,
          child: Icon(
            item.isIncome
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(item.title),
        subtitle: Text(
          '${item.staffName}\n'
          '${item.dateTime.day}/${item.dateTime.month}/${item.dateTime.year}',
        ),
        isThreeLine: true,
        trailing: SizedBox(
          width: 130,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  '${item.isIncome ? '+' : '-'}'
                  '${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: item.isIncome
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showTransactionDialog(item: item);
                  } else if (value == 'delete') {
                    _deleteTransaction(item);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('✏️ አስተካክል'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('🗑️ አጥፋ'),
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
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'ሂሳብ ፈልግ',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _filterType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'አጣራ',
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('ሁሉንም'),
              ),
              DropdownMenuItem(
                value: 'income',
                child: Text('🟢 ገቢ'),
              ),
              DropdownMenuItem(
                value: 'expense',
                child: Text('🔴 ወጪ'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _filterType = value!;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filteredTransactions.isEmpty
              ? const Center(
                  child: Text(
                    'ምንም መረጃ አልተገኘም',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount:
                      filteredTransactions.length,
                  itemBuilder: (context, index) {
                    return _transactionCard(
                      filteredTransactions[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGallery() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'የተሰሩ ስራዎች ፎቶዎች',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'እዚህ የሳሎን ስራዎችን ፎቶ ማሳየት ይቻላል።',
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: _photos.length + 1,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            if (index == _photos.length) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _photos.add(
                      'https://picsum.photos/500/500?random='
                      '${DateTime.now().millisecondsSinceEpoch}',
                    );
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.teal,
                      width: 2,
                    ),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: const Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 45,
                        color: Colors.teal,
                      ),
                      SizedBox(height: 10),
                      Text('ፎቶ ጨምር'),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(15),
                  child: Image.network(
                    _photos[index],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _photos.removeAt(index);
                        });
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

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.teal,
            child: Icon(
              Icons.content_cut,
              size: 55,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            'Salon Manager',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        const ListTile(
          leading: Icon(Icons.business),
          title: Text('የሳሎን ስም'),
          subtitle: Text('የእኔ ሳሎን'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.phone),
          title: Text('ስልክ ቁጥር'),
          subtitle: Text('በኋላ ማስገባት ይቻላል'),
        ),
        const Divider(),
        const ListTile(
          leading:
              Icon(Icons.admin_panel_settings),
          title: Text('Admin'),
          subtitle: Text(
            'የአፕሊኬሽኑ ባለቤት / አስተዳዳሪ',
          ),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info),
          title: Text('ስለ Application'),
          subtitle: Text(
            'Salon Income & Expense Manager',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      '🏠 Salon Manager',
      '📋 የሂሳብ ታሪክ',
      '📷 ፎቶዎች',
      '👤 ፕሮፋይል',
    ];

    final pages = [
      _buildDashboard(),
      _buildHistory(),
      _buildGallery(),
      _buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        centerTitle: true,
      ),
      body: pages[_currentIndex],
      floatingActionButton:
          _currentIndex == 0 || _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    _showTransactionDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('አዲስ መዝግብ'),
                )
              : null,
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
            label: 'ዋና',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long),
            label: 'ሂሳብ',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.photo_library_outlined),
            selectedIcon:
                Icon(Icons.photo_library),
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
