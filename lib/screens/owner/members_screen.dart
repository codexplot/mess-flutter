import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/room.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    final ok = await context
                        .read<RoomProvider>()
                        .addMember(ctrl.text.trim());
                    setS(() => loading = false);
                    if (context.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      showSnack(
                        context,
                        ok
                            ? 'Member added!'
                            : (context.read<RoomProvider>().error ?? 'Failed'),
                        error: !ok,
                      );
                    }
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
    final owner = context.watch<AuthProvider>().user;

    // Build balance map from summary
    final balanceMap = <String, Map<String, dynamic>>{};
    if (summary != null) {
      for (final m in (summary['memberSummary'] as List? ?? [])) {
        balanceMap[m['_id'] ?? ''] = m;
      }
    }

    // Compute totals
    double totalOwed = 0;
    double toReceive = 0;
    for (final data in balanceMap.values) {
      final b = (data['balance'] ?? 0).toDouble();
      if (b > 0) totalOwed += b;
      if (b < 0) toReceive += b.abs();
    }

    final members = room?.members ?? [];
    final filtered = _search.isEmpty
        ? members
        : members
            .where((m) =>
                m.name.toLowerCase().contains(_search.toLowerCase()) ||
                m.email.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.navy,
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
                        'Members',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAddMember(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_outlined,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Total Owed / To Receive
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total Owed',
                          value:
                              '₹${totalOwed.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'To Receive',
                          value:
                              '₹${toReceive.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search bar
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF243560),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search members...',
                        hintStyle:
                            TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.white38, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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
              child: room == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => roomProv.fetchRoom(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              '${members.length + 1} Members',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
                            ),
                          ),
                          // Owner card always at top
                          if (owner != null)
                            _OwnerCard(owner: owner),
                          if (filtered.isEmpty && _search.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'No members found',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                            )
                          else
                            ...filtered.map((m) => _MemberCard(
                                  member: m,
                                  room: room,
                                  balanceData: balanceMap[m.id],
                                )),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Owner Card ───────────────────────────────────────────────────────────────

class _OwnerCard extends StatelessWidget {
  final dynamic owner;
  const _OwnerCard({required this.owner});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppTheme.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                owner.name.isNotEmpty ? owner.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      owner.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Owner',
                        style: TextStyle(
                            color: AppTheme.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  owner.email,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF243560),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Member Card ──────────────────────────────────────────────────────────────

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
      if (ok) context.read<RoomProvider>().fetchSummary();
      showSnack(
        context,
        ok
            ? 'Contribution added!'
            : (context.read<ExpenseProvider>().error ?? 'Failed'),
        error: !ok,
      );
    }
  }

  void _showMemberInfo(BuildContext context, dynamic m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.navy,
                  child: Text(
                    m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('MEMBER', style: TextStyle(color: AppTheme.teal, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _MemberInfoRow(icon: Icons.email_outlined, label: 'Email', value: m.email),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: (m.phone != null && m.phone!.isNotEmpty) ? m.phone! : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: (m.address != null && m.address!.isNotEmpty) ? m.address! : 'Not set',
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final roomProv = context.read<RoomProvider>();
    final m = widget.member;
    final room = widget.room;
    final isPaid = room.paidMembers.contains(m.id);
    final isFoodOptOut = room.foodOptOut.contains(m.id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ActionRow(
              icon: isPaid ? Icons.check_circle : Icons.check_circle_outline,
              label: isPaid ? 'Mark Unpaid' : 'Mark Paid',
              color: AppTheme.success,
              onTap: () {
                Navigator.pop(context);
                roomProv.togglePaid(m.id);
              },
            ),
            _ActionRow(
              icon: Icons.restaurant,
              label: isFoodOptOut ? 'Add Food' : 'No Food',
              color: isFoodOptOut ? AppTheme.success : AppTheme.error,
              onTap: () {
                Navigator.pop(context);
                roomProv.toggleFood(m.id);
              },
            ),
            _ActionRow(
              icon: Icons.add_circle_outline,
              label: 'Add Contribution',
              color: AppTheme.teal,
              onTap: () {
                Navigator.pop(context);
                setState(() => _showContrib = !_showContrib);
              },
            ),
            _ActionRow(
              icon: Icons.receipt_long_outlined,
              label: 'Bill Breakdown',
              color: AppTheme.navy,
              onTap: () {
                Navigator.pop(context);
                setState(() => _showBreakdown = !_showBreakdown);
              },
            ),
            _ActionRow(
              icon: Icons.person_remove_outlined,
              label: 'Remove Member',
              color: AppTheme.error,
              onTap: () async {
                Navigator.pop(context);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final room = widget.room;
    final isPaid = room.paidMembers.contains(m.id);
    final isFoodOptOut = room.foodOptOut.contains(m.id);
    final balance = widget.balanceData;
    final balanceAmt = (balance?['balance'] ?? 0).toDouble();
    final share = (balance?['perPersonShare'] ?? 0).toDouble();
    final contribution = (balance?['contribution'] ?? 0).toDouble();

    final bills = room.monthlyBills;
    final memberCount = room.members.length + 1;
    final foodOptOutCount = room.foodOptOut.length;
    final foodEaters = memberCount - foodOptOutCount;

    // Status text + color
    String statusLabel;
    Color statusColor;
    if (isPaid) {
      statusLabel = 'Paid';
      statusColor = AppTheme.success;
    } else if (balanceAmt > 0) {
      statusLabel = 'Owes ₹${balanceAmt.toStringAsFixed(0)}';
      statusColor = AppTheme.error;
    } else if (balanceAmt < 0) {
      statusLabel = 'Gets back ₹${balanceAmt.abs().toStringAsFixed(0)}';
      statusColor = AppTheme.success;
    } else {
      statusLabel = 'Settled';
      statusColor = AppTheme.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppTheme.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary),
                          ),
                          if (isFoodOptOut) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'No Food',
                                style: TextStyle(
                                    color: AppTheme.error, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Info icon
                GestureDetector(
                  onTap: () => _showMemberInfo(context, m),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.info_outline,
                        color: AppTheme.teal, size: 20),
                  ),
                ),
                // Three-dot menu
                GestureDetector(
                  onTap: () => _showActions(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.more_vert,
                        color: AppTheme.textSecondary, size: 20),
                  ),
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
                            prefixIcon:
                                Icon(Icons.currency_rupee, size: 16),
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
                      prefixIcon:
                          Icon(Icons.comment_outlined, size: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        const Text(' (tap to change)',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _showContrib = false),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bill Breakdown',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy)),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showBreakdown = false),
                        child: const Icon(Icons.close,
                            size: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (bills.rent > 0)
                    _BreakdownRow('Rent',
                        memberCount > 0 ? bills.rent / memberCount : 0,
                        '÷ $memberCount'),
                  if (bills.food > 0)
                    isFoodOptOut
                        ? const _BreakdownRow('Food', 0, 'opted out',
                            optOut: true)
                        : _BreakdownRow(
                            'Food',
                            foodEaters > 0
                                ? bills.food / foodEaters
                                : 0,
                            '÷ $foodEaters'),
                  if (bills.electricity > 0)
                    _BreakdownRow(
                        'Electricity',
                        memberCount > 0
                            ? bills.electricity / memberCount
                            : 0,
                        '÷ $memberCount'),
                  if (bills.water > 0)
                    _BreakdownRow(
                        'Water',
                        memberCount > 0
                            ? bills.water / memberCount
                            : 0,
                        '÷ $memberCount'),
                  const Divider(height: 14),
                  _SummaryRow('Their Share',
                      '₹${share.toStringAsFixed(2)}',
                      bold: true),
                  _SummaryRow(
                      'Contributions',
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

// ─── Action Row (bottom sheet) ────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Breakdown Row ────────────────────────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final String note;
  final bool optOut;

  const _BreakdownRow(this.label, this.amount, this.note,
      {this.optOut = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13))),
          Text(note,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 8),
          Text(
            optOut ? 'opted out' : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: optOut
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

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

class _MemberInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MemberInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
