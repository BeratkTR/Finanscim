import 'package:flutter/material.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/budget_bar_widget.dart';
import '../services/db_helper.dart';
import '../models/transaction.dart';
import '../widgets/add_transaction_widget.dart';
import '../widgets/main_drawer.dart';
import '../services/notification_service.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _summary = [];
  List<Transaction> _selectedDayItems = [];
  String? _selectedDateLabel;
  int _budgetRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _initNotificationService();
  }

  void _initNotificationService() async {
    final service = NotificationService();
    bool granted = await NotificationListenerService.isPermissionGranted();
    if (!granted) {
      if (!mounted) return;
      
      bool? request = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Otomatik Banka Takibi"),
          content: const Text("Yapı Kredi bildirimlerini otomatik olarak harcama olarak eklemek için bildirim erişimi izni vermeniz gerekmektedir."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: const Text("Daha Sonra")
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text("Ayarlara Git", style: TextStyle(fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );
      
      if (request == true) {
        await NotificationListenerService.requestPermission();
      }
    }
    
    service.onTransactionAdded.listen((_) {
      if (mounted) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yeni bir işlem otomatik olarak eklendi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    service.startListening();
  }

  void _refreshData() async {
    final data = await DbHelper.instance.getWeeklySummary();
    setState(() {
      _summary = data;
      _selectedDayItems = [];
      _selectedDateLabel = null;
      _budgetRefreshKey++;
    });
  }

  void _loadDailyDetails(String dateStr) async {
    final items = await DbHelper.instance.getTransactionsByDate(dateStr);
    setState(() {
      _selectedDayItems = items;
      _selectedDateLabel = dateStr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Finansım", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      drawer: const MainDrawer(currentRoute: 'home'),
      body: Column(
        children: [
          BudgetBarWidget(
            isWeekly: true,
            onSettingsChanged: _refreshData,
            refreshKey: _budgetRefreshKey,
          ),
          RepaintBoundary(
            child: WeeklyBarChart(summaryData: _summary, onBarTap: _loadDailyDetails),
          ),
          const Divider(height: 1),
          if (_selectedDateLabel != null)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _selectedDayItems.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(_selectedDayItems[i].color),
                    radius: 10,
                  ),
                  title: Text(_selectedDayItems[i].title),
                  subtitle: Text(_selectedDayItems[i].date.toIso8601String().split('T')[0]),
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
                              _refreshData();
                              _loadDailyDetails(_selectedDateLabel!);
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
                            _refreshData();
                            _loadDailyDetails(_selectedDateLabel!);
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
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Sütunlara tıklayarak detay gör", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          elevation: 0,
          builder: (ctx) => AddTransactionWidget(onAdded: _refreshData),
        ),
        label: const Text("Yeni Ekle"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}