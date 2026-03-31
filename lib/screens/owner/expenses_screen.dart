import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/room_provider.dart';
import '../../models/expense.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ExpensesScreen extends StatefulWidget {
  final VoidCallback? onGoBack;
  const ExpensesScreen({super.key, this.onGoBack});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _filter; // null = All, 'pending', 'approved'
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenses();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
                        .map((m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.name)))
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
                        labelText: 'Category / Comments (optional)',
                        prefixIcon: Icon(Icons.label_outline)),
                  ),
                  const SizedBox(height: 20),
                  LoadingButton(
                    loading: loading,
                    onPressed: () async {
                      final amt = double.tryParse(amountCtrl.text);
                      if (amt == null || shopCtrl.text.isEmpty) {
                        showSnack(context, 'Fill all required fields',
                            error: true);
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
                      if (ok && context.mounted) {
                        context.read<RoomProvider>().fetchSummary();
                      }
                      if (context.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showSnack(
                          context,
                          ok
                              ? 'Expense added!'
                              : (context.read<ExpenseProvider>().error ??
                                  'Failed'),
                          error: !ok,
                        );
                      }
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

  List<Expense> _getList(ExpenseProvider prov) {
    List<Expense> list;
    if (_filter == 'pending') {
      list = prov.pendingExpenses;
    } else if (_filter == 'approved') {
      list = prov.approvedExpenses;
    } else {
      list = prov.expenses;
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((e) =>
              e.shopName.toLowerCase().contains(q) ||
              e.memberName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final expProv = context.watch<ExpenseProvider>();
    final list = _getList(expProv);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpense,
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Dark Header ──────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Title row
                  Row(
                    children: [
                      const Text(
                        'All Expenses',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF243560),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search expenses...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.white38, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter chips row
                  Row(
                    children: [
                      _FilterChip(
                          label: 'All',
                          isActive: _filter == null,
                          onTap: () => setState(() => _filter = null)),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: 'Pending',
                          isActive: _filter == 'pending',
                          onTap: () =>
                              setState(() => _filter = 'pending')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: 'Approved',
                          isActive: _filter == 'approved',
                          onTap: () =>
                              setState(() => _filter = 'approved')),
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF243560),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── White Body ───────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: expProv.loading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? _EmptyExpenses(filter: _filter, search: _search)
                      : RefreshIndicator(
                          onRefresh: () =>
                              context.read<ExpenseProvider>().fetchExpenses(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _ExpenseTile(expense: list[i]),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.teal : const Color(0xFF243560),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Expense Tile ─────────────────────────────────────────────────────────────

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
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 20),
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<ExpenseProvider>()
                  .updateStatus(expense.id, 'rejected',
                      rejectionNote: ctrl.text);
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
    final dateFmt = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Amount
          Row(
            children: [
              Expanded(
                child: Text(
                  expense.shopName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${expense.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  Text(
                    dateFmt.format(expense.date),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Paid by
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Paid by ${expense.memberName}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (expense.comments != null &&
                  expense.comments!.isNotEmpty) ...[
                const Text(' · ',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  expense.comments!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          // Status badge + approve/reject
          Row(
            children: [
              _StatusBadge(status: expense.status),
              const Spacer(),
              if (expense.isPending) ...[
                TextButton(
                  onPressed: () => _reject(context),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Reject', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approve(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13)),
                  child: const Text('Approve'),
                ),
              ],
            ],
          ),
          if (expense.isRejected && expense.rejectionNote != null) ...[
            const SizedBox(height: 6),
            Text('Reason: ${expense.rejectionNote}',
                style: const TextStyle(
                    color: AppTheme.error, fontSize: 12)),
          ],
          if (expense.billImage != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _viewImage(context, expense.billImage!.url),
              child: const Row(
                children: [
                  Icon(Icons.image_outlined, size: 14, color: AppTheme.teal),
                  SizedBox(width: 6),
                  Text('View Bill Image',
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
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (status == 'approved') {
      color = AppTheme.success;
    } else if (status == 'rejected') {
      color = AppTheme.error;
    } else {
      color = AppTheme.warning;
    }
    final label = status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyExpenses extends StatelessWidget {
  final String? filter;
  final String search;
  const _EmptyExpenses({this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    final msg = search.isNotEmpty
        ? 'No results for "$search"'
        : 'No ${filter ?? ''} expenses';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

