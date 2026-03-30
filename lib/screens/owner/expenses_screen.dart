import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/room_provider.dart';
import '../../models/expense.dart';
import '../../theme.dart';
import '../../widgets/common.dart';


class ExpensesScreen extends StatefulWidget {
  final bool openAdd;
  const ExpensesScreen({super.key, this.openAdd = false});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openAdd) _showAddExpense();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddExpense() {
    final room = context.read<RoomProvider>().room;
    if (room == null) return;
    final memberCtrl = ValueNotifier<String?>(
        room.members.isNotEmpty ? room.members.first.id : null);
    final amountCtrl = TextEditingController();
    final shopCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add Expense for Member',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: memberCtrl.value,
                    decoration: const InputDecoration(labelText: 'Member'),
                    items: room.members
                        .map((m) => DropdownMenuItem(
                            value: m.id, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) => memberCtrl.value = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: shopCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Shop / Description',
                        prefixIcon: Icon(Icons.store_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Comments (optional)',
                        prefixIcon: Icon(Icons.comment_outlined)),
                  ),
                  const SizedBox(height: 20),
                  LoadingButton(
                    loading: loading,
                    onPressed: () async {
                      final amt = double.tryParse(amountCtrl.text);
                      if (amt == null || shopCtrl.text.isEmpty) {
                        showSnack(context, 'Fill all required fields', error: true);
                        return;
                      }
                      setS(() => loading = true);
                      final ok =
                          await context.read<ExpenseProvider>().ownerAddExpense(
                                memberId: memberCtrl.value!,
                                amount: amt,
                                shopName: shopCtrl.text.trim(),
                                date: selectedDate,
                                comments: commentCtrl.text.trim(),
                              );
                      setS(() => loading = false);
                      if (ok) {
                        context.read<RoomProvider>().fetchSummary();
                      }
                      Navigator.pop(ctx);
                      showSnack(
                        context,
                        ok ? 'Expense added!' : (context.read<ExpenseProvider>().error ?? 'Failed'),
                        error: !ok,
                      );
                    },
                    label: 'Add Expense',
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add for Member'),
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'All'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ExpenseList(filter: 'pending'),
                _ExpenseList(filter: 'approved'),
                _ExpenseList(filter: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final String? filter;

  const _ExpenseList({this.filter});

  @override
  Widget build(BuildContext context) {
    final expProv = context.watch<ExpenseProvider>();
    List<Expense> list;
    if (filter == 'pending') {
      list = expProv.pendingExpenses;
    } else if (filter == 'approved') {
      list = expProv.approvedExpenses;
    } else {
      list = expProv.expenses;
    }

    if (expProv.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No ${filter ?? ''} expenses',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ExpenseProvider>().fetchExpenses(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => _ExpenseTile(expense: list[i]),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;

  const _ExpenseTile({required this.expense});

  void _viewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approve(BuildContext context) async {
    final ok =
        await context.read<ExpenseProvider>().updateStatus(expense.id, 'approved');
    if (context.mounted) {
      if (ok) context.read<RoomProvider>().fetchSummary();
      showSnack(context, ok ? 'Approved!' : 'Failed', error: !ok);
    }
  }

  void _reject(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ExpenseProvider>()
                  .updateStatus(expense.id, 'rejected', rejectionNote: ctrl.text);
              if (context.mounted) {
                if (ok) context.read<RoomProvider>().fetchSummary();
                showSnack(context, ok ? 'Rejected' : 'Failed', error: !ok);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(expense.shopName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                StatusBadge(status: expense.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(expense.memberName,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                Text(fmt.format(expense.date),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy)),
                if (expense.isPending)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _reject(context),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _approve(context),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
              ],
            ),
            if (expense.isRejected && expense.rejectionNote != null) ...[
              const Divider(),
              Text('Reason: ${expense.rejectionNote}',
                  style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
            if (expense.billImage != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _viewImage(context, expense.billImage!.url),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 14, color: AppTheme.teal),
                    const SizedBox(width: 6),
                    const Text('View Bill Image',
                        style: TextStyle(
                            color: AppTheme.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
