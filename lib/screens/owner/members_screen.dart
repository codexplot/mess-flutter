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
  // filter: 'all' | 'unpaid' | 'paid'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().fetchSummary();
    });
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          color: AppTheme.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add Member',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Member email address',
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'example@email.com',
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
    final sym = roomProv.currencySymbol;

    // Build balance map from summary
    final balanceMap = <String, Map<String, dynamic>>{};
    if (summary != null) {
      for (final m in (summary['memberSummary'] as List? ?? [])) {
        balanceMap[m['_id'] ?? ''] = m;
      }
    }

    // Compute totals
    double totalOwed = 0;
    double totalReceived = 0;
    for (final data in balanceMap.values) {
      final totalDue = (data['totalDue'] ?? data['balance'] ?? 0).toDouble();
      final partialPaid = (data['partialPaid'] ?? 0).toDouble();
      final isPaid = data['isPaid'] == true;
      if (totalDue > 0) {
        totalOwed += totalDue;
        if (isPaid) {
          totalReceived += totalDue;
        } else if (partialPaid > 0) {
          totalReceived += partialPaid;
        }
      }
    }
    // Include owner's share in totals — same formula as _OwnerCardState
    final totalMonthExpense = (summary?['totalRoomExpense'] ?? 0).toDouble();
    double ownerShare = 0;
    if (room != null) {
      final bills = room.monthlyBills;
      final memberCount = room.members.length + 1;
      final foodOptOutCount = room.foodOptOut.length;
      final foodEaters = memberCount - foodOptOutCount;
      final isOwnerFoodOptOut = owner != null && room.foodOptOut.contains(owner.id);
      if (memberCount > 0) {
        ownerShare += bills.rent / memberCount;
        ownerShare += bills.electricity / memberCount;
        ownerShare += bills.water / memberCount;
      }
      if (!isOwnerFoodOptOut && foodEaters > 0) {
        ownerShare += bills.food / foodEaters;
      }
    }
    totalOwed += ownerShare;
    final ownerIsPaid = owner != null && (room?.paidMembers.contains(owner.id) ?? false);
    if (ownerIsPaid) {
      totalReceived += ownerShare;
    }
    final remaining = totalOwed - totalReceived;

    final members = room?.members ?? [];
    final paidCount = room?.paidMembers.length ?? 0;
    final totalCount = members.length;
    // Include owner in paid/unpaid counts
    final ownerPaid = owner != null && (room?.paidMembers.contains(owner.id) ?? false);
    final totalPaidCount = paidCount;
    final totalUnpaidCount = (totalCount + 1) - totalPaidCount;

    // Apply search filter
    List<RoomMember> filtered = _search.isEmpty
        ? members
        : members
            .where((m) =>
                m.name.toLowerCase().contains(_search.toLowerCase()) ||
                m.email.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    // Apply paid/unpaid filter
    if (_filter == 'paid') {
      filtered =
          filtered.where((m) => room!.paidMembers.contains(m.id)).toList();
    } else if (_filter == 'unpaid') {
      filtered =
          filtered.where((m) => !room!.paidMembers.contains(m.id)).toList();
    }

    // Sort: unpaid first, then paid
    filtered.sort((a, b) {
      final aPaid = room?.paidMembers.contains(a.id) ?? false;
      final bPaid = room?.paidMembers.contains(b.id) ?? false;
      if (aPaid == bPaid) return 0;
      return aPaid ? 1 : -1;
    });

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Column(
        children: [
          // ── Dark Header ──────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + stats inline
                  Row(
                    children: [
                      const Text(
                        'Members',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, color: Colors.white54, size: 13),
                            const SizedBox(width: 4),
                            Text('${totalCount + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Container(width: 1, height: 12, color: Colors.white24),
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_outline, color: Color(0xFF66BB6A), size: 13),
                            const SizedBox(width: 4),
                            Text('$paidCount paid',
                                style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Billing breakdown card (compact)
                  _BillingBreakdownCard(
                    sym: sym,
                    totalExpense: totalMonthExpense,
                    received: totalReceived,
                    remaining: remaining,
                  ),
                  const SizedBox(height: 8),

                  // Search bar
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF243560),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search members...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: room == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await roomProv.fetchRoom();
                        await roomProv.fetchSummary();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          // Filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                    label: 'All (${members.length + 1})',
                                    active: _filter == 'all',
                                    onTap: () =>
                                        setState(() => _filter = 'all')),
                                const SizedBox(width: 8),
                                _FilterChip(
                                    label: 'Unpaid ($totalUnpaidCount)',
                                    active: _filter == 'unpaid',
                                    color: AppTheme.error,
                                    onTap: () =>
                                        setState(() => _filter = 'unpaid')),
                                const SizedBox(width: 8),
                                _FilterChip(
                                    label: 'Paid ($totalPaidCount)',
                                    active: _filter == 'paid',
                                    color: AppTheme.success,
                                    onTap: () =>
                                        setState(() => _filter = 'paid')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Owner card — shown based on paid status filter
                          if (owner != null &&
                              (_filter == 'all' ||
                               (_filter == 'paid' && ownerPaid) ||
                               (_filter == 'unpaid' && !ownerPaid)))
                            _OwnerCard(owner: owner, room: room, sym: sym),

                          // Empty state
                          if (filtered.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 48,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.4)),
                                    const SizedBox(height: 12),
                                    Text(
                                      _search.isNotEmpty
                                          ? 'No members found'
                                          : _filter == 'unpaid'
                                              ? 'Everyone has paid!'
                                              : 'No members yet',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...filtered.map((m) => _MemberCard(
                                  member: m,
                                  room: room,
                                  balanceData: balanceMap[m.id],
                                  sym: sym,
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

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.navy;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : const Color(0xFFE0E0E0)),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: c.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Owner Card ───────────────────────────────────────────────────────────────

class _OwnerCard extends StatefulWidget {
  final dynamic owner;
  final Room? room;
  final String sym;
  const _OwnerCard({required this.owner, this.room, this.sym = ''});

  @override
  State<_OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends State<_OwnerCard> {
  bool _togglingPaid = false;
  bool _togglingFood = false;

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    final room = widget.room;
    final sym = widget.sym;
    final isOwnerFoodOptOut = room?.foodOptOut.contains(owner.id) ?? false;

    // Calculate owner's share from bills
    double ownerShare = 0;
    if (room != null) {
      final bills = room!.monthlyBills;
      final memberCount = room!.members.length + 1;
      final foodOptOutCount = room!.foodOptOut.length;
      final foodEaters = memberCount - foodOptOutCount;
      if (memberCount > 0) {
        ownerShare += bills.rent / memberCount;
        ownerShare += bills.electricity / memberCount;
        ownerShare += bills.water / memberCount;
      }
      if (!isOwnerFoodOptOut && foodEaters > 0) {
        ownerShare += bills.food / foodEaters;
      }
    }

    final isPaid = room?.paidMembers.contains(owner.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPaid
                ? AppTheme.success.withOpacity(0.3)
                : AppTheme.teal.withOpacity(0.3)),
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
                if (ownerShare > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Share: $sym${ownerShare.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppTheme.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      if (isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PAID ✓',
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // All three action buttons aligned via _QuickAction
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Food toggle
              _QuickAction(
                icon: isOwnerFoodOptOut
                    ? Icons.no_meals_outlined
                    : Icons.restaurant_outlined,
                label: isOwnerFoodOptOut ? 'No Food' : 'Eats',
                color: isOwnerFoodOptOut ? AppTheme.error : AppTheme.teal,
                active: false,
                loading: _togglingFood,
                onTap: () async {
                  setState(() => _togglingFood = true);
                  await context.read<RoomProvider>().toggleFood(owner.id);
                  if (mounted) setState(() => _togglingFood = false);
                },
              ),
              const SizedBox(width: 6),
              // Paid toggle
              _QuickAction(
                icon: isPaid ? Icons.check_circle : Icons.check_circle_outline,
                label: isPaid ? 'Paid' : 'Mark Paid',
                color: AppTheme.success,
                active: isPaid,
                loading: _togglingPaid,
                onTap: () async {
                  setState(() => _togglingPaid = true);
                  await context.read<RoomProvider>().togglePaid(owner.id);
                  if (mounted) setState(() => _togglingPaid = false);
                },
              ),
              const SizedBox(width: 6),
              // Info
              _QuickAction(
                icon: Icons.info_outline,
                label: 'Info',
                color: AppTheme.teal,
                active: false,
                loading: false,
                onTap: () => showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.teal,
                          child: Text(
                            owner.name.isNotEmpty
                                ? owner.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(owner.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Text('OWNER',
                                style: TextStyle(
                                    color: AppTheme.teal, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _MemberInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: owner.email),
                  ],
                ),
              ),
            ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

// ─── Billing Breakdown Card ───────────────────────────────────────────────────

class _BillingBreakdownCard extends StatelessWidget {
  final String sym;
  final double totalExpense;
  final double received;
  final double remaining;

  const _BillingBreakdownCard({
    required this.sym,
    required this.totalExpense,
    required this.received,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF243560),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _BillCol(label: 'Expense', value: '$sym${totalExpense.toStringAsFixed(0)}', valueColor: Colors.white)),
          Container(width: 1, height: 32, color: Colors.white12),
          Expanded(child: _BillCol(label: 'Received', value: '$sym${received.toStringAsFixed(0)}', valueColor: const Color(0xFF66BB6A))),
          Container(width: 1, height: 32, color: Colors.white12),
          Expanded(child: _BillCol(label: 'Remaining', value: '$sym${remaining.toStringAsFixed(0)}', valueColor: remaining > 0 ? const Color(0xFFEF9A9A) : const Color(0xFF66BB6A), bold: true)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _BillRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}

class _BillCol extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _BillCol({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF243560),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
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
  final String sym;

  const _MemberCard({
    required this.member,
    required this.room,
    required this.sym,
    this.balanceData,
  });

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _expanded = false;
  bool _showContrib = false;
  bool _showBreakdown = false;
  bool _togglingPaid = false;
  bool _togglingFood = false;
  bool _removing = false;

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

  void _showMemberInfo() {
    final m = widget.member;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('MEMBER',
                          style:
                              TextStyle(color: AppTheme.teal, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _MemberInfoRow(
                icon: Icons.email_outlined, label: 'Email', value: m.email),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: (m.phone != null && m.phone!.isNotEmpty)
                  ? m.phone!
                  : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: (m.address != null && m.address!.isNotEmpty)
                  ? m.address!
                  : 'Not set',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${widget.member.name} from the room? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _removing = true);
      final ok =
          await context.read<RoomProvider>().removeMember(widget.member.id);
      if (mounted) {
        setState(() => _removing = false);
        showSnack(
          context,
          ok
              ? '${widget.member.name} removed'
              : (context.read<RoomProvider>().error ?? 'Failed'),
          error: !ok,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final room = widget.room;
    final sym = widget.sym;
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

    // Status
    String statusLabel;
    Color statusColor;
    if (isPaid) {
      statusLabel = 'PAID ✓';
      statusColor = AppTheme.success;
    } else if (balanceAmt > 0) {
      statusLabel = 'Owes $sym${balanceAmt.toStringAsFixed(0)}';
      statusColor = AppTheme.error;
    } else if (balanceAmt < 0) {
      statusLabel = 'Gets back $sym${balanceAmt.abs().toStringAsFixed(0)}';
      statusColor = AppTheme.teal;
    } else {
      statusLabel = 'Settled';
      statusColor = AppTheme.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPaid
            ? Border.all(color: AppTheme.success.withOpacity(0.25))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ── Top: avatar + name + status (tappable to expand) ────────
          GestureDetector(
            onTap: () => setState(() {
              _expanded = !_expanded;
              if (!_expanded) {
                _showContrib = false;
                _showBreakdown = false;
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Avatar with paid indicator
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppTheme.success.withOpacity(0.15)
                            : AppTheme.navy.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: isPaid ? AppTheme.success : AppTheme.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                    if (isPaid)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Name + badges + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              child: const Text('No Food',
                                  style: TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
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
                      if ((balance?['carryForward'] ?? 0) > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _StatusChip(label: 'Carry: $sym${(balance!['carryForward'] as num).toStringAsFixed(0)}', color: Colors.orange),
                            if ((balance['partialPaid'] ?? 0) > 0) ...[
                              const SizedBox(width: 6),
                              _StatusChip(label: 'Paid: $sym${(balance['partialPaid'] as num).toStringAsFixed(0)}', color: Colors.purple),
                            ],
                          ],
                        ),
                      ] else if ((balance?['partialPaid'] ?? 0) > 0) ...[
                        const SizedBox(height: 3),
                        _StatusChip(label: 'Paid: $sym${(balance!['partialPaid'] as num).toStringAsFixed(0)}', color: Colors.purple),
                      ],
                    ],
                  ),
                ),
                // Info button
                GestureDetector(
                  onTap: _showMemberInfo,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.navy.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: AppTheme.textSecondary, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
                // Chevron
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ],
            ),
          ),
          ),

          // ── Collapsible: divider + actions + inline panels ────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded ? Column(
              children: [
          // ── Divider ──────────────────────────────────────────────
          const Divider(height: 1, indent: 14, endIndent: 14),

          // ── Quick-action bar ──────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Mark Paid / Unpaid
                Expanded(
                  child: _QuickAction(
                    icon: isPaid
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    label: isPaid ? 'Paid' : 'Mark Paid',
                    color: AppTheme.success,
                    active: isPaid,
                    loading: _togglingPaid,
                    onTap: () async {
                      setState(() => _togglingPaid = true);
                      await context.read<RoomProvider>().togglePaid(m.id);
                      if (mounted) setState(() => _togglingPaid = false);
                    },
                  ),
                ),
                // Food toggle
                Expanded(
                  child: _QuickAction(
                    icon: isFoodOptOut
                        ? Icons.no_meals_outlined
                        : Icons.restaurant_outlined,
                    label: isFoodOptOut ? 'No Food' : 'Eats',
                    color: isFoodOptOut ? AppTheme.error : AppTheme.teal,
                    active: false,
                    loading: _togglingFood,
                    onTap: () async {
                      setState(() => _togglingFood = true);
                      await context.read<RoomProvider>().toggleFood(m.id);
                      if (mounted) setState(() => _togglingFood = false);
                    },
                  ),
                ),
                // Add contribution
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Contrib',
                    color: AppTheme.navy,
                    active: _showContrib,
                    loading: false,
                    onTap: () =>
                        setState(() => _showContrib = !_showContrib),
                  ),
                ),
                // Bill breakdown
                Expanded(
                  child: _QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Bills',
                    color: const Color(0xFF7E57C2),
                    active: _showBreakdown,
                    loading: false,
                    onTap: () => setState(
                        () => _showBreakdown = !_showBreakdown),
                  ),
                ),
                // Remove
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_remove_outlined,
                    label: 'Remove',
                    color: AppTheme.error,
                    active: false,
                    loading: _removing,
                    onTap: _confirmRemove,
                  ),
                ),
              ],
            ),
          ),

          // ── Inline: Add Contribution ──────────────────────────────────
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Contribution',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.teal)),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showContrib = false),
                        child: const Icon(Icons.close,
                            size: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount ($sym)',
                            isDense: true,
                            prefixIcon: const Icon(Icons.attach_money,
                                size: 16),
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

          // ── Inline: Bill Breakdown ────────────────────────────────────
          if (_showBreakdown)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF7E57C2).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bill Breakdown — ${m.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E57C2))),
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
                    _BreakdownRow(
                        'Rent',
                        memberCount > 0 ? bills.rent / memberCount : 0,
                        '÷ $memberCount',
                        sym: sym),
                  if (bills.food > 0)
                    isFoodOptOut
                        ? const _BreakdownRow(
                            'Food', 0, 'opted out',
                            optOut: true)
                        : _BreakdownRow(
                            'Food',
                            foodEaters > 0 ? bills.food / foodEaters : 0,
                            '÷ $foodEaters',
                            sym: sym),
                  if (bills.electricity > 0)
                    _BreakdownRow(
                        'Electricity',
                        memberCount > 0
                            ? bills.electricity / memberCount
                            : 0,
                        '÷ $memberCount',
                        sym: sym),
                  if (bills.water > 0)
                    _BreakdownRow(
                        'Water',
                        memberCount > 0 ? bills.water / memberCount : 0,
                        '÷ $memberCount',
                        sym: sym),
                  const Divider(height: 14),
                  _SummaryRow('Their Share',
                      '$sym${share.toStringAsFixed(2)}',
                      bold: true),
                  _SummaryRow(
                      'Contributions',
                      '- $sym${contribution.toStringAsFixed(2)}',
                      color: AppTheme.success),
                  _SummaryRow(
                    isPaid ? 'Status' : 'Balance',
                    isPaid
                        ? 'PAID ✓'
                        : balanceAmt > 0
                            ? 'Owes $sym${balanceAmt.toStringAsFixed(2)}'
                            : balanceAmt < 0
                                ? 'Gets $sym${balanceAmt.abs().toStringAsFixed(2)}'
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
          ], // end AnimatedSize Column children
        ) : const SizedBox.shrink(),
        ), // end AnimatedSize
        ],
      ),
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active
                  ? color.withOpacity(0.15)
                  : color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: color.withOpacity(0.4))
                  : null,
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    ),
                  )
                : Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal)),
        ],
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
  final String sym;

  const _BreakdownRow(this.label, this.amount, this.note,
      {this.optOut = false, this.sym = ''});

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
            optOut ? 'opted out' : '$sym${amount.toStringAsFixed(0)}',
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

// ─── Member Info Row ──────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _MemberInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MemberInfoRow(
      {required this.icon, required this.label, required this.value});

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
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
