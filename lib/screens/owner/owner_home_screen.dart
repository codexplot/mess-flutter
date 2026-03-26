import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'room_setup_screen.dart';
import 'members_screen.dart';
import 'expenses_screen.dart';
import 'summary_screen.dart';
import 'monthly_bills_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<RoomProvider>().fetchRoom();
    if (mounted) {
      await context.read<RoomProvider>().fetchSummary();
      await context.read<ExpenseProvider>().fetchExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    final user = context.watch<AuthProvider>().user;

    if (room == null && !context.watch<RoomProvider>().loading) {
      return const RoomSetupScreen();
    }

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = [
      _DashboardTab(
        room: room,
        user: user,
        onGoToMembers: () => setState(() => _tab = 1),
        onGoToExpenses: () => setState(() => _tab = 2),
        onGoToSummary: () => setState(() => _tab = 3),
      ),
      const MembersScreen(),
      const ExpensesScreen(),
      const SummaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Monthly Bills',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MonthlyBillsScreen())),
          ),
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.receipt_outlined), selectedIcon: Icon(Icons.receipt), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Summary'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final dynamic room;
  final dynamic user;
  final VoidCallback? onGoToMembers;
  final VoidCallback? onGoToExpenses;
  final VoidCallback? onGoToSummary;

  const _DashboardTab({
    this.room,
    this.user,
    this.onGoToMembers,
    this.onGoToExpenses,
    this.onGoToSummary,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final summary = context.watch<RoomProvider>().summary;
    final pendingCount = expenses.where((e) => e.isPending).length;
    final totalContributions = expenses
        .where((e) => e.isApproved)
        .fold(0.0, (sum, e) => sum + e.amount);

    final bills = room?.monthlyBills;
    final memberCount = (room?.members.length ?? 0) as int;
    final foodOptOutCount = (room?.foodOptOut.length ?? 0) as int;
    final foodEaters = memberCount - foodOptOutCount;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<RoomProvider>().fetchRoom();
        await context.read<RoomProvider>().fetchSummary();
        await context.read<ExpenseProvider>().fetchExpenses();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.navy, AppTheme.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${user?.name ?? ''}!',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Room Overview',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Text('Code: ${room?.roomCode ?? ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      if (room?.billingMonth.isNotEmpty == true)
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.white54, size: 14),
                            const SizedBox(width: 4),
                            Text(room!.billingMonth,
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pending alert
            if (pendingCount > 0)
              GestureDetector(
                onTap: onGoToExpenses,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions, color: AppTheme.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$pendingCount expense${pendingCount > 1 ? 's' : ''} waiting for your approval',
                          style: const TextStyle(
                              color: AppTheme.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: AppTheme.warning, size: 14),
                    ],
                  ),
                ),
              ),

            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                InfoCard(
                  label: 'Members',
                  value: '$memberCount',
                  icon: Icons.people,
                  color: AppTheme.navy,
                ),
                InfoCard(
                  label: 'Pending',
                  value: '$pendingCount',
                  icon: Icons.pending_actions,
                  color: AppTheme.warning,
                ),
                InfoCard(
                  label: 'Total Bills',
                  value: '₹${bills?.total.toStringAsFixed(0) ?? '0'}',
                  icon: Icons.account_balance_wallet,
                  color: AppTheme.teal,
                ),
                InfoCard(
                  label: 'Contributions',
                  value: '₹${totalContributions.toStringAsFixed(0)}',
                  icon: Icons.trending_up,
                  color: AppTheme.success,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Monthly bills breakdown
            if (bills != null && bills.total > 0) ...[
              const SectionHeader(title: 'Monthly Bills'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (bills.rent > 0)
                        _BillRow(Icons.home_outlined, 'Rent',
                            bills.rent, memberCount, memberCount),
                      if (bills.food > 0)
                        _BillRow(Icons.restaurant_outlined, 'Food',
                            bills.food, memberCount, foodEaters > 0 ? foodEaters : memberCount),
                      if (bills.electricity > 0)
                        _BillRow(Icons.bolt_outlined, 'Electricity',
                            bills.electricity, memberCount, memberCount),
                      if (bills.water > 0)
                        _BillRow(Icons.water_drop_outlined, 'Water',
                            bills.water, memberCount, memberCount),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Monthly',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${bills.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.teal,
                                  fontSize: 16)),
                        ],
                      ),
                      if (memberCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Per Person (avg)',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            Text(
                              '≈ ₹${(bills.total / memberCount).toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Member Contributions',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            Text(
                              '₹${totalContributions.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.success, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Member balances
            if (summary != null) ...[
              const SectionHeader(title: 'Member Balances'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final m in (summary['memberSummary'] as List? ?? []))
                        _MemberBalanceRow(data: m),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Quick actions
            const SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _QuickAction(
                  icon: Icons.receipt_long,
                  label: 'Monthly Bills',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MonthlyBillsScreen())),
                ),
                _QuickAction(
                  icon: Icons.people,
                  label: 'Manage Members',
                  onTap: onGoToMembers ?? () {},
                ),
                _QuickAction(
                  icon: Icons.pending_actions,
                  label: 'Approve Expenses',
                  badge: pendingCount > 0 ? '$pendingCount' : null,
                  onTap: onGoToExpenses ?? () {},
                ),
                _QuickAction(
                  icon: Icons.bar_chart,
                  label: 'View Summary',
                  onTap: onGoToSummary ?? () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final int totalMembers;
  final int divisor;

  const _BillRow(this.icon, this.label, this.amount, this.totalMembers, this.divisor);

  @override
  Widget build(BuildContext context) {
    final perPerson = divisor > 0 ? amount / divisor : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('(₹${perPerson.toStringAsFixed(0)}/person)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MemberBalanceRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MemberBalanceRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final balance = (data['balance'] ?? 0).toDouble();
    final isPaid = data['isPaid'] ?? false;
    final isFoodOptOut = !(data['eatsFood'] ?? true);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.teal.withOpacity(0.15),
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      title: Row(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          if (isFoodOptOut) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('No Food',
                  style: TextStyle(color: AppTheme.error, fontSize: 9)),
            ),
          ],
        ],
      ),
      trailing: isPaid
          ? const _StatusPill('PAID', AppTheme.success)
          : balance > 0
              ? _StatusPill('Pay ₹${balance.toStringAsFixed(0)}', AppTheme.error)
              : balance < 0
                  ? _StatusPill('Get ₹${balance.abs().toStringAsFixed(0)}', AppTheme.teal)
                  : const _StatusPill('Settled', AppTheme.textSecondary),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Icon(icon, color: AppTheme.navy, size: 20),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppTheme.error, shape: BoxShape.circle),
                      child: Text(badge!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
