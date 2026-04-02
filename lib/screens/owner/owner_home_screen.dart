import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/expense.dart';
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
  // Figma order: Home(0), Expenses(1), Members(2), Summary(3)
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

    if (room == null && !context.watch<RoomProvider>().loading) {
      return const RoomSetupScreen();
    }

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = [
      _DashboardTab(onGoToExpenses: () => setState(() => _tab = 1)),
      ExpensesScreen(onGoBack: null),
      const MembersScreen(),
      const SummaryScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: tabs[_tab],
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ─── Bottom Navigation ───────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Expenses', index: 1, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Members', index: 2, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart, label: 'Summary', index: 3, currentIndex: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.navy : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.navy : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final VoidCallback onGoToExpenses;

  const _DashboardTab({required this.onGoToExpenses});

  String _fmtAmount(double n, String sym) {
    if (n >= 1000) return '$sym${(n / 1000).toStringAsFixed(1)}k';
    return '$sym${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room!;
    final sym = context.read<RoomProvider>().currencySymbol;
    final user = context.watch<AuthProvider>().user;
    final expenses = context.watch<ExpenseProvider>().expenses;
    final pendingCount = expenses.where((e) => e.isPending).length;
    final totalExpenses = expenses
        .where((e) => e.isApproved)
        .fold(0.0, (s, e) => s + e.amount);
    final memberCount = room.members.length + 1;
    final recentExpenses = expenses.take(3).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<RoomProvider>().fetchRoom();
        await context.read<RoomProvider>().fetchSummary();
        await context.read<ExpenseProvider>().fetchExpenses();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dark Header ──────────────────────────────────────────
            Container(
              color: AppTheme.navy,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Room name row
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.home, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$memberCount Members',
                                style: const TextStyle(
                                    color: AppTheme.teal, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user?.name ?? ''} · Owner',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 26),
                            if (pendingCount > 0)
                              Positioned(
                                top: -1,
                                right: -1,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white, size: 22),
                          onSelected: (v) {
                            if (v == 'bills') {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MonthlyBillsScreen()));
                            } else if (v == 'room-details') {
                              _showEditRoomDetails(context);
                            } else if (v == 'profile') {
                              _showProfileInfo(context);
                            } else if (v == 'logout') {
                              context.read<AuthProvider>().logout(roomProvider: context.read<RoomProvider>(), expenseProvider: context.read<ExpenseProvider>());
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'bills', child: Text('Monthly Bills')),
                            PopupMenuItem(
                              value: 'room-details',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_location_alt_outlined, size: 18, color: Colors.black87),
                                  SizedBox(width: 8),
                                  Text('Room Details'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.black87),
                                  SizedBox(width: 8),
                                  Text('My Info'),
                                ],
                              ),
                            ),
                            PopupMenuItem(value: 'logout', child: Text('Logout')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Room code chip
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: room.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room code copied!'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.vpn_key_outlined, color: AppTheme.teal, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Room Code: ${room.roomCode}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_outlined, color: Colors.white54, size: 13),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Stat cards row
                    Row(
                      children: [
                        Expanded(child: _StatCard(
                          icon: Icons.attach_money,
                          iconColor: AppTheme.teal,
                          value: _fmtAmount(totalExpenses, sym),
                          label: 'This Month',
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          icon: Icons.access_time_outlined,
                          iconColor: AppTheme.warning,
                          value: '$pendingCount',
                          label: 'Pending',
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          icon: Icons.people_outline,
                          iconColor: AppTheme.teal,
                          value: '$memberCount',
                          label: 'Members',
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── White Body ───────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Monthly Bills quick-access button
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MonthlyBillsScreen()),
                    ).then((_) => context.read<RoomProvider>().fetchRoom()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.navy, Color(0xFF243580)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navy.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Bills',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text(
                                'Billing: ${room.billingMonth.isNotEmpty ? room.billingMonth : "Not set"}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.teal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Edit',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary cards row
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.attach_money,
                          iconBg: const Color(0xFFF44336),
                          title: 'Total Expenses',
                          value: '$sym${totalExpenses.toStringAsFixed(0)}',
                          subtitle: expenses.isNotEmpty
                              ? '${expenses.where((e) => e.isApproved).length} transactions'
                              : 'No expenses yet',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.access_time_outlined,
                          iconBg: AppTheme.warning,
                          title: 'Pending\nApprovals',
                          value: '$pendingCount',
                          subtitle: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Expenses header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Expenses',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      GestureDetector(
                        onTap: onGoToExpenses,
                        child: const Text(
                          'View All',
                          style: TextStyle(
                              color: AppTheme.teal,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (expenses.isEmpty)
                    _EmptyState(
                      icon: Icons.receipt_long,
                      message: 'No expenses yet',
                    )
                  else
                    ...recentExpenses.map((e) => _ExpenseCard(expense: e)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showEditRoomDetails(BuildContext context) {
    final room = context.read<RoomProvider>().room;
    final addressCtrl = TextEditingController(text: room?.address ?? '');
    final locationCtrl = TextEditingController(text: room?.location ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy)),
            const SizedBox(height: 4),
            const Text('Set address and location for your room',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'e.g. 123 Main St, Building A',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location / Area',
                hintText: 'e.g. Kozhikode, Kerala',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await context.read<RoomProvider>().updateRoomDetails(
                    addressCtrl.text.trim(),
                    locationCtrl.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Room details saved!' : 'Failed to save'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showProfileInfo(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileInfoSheet(user: user),
    );
  }
}

// ─── Stat Card (header) ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF243560),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card (white body) ────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String value;
  final String? subtitle;

  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Expense Card ─────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final sym = context.read<RoomProvider>().currencySymbol;
    final dateFmt = DateFormat('MMM d');
    final isPending = expense.isPending;
    final isApproved = expense.isApproved;

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
              Text(
                '$sym${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
              if (expense.comments != null && expense.comments!.isNotEmpty) ...[
                const Text(
                  ' · ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  expense.comments!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              const Spacer(),
              Text(
                dateFmt.format(expense.date),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          _StatusBadge(status: expense.status),
        ],
      ),
    );
  }
}

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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Info Sheet ───────────────────────────────────────────────────────

class _ProfileInfoSheet extends StatefulWidget {
  final dynamic user;
  const _ProfileInfoSheet({required this.user});

  @override
  State<_ProfileInfoSheet> createState() => _ProfileInfoSheetState();
}

class _ProfileInfoSheetState extends State<_ProfileInfoSheet> {
  bool _editing = false;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.user?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.user?.address ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().updateProfile(
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
    setState(() {
      _saving = false;
      if (error == null) _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
                  (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user?.role.toUpperCase() ?? '', style: const TextStyle(color: AppTheme.teal, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
                onPressed: () => setState(() => _editing = !_editing),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? ''),
          const SizedBox(height: 12),
          if (_editing) ...[
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ),
          ] else ...[
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: user?.phone?.isNotEmpty == true ? user!.phone! : 'Not set',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: user?.address?.isNotEmpty == true ? user!.address! : 'Not set',
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

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
