import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/room_provider.dart';
import '../../models/expense.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'submit_expense_screen.dart';

class MemberExpensesScreen extends StatefulWidget {
  const MemberExpensesScreen({super.key});

  @override
  State<MemberExpensesScreen> createState() => _MemberExpensesScreenState();
}

class _MemberExpensesScreenState extends State<MemberExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ExpenseProvider>().fetchExpenses(),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expProv = context.watch<ExpenseProvider>();
    final expenses = expProv.expenses;

    final approved = expenses.where((e) => e.isApproved).toList();
    final pending = expenses.where((e) => e.isPending).toList();
    final rejected = expenses.where((e) => e.isRejected).toList();
    final approvedTotal = approved.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitExpenseScreen()),
        ).then((_) => expProv.fetchExpenses()),
        icon: const Icon(Icons.add),
        label: const Text('New'),
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
      ),
      body: expProv.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => expProv.fetchExpenses(),
              child: Column(
                children: [
                  // Stat cards
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.0,
                      children: [
                        _StatCard(
                          label: 'Approved',
                          value: '${approved.length}',
                          sub: '${context.read<RoomProvider>().currencySymbol}${approvedTotal.toStringAsFixed(0)}',
                          color: AppTheme.success,
                          icon: Icons.check_circle_outline,
                        ),
                        _StatCard(
                          label: 'Pending',
                          value: '${pending.length}',
                          sub: 'Awaiting review',
                          color: AppTheme.warning,
                          icon: Icons.pending_outlined,
                        ),
                        _StatCard(
                          label: 'Rejected',
                          value: '${rejected.length}',
                          sub: 'Declined',
                          color: AppTheme.error,
                          icon: Icons.cancel_outlined,
                        ),
                        _StatCard(
                          label: 'Total',
                          value: '${expenses.length}',
                          sub: 'All expenses',
                          color: AppTheme.navy,
                          icon: Icons.receipt_long,
                        ),
                      ],
                    ),
                  ),

                  // Filter tabs
                  TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: [
                      Tab(text: 'All  ${expenses.length}'),
                      Tab(text: 'Pending  ${pending.length}'),
                      Tab(text: 'Approved  ${approved.length}'),
                      Tab(text: 'Rejected  ${rejected.length}'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _ExpenseList(expenses: expenses),
                        _ExpenseList(expenses: pending),
                        _ExpenseList(expenses: approved),
                        _ExpenseList(expenses: rejected),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                Text(sub,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final List<Expense> expenses;

  const _ExpenseList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No expenses here',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (_, i) => _ExpenseTile(expense: expenses[i]),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;

  const _ExpenseTile({required this.expense});

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
                Text('${context.read<RoomProvider>().currencySymbol}${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy)),
                const Spacer(),
                Text(fmt.format(expense.date),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            if (expense.comments != null && expense.comments!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(expense.comments!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ],
            if (expense.isRejected && expense.rejectionNote != null) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(expense.rejectionNote!,
                        style: const TextStyle(
                            color: AppTheme.error, fontSize: 12)),
                  ),
                ],
              ),
            ],
            // Bill image
            if (expense.billImage != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _viewImage(context, expense.billImage!.url),
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 14, color: AppTheme.teal),
                    const SizedBox(width: 6),
                    const Text('View Bill',
                        style: TextStyle(
                            color: AppTheme.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            if (expense.isPending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await context
                        .read<ExpenseProvider>()
                        .deleteExpense(expense.id);
                    if (context.mounted) {
                      showSnack(context, ok ? 'Deleted' : 'Failed', error: !ok);
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.error),
                  label: const Text('Delete',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
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
}
