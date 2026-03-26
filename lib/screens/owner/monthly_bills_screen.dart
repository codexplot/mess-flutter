import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

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

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomProvider>().room;
    if (room != null) {
      _rentCtrl.text = room.monthlyBills.rent.toStringAsFixed(0);
      _foodCtrl.text = room.monthlyBills.food.toStringAsFixed(0);
      _electricityCtrl.text = room.monthlyBills.electricity.toStringAsFixed(0);
      _waterCtrl.text = room.monthlyBills.water.toStringAsFixed(0);
      _billingMonth = room.billingMonth;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await context.read<RoomProvider>().updateMonthlyBills(
          double.tryParse(_rentCtrl.text) ?? 0,
          double.tryParse(_foodCtrl.text) ?? 0,
          double.tryParse(_electricityCtrl.text) ?? 0,
          double.tryParse(_waterCtrl.text) ?? 0,
          _billingMonth,
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
        prefixText: '₹ ',
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
