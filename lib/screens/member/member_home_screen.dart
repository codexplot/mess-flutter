import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'member_expenses_screen.dart';
import 'submit_expense_screen.dart';
import 'member_summary_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user?.roomId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RoomMess'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_outlined,
                      size: 60, color: AppTheme.teal),
                ),
                const SizedBox(height: 24),
                const Text('Not in a Room Yet',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                      color: AppTheme.teal, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ask your room owner to add you using your email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = [
      _MemberDashboardTab(
        onAddExpense: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitExpenseScreen()),
        ),
        onMyExpenses: () => setState(() => _tab = 1),
      ),
      const MemberExpensesScreen(),
      const MemberSummaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.roomName ?? 'RoomMess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_outlined),
              selectedIcon: Icon(Icons.receipt),
              label: 'My Expenses'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Summary'),
        ],
      ),
    );
  }
}

class _MemberDashboardTab extends StatefulWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onMyExpenses;

  const _MemberDashboardTab({
    required this.onAddExpense,
    required this.onMyExpenses,
  });

  @override
  State<_MemberDashboardTab> createState() => _MemberDashboardTabState();
}

class _MemberDashboardTabState extends State<_MemberDashboardTab> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _expandedMember;
  String? _expandedExpenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _summary = await context.read<RoomProvider>().fetchMemberSummary();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Unable to load dashboard',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final room = (_summary!['room'] ?? {}) as Map<String, dynamic>;
    final roomName = room['name'] ?? '';
    final billingMonth = room['billingMonth'] ?? '';
    final totalRoomExpense = (_summary!['totalRoomExpense'] ?? 0).toDouble();
    final perPersonShare = (_summary!['perPersonShare'] ?? 0).toDouble();
    final myContribution = (_summary!['myContribution'] ?? 0).toDouble();
    final numberOfMembers = (_summary!['numberOfMembers'] ?? 0) as int;
    final balance = (_summary!['balance'] ?? 0).toDouble();
    final status = _summary!['status'] ?? 'settled';
    final eatsFood = _summary!['eatsFood'] ?? true;
    final members = (_summary!['memberSummary'] as List?) ?? [];
    final bills = (_summary!['monthlyBills'] ?? {}) as Map<String, dynamic>;

    final foodEaters = members.where((m) => (m['eatsFood'] ?? true) as bool).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR ROOM',
                      style: TextStyle(
                          color: Color(0xFF99F6E4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(roomName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  if (billingMonth.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Billing: $billingMonth',
                        style: const TextStyle(
                            color: Color(0xFF99F6E4), fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                InfoCard(
                  label: 'Total Bill',
                  value: '₹${totalRoomExpense.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee,
                  color: AppTheme.teal,
                ),
                InfoCard(
                  label: 'Your Share',
                  value: '₹${perPersonShare.toStringAsFixed(0)}',
                  icon: Icons.trending_up,
                  color: AppTheme.navy,
                ),
                InfoCard(
                  label: 'You Spent',
                  value: '₹${myContribution.toStringAsFixed(0)}',
                  icon: Icons.shopping_bag_outlined,
                  color: AppTheme.success,
                ),
                InfoCard(
                  label: 'Members',
                  value: '$numberOfMembers',
                  icon: Icons.people_outline,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Your Balance card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Balance',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    _BalanceDisplay(balance: balance, status: status),
                    const SizedBox(height: 16),
                    const Text('YOUR BILL BREAKDOWN',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    _buildBillBreakdown(
                      bills: bills,
                      memberCount: numberOfMembers,
                      foodEaters: foodEaters,
                      eatsFood: eatsFood,
                    ),
                    const Divider(height: 16),
                    _SummaryRow(
                      label: 'Your Share',
                      value: '₹${perPersonShare.toStringAsFixed(2)}',
                      bold: true,
                      color: AppTheme.teal,
                    ),
                    _SummaryRow(
                      label: '− Your Contributions',
                      value: '₹${myContribution.toStringAsFixed(2)}',
                      color: AppTheme.success,
                    ),
                    const SizedBox(height: 4),
                    _SummaryRow(
                      label: status == 'paid'
                          ? 'Status'
                          : status == 'pays'
                              ? 'You Pay'
                              : status == 'receives'
                                  ? 'You Get'
                                  : 'Balance',
                      value: status == 'paid'
                          ? 'PAID ✓'
                          : '₹${balance.abs().toStringAsFixed(2)}',
                      bold: true,
                      color: status == 'pays'
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Room Members
            const SectionHeader(title: 'Room Members'),
            const SizedBox(height: 12),
            ...members.map((m) {
              final mId = m['_id'] ?? '';
              final name = m['name'] ?? '';
              final isMe = m['isMe'] ?? false;
              final mEatsFood = m['eatsFood'] ?? true;
              final contribution = (m['contribution'] ?? 0).toDouble();
              final share = (m['perPersonShare'] ?? 0).toDouble();
              final bal = (m['balance'] ?? 0).toDouble();
              final mStatus = m['status'] ?? 'settled';
              final expenses = (m['expenses'] as List?) ?? [];
              final isExpanded = _expandedMember == mId;
              final isExpensesExpanded = _expandedExpenses == mId;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isMe ? AppTheme.teal.withOpacity(0.05) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isMe
                        ? AppTheme.teal.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isMe ? AppTheme.teal : Colors.grey.shade400,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$name${isMe ? ' (you)' : ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spent: ₹${contribution.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12)),
                          if (!mEatsFood)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('No Food',
                                  style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusBadge(status: mStatus, balance: bal),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() =>
                                _expandedMember = isExpanded ? null : mId),
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 12),
                            const Text('BILL BREAKDOWN',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0)),
                            const SizedBox(height: 6),
                            _buildBillBreakdown(
                              bills: bills,
                              memberCount: numberOfMembers,
                              foodEaters: foodEaters,
                              eatsFood: mEatsFood,
                              small: true,
                            ),
                            const Divider(height: 12),
                            _SummaryRowSmall(
                              label: isMe
                                  ? 'Your Share'
                                  : "${name.split(' ')[0]}'s Share",
                              value:
                                  '₹${share.toStringAsFixed(2)}',
                              bold: true,
                              color: AppTheme.teal,
                            ),
                            _SummaryRowSmall(
                              label: '− Contributions',
                              value:
                                  '₹${contribution.toStringAsFixed(2)}',
                              color: AppTheme.success,
                            ),
                            _SummaryRowSmall(
                              label: mStatus == 'paid'
                                  ? 'Status'
                                  : mStatus == 'pays'
                                      ? 'Owes'
                                      : mStatus == 'receives'
                                          ? 'Gets Back'
                                          : 'Balance',
                              value: mStatus == 'paid'
                                  ? 'PAID ✓'
                                  : '₹${bal.abs().toStringAsFixed(2)}',
                              bold: true,
                              color: mStatus == 'pays'
                                  ? AppTheme.error
                                  : AppTheme.success,
                            ),
                            if (expenses.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => setState(() =>
                                    _expandedExpenses =
                                        isExpensesExpanded ? null : mId),
                                child: Row(
                                  children: [
                                    Text(
                                      'EXPENSES ADDED (${expenses.length})',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isExpensesExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpensesExpanded) ...[
                                const SizedBox(height: 6),
                                ...expenses.map((exp) {
                                  final shopName =
                                      exp['shopName'] ?? '';
                                  final comments =
                                      exp['comments'] ?? '';
                                  final amount =
                                      (exp['amount'] ?? 0).toDouble();
                                  final date = exp['date'] != null
                                      ? _formatDate(exp['date'])
                                      : '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shopName +
                                                    (comments.isNotEmpty
                                                        ? ' · $comments'
                                                        : ''),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppTheme
                                                        .textPrimary),
                                              ),
                                              if (date.isNotEmpty)
                                                Text(date,
                                                    style: const TextStyle(
                                                        color: AppTheme
                                                            .textSecondary,
                                                        fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${amount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.success),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddExpense,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onMyExpenses,
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('My Expenses'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBillBreakdown({
    required Map<String, dynamic> bills,
    required int memberCount,
    required int foodEaters,
    required bool eatsFood,
    bool small = false,
  }) {
    final rows = <Widget>[];
    final billFields = [
      {'key': 'rent', 'label': 'Rent', 'icon': Icons.home_outlined},
      {'key': 'food', 'label': 'Food', 'icon': Icons.shopping_bag_outlined},
      {'key': 'electricity', 'label': 'Electricity', 'icon': Icons.bolt_outlined},
      {'key': 'water', 'label': 'Water', 'icon': Icons.water_drop_outlined},
    ];

    for (final field in billFields) {
      final key = field['key'] as String;
      final label = field['label'] as String;
      final icon = field['icon'] as IconData;
      final total = (bills[key] ?? 0).toDouble();
      if (total == 0) continue;

      if (key == 'food') {
        if (!eatsFood) {
          rows.add(_BillDetailRow(
            label: label,
            icon: icon,
            calcText: 'opted out',
            amount: '₹0',
            optOut: true,
            small: small,
          ));
        } else {
          final share = foodEaters > 0 ? total / foodEaters : 0.0;
          rows.add(_BillDetailRow(
            label: label,
            icon: icon,
            calcText: '÷ $foodEaters',
            amount: '₹${share.toStringAsFixed(small ? 0 : 2)}',
            small: small,
          ));
        }
      } else {
        final share = memberCount > 0 ? total / memberCount : 0.0;
        rows.add(_BillDetailRow(
          label: label,
          icon: icon,
          calcText: '÷ $memberCount',
          amount: '₹${share.toStringAsFixed(small ? 0 : 2)}',
          small: small,
        ));
      }
    }

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('No bills set',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      );
    }

    return Column(children: rows);
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _BalanceDisplay extends StatelessWidget {
  final double balance;
  final String status;

  const _BalanceDisplay({required this.balance, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, border, textColor;
    IconData icon;
    String title, subtitle;

    switch (status) {
      case 'paid':
        bg = AppTheme.success.withOpacity(0.08);
        border = AppTheme.success.withOpacity(0.3);
        textColor = AppTheme.success;
        icon = Icons.trending_down;
        title = 'PAID';
        subtitle = 'Owner confirmed payment';
        break;
      case 'pays':
        bg = AppTheme.error.withOpacity(0.06);
        border = AppTheme.error.withOpacity(0.2);
        textColor = AppTheme.error;
        icon = Icons.trending_up;
        title = '₹${balance.abs().toStringAsFixed(2)}';
        subtitle = 'You Need to Pay';
        break;
      case 'receives':
        bg = AppTheme.success.withOpacity(0.08);
        border = AppTheme.success.withOpacity(0.2);
        textColor = AppTheme.success;
        icon = Icons.trending_down;
        title = '₹${balance.abs().toStringAsFixed(2)}';
        subtitle = 'You Will Receive';
        break;
      default:
        bg = Colors.grey.shade50;
        border = Colors.grey.shade200;
        textColor = Colors.grey;
        icon = Icons.remove;
        title = '₹0';
        subtitle = 'All Settled';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor)),
        ],
      ),
    );
  }
}

class _BillDetailRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String calcText;
  final String amount;
  final bool optOut;
  final bool small;

  const _BillDetailRow({
    required this.label,
    required this.icon,
    required this.calcText,
    required this.amount,
    this.optOut = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 3 : 5),
      child: Row(
        children: [
          Icon(icon,
              size: small ? 14 : 16,
              color: optOut ? AppTheme.textSecondary : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: optOut ? AppTheme.textSecondary : AppTheme.textPrimary,
                fontSize: small ? 12 : 13,
                decoration:
                    optOut ? TextDecoration.lineThrough : null),
          ),
          const SizedBox(width: 4),
          Text(calcText,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: small ? 10 : 11)),
          if (optOut) ...[
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('opted out',
                  style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: small ? 12 : 13,
                  color: optOut
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary)),
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

  const _SummaryRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

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
                  color: color ?? AppTheme.textPrimary,
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

class _SummaryRowSmall extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRowSmall(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

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
                  color: color ?? AppTheme.textSecondary,
                  fontSize: 11)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final double balance;

  const _StatusBadge({required this.status, required this.balance});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'paid':
        color = AppTheme.success;
        label = 'PAID';
        break;
      case 'pays':
        color = AppTheme.error;
        label = 'Pay ₹${balance.abs().toStringAsFixed(0)}';
        break;
      case 'receives':
        color = AppTheme.teal;
        label = 'Get ₹${balance.abs().toStringAsFixed(0)}';
        break;
      default:
        color = AppTheme.textSecondary;
        label = 'Settled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}
