import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../widgets/main_drawer.dart';
import '../widgets/budget_bar_widget.dart';
import '../models/transaction.dart';
import '../widgets/add_transaction_widget.dart';

class MonthlyViewScreen extends StatefulWidget {
  const MonthlyViewScreen({super.key});

  @override
  State<MonthlyViewScreen> createState() => _MonthlyViewScreenState();
}

class _MonthlyViewScreenState extends State<MonthlyViewScreen> {
  Map<int, double> _monthlyData = {};
  DateTime _currentDate = DateTime.now();
  bool _isLoading = true;
  List<Transaction> _selectedDayItems = [];
  String? _selectedDateLabel;
  int _budgetRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await DbHelper.instance.getMonthlySummary(
      _currentDate.year, 
      _currentDate.month
    );
    setState(() {
      _monthlyData = data;
      _isLoading = false;
      _selectedDayItems = [];
      _selectedDateLabel = null;
      _budgetRefreshKey++;
    });
  }

  void _loadDailyDetails(int day) async {
    String monthStr = _currentDate.month < 10 ? '0${_currentDate.month}' : '${_currentDate.month}';
    String dayStr = day < 10 ? '0$day' : '$day';
    String dateStr = '${_currentDate.year}-$monthStr-$dayStr';
    
    final items = await DbHelper.instance.getTransactionsByDate(dateStr);
    setState(() {
      _selectedDayItems = items;
      _selectedDateLabel = dateStr;
    });
  }

  Color _getHeatmapColor(double amount) {
    if (amount == 0) return Colors.grey[100]!;
    if (amount < 200) return Colors.green[100]!;
    if (amount < 500) return Colors.green[300]!;
    if (amount < 1000) return Colors.orange[300]!;
    if (amount < 5000) return Colors.red[300]!;
    return Colors.red[800]!;
  }

  String _formatAmount(double amount) {
    if (amount < 1000) return amount.toInt().toString();
    return "${(amount / 1000).toStringAsFixed(1)}K";
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 (Pzt) - 7 (Paz)

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${_getMonthName(month)} $year", 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _currentDate = DateTime(year, month - 1));
              _fetchData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _currentDate = DateTime(year, month + 1));
              _fetchData();
            },
          ),
        ],
      ),
      drawer: const MainDrawer(currentRoute: 'monthly'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              BudgetBarWidget(
                isWeekly: false,
                year: _currentDate.year,
                month: _currentDate.month,
                onSettingsChanged: _fetchData,
                refreshKey: _budgetRefreshKey,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, 
                    mainAxisSpacing: 4, 
                    crossAxisSpacing: 4
                  ),
                  itemCount: lastDay + (firstWeekday - 1),
                  itemBuilder: (context, index) {
                    if (index < firstWeekday - 1) {
                      return const SizedBox();
                    }
                    
                    final day = index - (firstWeekday - 2);
                    final amount = _monthlyData[day] ?? 0.0;
                    final isSelected = _selectedDateLabel != null && 
                                     _selectedDateLabel!.endsWith(day < 10 ? '0$day' : '$day');

                    return GestureDetector(
                      onTap: () => _loadDailyDetails(day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo[50] : _getHeatmapColor(amount),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: Colors.indigo, width: 2) : null,
                          boxShadow: amount > 0 ? [
                            BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (amount > 2000 && !isSelected) ? Colors.white : Colors.black54
                              ),
                            ),
                            if (amount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _formatAmount(amount),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: (amount > 2000 && !isSelected) ? Colors.white : Colors.black
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              if (_selectedDateLabel != null)
                Expanded(
                  child: _selectedDayItems.isEmpty
                    ? const Center(child: Text("Bu güne ait harcama yok"))
                    : ListView.builder(
                        itemCount: _selectedDayItems.length,
                        itemBuilder: (ctx, i) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(_selectedDayItems[i].color),
                            radius: 10,
                          ),
                          title: Text(_selectedDayItems[i].title),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_selectedDayItems[i].amount.toInt()} ₺", 
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => AddTransactionWidget(
                                    transaction: _selectedDayItems[i],
                                    onAdded: () {
                                      _fetchData();
                                      _loadDailyDetails(int.parse(_selectedDateLabel!.split('-').last));
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Sil"),
                                      content: const Text("Bu harcamayı silmek istediğinize emin misiniz?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil", style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await DbHelper.instance.deleteTransaction(_selectedDayItems[i].id);
                                    _fetchData();
                                    _loadDailyDetails(int.parse(_selectedDateLabel!.split('-').last));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("Güne tıklayarak detay gör", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    return names[month - 1];
  }
}
