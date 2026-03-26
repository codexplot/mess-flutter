import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/room.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  void _showAddMember(BuildContext context) {
    final ctrl = TextEditingController();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Member',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Member email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                LoadingButton(
                  loading: loading,
                  onPressed: () async {
                    setS(() => loading = true);
                    final ok =
                        await context.read<RoomProvider>().addMember(ctrl.text.trim());
                    setS(() => loading = false);
                    Navigator.pop(ctx);
                    showSnack(
                      context,
                      ok ? 'Member added!' : (context.read<RoomProvider>().error ?? 'Failed'),
                      error: !ok,
                    );
                  },
                  label: 'Add Member',
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.watch<RoomProvider>();
    final room = roomProv.room;
    final summary = roomProv.summary;

    // Build a map of member balances from summary
    final balanceMap = <String, Map<String, dynamic>>{};
    if (summary != null) {
      for (final m in (summary['memberSummary'] as List? ?? [])) {
        balanceMap[m['_id'] ?? ''] = m;
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMember(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
      ),
      body: room == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => roomProv.fetchRoom(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room code card
                    Card(
                      color: AppTheme.navy,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room, color: Colors.white70),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Room Code',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text(room.roomCode,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3)),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white70),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: room.roomCode));
                                showSnack(context, 'Room code copied!');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: 'Members (${room.members.length})'),
                    const SizedBox(height: 12),
                    if (room.members.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                              'No members yet.\nShare the room code to invite.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      )
                    else
                      ...room.members.map((m) => _MemberCard(
                            member: m,
                            room: room,
                            balanceData: balanceMap[m.id],
                          )),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MemberCard extends StatefulWidget {
  final RoomMember member;
  final Room room;
  final Map<String, dynamic>? balanceData;

  const _MemberCard({
    required this.member,
    required this.room,
    this.balanceData,
  });

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _showContrib = false;
  bool _showBreakdown = false;

  final _amountCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _savingContrib = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _shopCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveContribution() async {
    final amt = double.tryParse(_amountCtrl.text);
    if (amt == null || _shopCtrl.text.isEmpty) {
      showSnack(context, 'Fill all required fields', error: true);
      return;
    }
    setState(() => _savingContrib = true);
    final ok = await context.read<ExpenseProvider>().ownerAddExpense(
          memberId: widget.member.id,
          amount: amt,
          shopName: _shopCtrl.text.trim(),
          date: _date,
          comments: _noteCtrl.text.trim(),
        );
    setState(() {
      _savingContrib = false;
      if (ok) {
        _showContrib = false;
        _amountCtrl.clear();
        _shopCtrl.clear();
        _noteCtrl.clear();
      }
    });
    if (mounted) {
      showSnack(
        context,
        ok ? 'Contribution added!' : (context.read<ExpenseProvider>().error ?? 'Failed'),
        error: !ok,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.read<RoomProvider>();
    final m = widget.member;
    final room = widget.room;
    final isPaid = room.paidMembers.contains(m.id);
    final isFoodOptOut = room.foodOptOut.contains(m.id);
    final balance = widget.balanceData;
    final balanceAmt = (balance?['balance'] ?? 0).toDouble();
    final share = (balance?['perPersonShare'] ?? 0).toDouble();
    final contribution = (balance?['contribution'] ?? 0).toDouble();

    final bills = room.monthlyBills;
    final memberCount = room.members.length;
    final foodOptOutCount = room.foodOptOut.length;
    final foodEaters = memberCount - foodOptOutCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.teal.withOpacity(0.15),
                  child: Text(m.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.teal, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(m.email,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                // Status badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isFoodOptOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('No Food',
                            style: TextStyle(color: AppTheme.error, fontSize: 10)),
                      ),
                    isPaid
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('PAID',
                                style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          )
                        : balanceAmt > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Pay ₹${balanceAmt.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: AppTheme.error,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              )
                            : balanceAmt < 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Get ₹${balanceAmt.abs().toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: AppTheme.teal,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.textSecondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Settled',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ActionChip(
                  label: isPaid ? 'Paid ✓' : 'Mark Paid',
                  icon: isPaid ? Icons.check_circle : Icons.check_circle_outline,
                  color: isPaid ? AppTheme.success : AppTheme.textSecondary,
                  onTap: () => roomProv.togglePaid(m.id),
                ),
                _ActionChip(
                  label: isFoodOptOut ? 'Add Food' : 'No Food',
                  icon: Icons.restaurant,
                  color: isFoodOptOut ? AppTheme.success : AppTheme.error,
                  onTap: () => roomProv.toggleFood(m.id),
                ),
                _ActionChip(
                  label: 'Add Contribution',
                  icon: Icons.add_circle_outline,
                  color: AppTheme.teal,
                  onTap: () => setState(() => _showContrib = !_showContrib),
                ),
                _ActionChip(
                  label: 'Bill Breakdown',
                  icon: Icons.expand_more,
                  color: AppTheme.navy,
                  onTap: () => setState(() => _showBreakdown = !_showBreakdown),
                ),
                _ActionChip(
                  label: 'Remove',
                  icon: Icons.person_remove_outlined,
                  color: AppTheme.error,
                  onTap: () async {
                    final ok = await roomProv.removeMember(m.id);
                    if (context.mounted) {
                      showSnack(
                        context,
                        ok ? 'Member removed' : (roomProv.error ?? 'Failed'),
                        error: !ok,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Add contribution inline form
          if (_showContrib)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.teal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Contribution',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: AppTheme.teal)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            isDense: true,
                            prefixIcon: Icon(Icons.currency_rupee, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _shopCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Shop / Description',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      isDense: true,
                      prefixIcon: Icon(Icons.comment_outlined, size: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date selector
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${_date.day}/${_date.month}/${_date.year}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        const Text('(tap to change)',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showContrib = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LoadingButton(
                          loading: _savingContrib,
                          onPressed: _saveContribution,
                          label: 'Save',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Bill breakdown
          if (_showBreakdown)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.navy.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.navy.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Breakdown',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: AppTheme.navy)),
                  const SizedBox(height: 10),
                  if (bills.rent > 0)
                    _BreakdownRow('Rent',
                        memberCount > 0 ? bills.rent / memberCount : 0,
                        '÷ $memberCount'),
                  if (bills.food > 0)
                    isFoodOptOut
                        ? const _BreakdownRow('Food', 0, 'opted out', optOut: true)
                        : _BreakdownRow(
                            'Food',
                            foodEaters > 0 ? bills.food / foodEaters : 0,
                            '÷ $foodEaters'),
                  if (bills.electricity > 0)
                    _BreakdownRow('Electricity',
                        memberCount > 0 ? bills.electricity / memberCount : 0,
                        '÷ $memberCount'),
                  if (bills.water > 0)
                    _BreakdownRow('Water',
                        memberCount > 0 ? bills.water / memberCount : 0,
                        '÷ $memberCount'),
                  const Divider(height: 14),
                  _SummaryRow('Their Share', '₹${share.toStringAsFixed(2)}',
                      bold: true),
                  _SummaryRow('Contributions',
                      '- ₹${contribution.toStringAsFixed(2)}',
                      color: AppTheme.success),
                  _SummaryRow(
                    isPaid ? 'Status' : 'Balance',
                    isPaid
                        ? 'PAID'
                        : balanceAmt > 0
                            ? 'Owes ₹${balanceAmt.toStringAsFixed(2)}'
                            : balanceAmt < 0
                                ? 'Gets ₹${balanceAmt.abs().toStringAsFixed(2)}'
                                : 'Settled',
                    bold: true,
                    color: isPaid
                        ? AppTheme.success
                        : balanceAmt > 0
                            ? AppTheme.error
                            : balanceAmt < 0
                                ? AppTheme.teal
                                : AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final String note;
  final bool optOut;

  const _BreakdownRow(this.label, this.amount, this.note, {this.optOut = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text(note,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 8),
          Text(
            optOut ? 'opted out' : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: optOut ? AppTheme.textSecondary : AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
