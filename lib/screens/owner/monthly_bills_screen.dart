import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

// Supported currencies
const _kCurrencies = [
  {'code': 'INR', 'symbol': '₹',   'name': 'Indian Rupee'},
  {'code': 'USD', 'symbol': '\$',   'name': 'US Dollar'},
  {'code': 'EUR', 'symbol': '€',   'name': 'Euro'},
  {'code': 'GBP', 'symbol': '£',   'name': 'British Pound'},
  {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
  {'code': 'SAR', 'symbol': 'ر.س', 'name': 'Saudi Riyal'},
  {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'Qatari Riyal'},
  {'code': 'KWD', 'symbol': 'د.ك', 'name': 'Kuwaiti Dinar'},
  {'code': 'OMR', 'symbol': 'ر.ع.','name': 'Omani Rial'},
  {'code': 'MYR', 'symbol': 'RM',  'name': 'Malaysian Ringgit'},
  {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
  {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
  {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
  {'code': 'JPY', 'symbol': '¥',   'name': 'Japanese Yen'},
];

class MonthlyBillsScreen extends StatefulWidget {
  const MonthlyBillsScreen({super.key});

  @override
  State<MonthlyBillsScreen> createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rentCtrl = TextEditingController();
  final _foodCtrl = TextEditingController();
  final _electricityCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  String _billingMonth = '';
  bool _loading = false;

  // Currency state
  String _currencyCode   = 'INR';
  String _currencySymbol = '₹';
  String _currencyName   = 'Indian Rupee';

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomProvider>().room;
    if (room != null) {
      _rentCtrl.text        = room.monthlyBills.rent.toStringAsFixed(0);
      _foodCtrl.text        = room.monthlyBills.food.toStringAsFixed(0);
      _electricityCtrl.text = room.monthlyBills.electricity.toStringAsFixed(0);
      _waterCtrl.text       = room.monthlyBills.water.toStringAsFixed(0);
      _billingMonth         = room.billingMonth;
      _currencyCode         = room.currencyCode;
      _currencySymbol       = room.currencySymbol;
      _currencyName         = room.currencyName;
    }
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _foodCtrl.dispose();
    _electricityCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (ctx, scroll) => Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Currency',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _kCurrencies.length,
                itemBuilder: (_, i) {
                  final c = _kCurrencies[i];
                  final isSelected = c['code'] == _currencyCode;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.teal.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          c['symbol']!,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppTheme.teal
                                  : AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    title: Text(
                      c['name']!,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                    subtitle: Text('${c['code']} · ${c['symbol']}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.teal)
                        : null,
                    onTap: () {
                      setState(() {
                        _currencyCode   = c['code']!;
                        _currencySymbol = c['symbol']!;
                        _currencyName   = c['name']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await context.read<RoomProvider>().updateMonthlyBills(
          double.tryParse(_rentCtrl.text) ?? 0,
          double.tryParse(_foodCtrl.text) ?? 0,
          double.tryParse(_electricityCtrl.text) ?? 0,
          double.tryParse(_waterCtrl.text) ?? 0,
          _billingMonth,
          currencyCode:   _currencyCode,
          currencySymbol: _currencySymbol,
          currencyName:   _currencyName,
        );
    setState(() => _loading = false);
    if (mounted) {
      showSnack(context, ok ? 'Bills updated!' : (context.read<RoomProvider>().error ?? 'Failed'), error: !ok);
      if (ok) Navigator.pop(context);
    }
  }

  Widget _billField(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: '$_currencySymbol ',
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Bills')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Currency selector
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _currencySymbol,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.teal),
                      ),
                    ),
                  ),
                  title: const Text('Currency'),
                  subtitle: Text('$_currencyName ($_currencyCode)'),
                  trailing: const Icon(Icons.edit, color: AppTheme.teal),
                  onTap: _showCurrencyPicker,
                ),
              ),
              const SizedBox(height: 12),

              // Billing month
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: AppTheme.teal),
                  title: const Text('Billing Month'),
                  subtitle: Text(_billingMonth.isEmpty ? 'Not set' : _billingMonth),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      helpText: 'Select billing month',
                    );
                    if (picked != null) {
                      setState(() {
                        _billingMonth =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text('Fixed Monthly Bills',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                  'Set the monthly bills to be split among room members',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              _billField(_rentCtrl, 'Rent', Icons.house_outlined),
              const SizedBox(height: 14),
              _billField(_foodCtrl, 'Food', Icons.restaurant_outlined),
              const SizedBox(height: 14),
              _billField(_electricityCtrl, 'Electricity', Icons.bolt_outlined),
              const SizedBox(height: 14),
              _billField(_waterCtrl, 'Water', Icons.water_drop_outlined),
              const SizedBox(height: 32),
              LoadingButton(loading: _loading, onPressed: _save, label: 'Save Bills'),
            ],
          ),
        ),
      ),
    );
  }
}
