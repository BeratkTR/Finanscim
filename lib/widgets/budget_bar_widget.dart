import 'package:flutter/material.dart';
import '../services/db_helper.dart';

class BudgetBarWidget extends StatefulWidget {
  final bool isWeekly;
  final VoidCallback? onSettingsChanged;
  final int? year;
  final int? month;
  final int refreshKey;

  const BudgetBarWidget({
    super.key,
    required this.isWeekly,
    this.onSettingsChanged,
    this.year,
    this.month,
    this.refreshKey = 0,
  });

  @override
  State<BudgetBarWidget> createState() => _BudgetBarWidgetState();
}

class _BudgetBarWidgetState extends State<BudgetBarWidget> {
  double _monthlyBudget = 0;
  int _warningPercentage = 80;
  double _currentSpending = 0;
  double _weeklyBudget = 0;
  int _daysInWeek = 7;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(BudgetBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || 
        oldWidget.month != widget.month ||
        oldWidget.refreshKey != widget.refreshKey) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final settings = await DbHelper.instance.getBudgetSettings();
    _monthlyBudget = settings['monthly_budget'];
    _warningPercentage = settings['warning_percentage'];

    if (widget.isWeekly) {
      _currentSpending = await DbHelper.instance.getWeeklyTotal();
      _weeklyBudget = DbHelper.instance.calculateWeeklyBudget(_monthlyBudget);
      _daysInWeek = DbHelper.instance.getDaysInCurrentWeek();
    } else {
      final year = widget.year ?? DateTime.now().year;
      final month = widget.month ?? DateTime.now().month;
      _currentSpending = await DbHelper.instance.getMonthlyTotal(year, month);
    }

    setState(() => _isLoading = false);
  }

  double get _effectiveBudget {
    if (widget.isWeekly) {
      return _weeklyBudget;
    }
    return _monthlyBudget;
  }

  double get _usagePercentage {
    if (_effectiveBudget <= 0) return 0;
    return (_currentSpending / _effectiveBudget * 100).clamp(0, 100);
  }

  bool get _isWarning {
    return _usagePercentage >= _warningPercentage;
  }

  bool get _isExceeded {
    return _currentSpending > _effectiveBudget && _effectiveBudget > 0;
  }

  Color get _barColor {
    if (_isExceeded) return Colors.red[700]!;
    if (_isWarning) return Colors.red;
    return Colors.blue;
  }

  void _showSettingsModal() {
    final budgetController = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toInt().toString() : '',
    );
    final percentageController = TextEditingController(
      text: _warningPercentage.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bütçe Ayarları',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Aylık Bütçe (₺)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Örn: 10000',
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Uyarı Yüzdesi (%)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Örn: 80',
                  prefixIcon: const Icon(Icons.warning_amber_rounded),
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Harcama bu orana ulaştığında bar maviden kırmızıya döner',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final budget = double.tryParse(budgetController.text) ?? 0;
                    final percentage = int.tryParse(percentageController.text) ?? 80;
                    
                    await DbHelper.instance.updateBudgetSettings(
                      budget,
                      percentage.clamp(1, 100),
                    );
                    
                    Navigator.pop(ctx);
                    _loadData();
                    widget.onSettingsChanged?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_monthlyBudget <= 0) {
      return GestureDetector(
        onTap: _showSettingsModal,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Bütçe belirlemek için tıklayın',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final budgetLabel = widget.isWeekly ? 'Haftalık ($_daysInWeek gün)' : 'Aylık';
    final displayPercentage = _isExceeded 
        ? (_currentSpending / _effectiveBudget * 100).toInt()
        : _usagePercentage.toInt();

    return GestureDetector(
      onTap: _showSettingsModal,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isExceeded ? Icons.warning : Icons.account_balance_wallet,
                      size: 18,
                      color: _barColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$budgetLabel Bütçe',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${_currentSpending.toInt()}₺',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _barColor,
                      ),
                    ),
                    Text(
                      ' / ${_effectiveBudget.toInt()}₺',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (_usagePercentage / 100).clamp(0, 1),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: _barColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _barColor.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isExceeded 
                      ? 'Bütçe aşıldı!' 
                      : _isWarning 
                          ? 'Dikkat! Uyarı sınırına ulaşıldı'
                          : 'Bütçe durumu iyi',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isExceeded || _isWarning ? _barColor : Colors.grey[600],
                    fontWeight: _isExceeded || _isWarning ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  '%$displayPercentage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _barColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
