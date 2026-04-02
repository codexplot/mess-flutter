import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'member_expenses_screen.dart';
import 'submit_expense_screen.dart';
import 'member_summary_screen.dart';
import 'profile_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().fetchRoom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user?.roomId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RoomMess'),
          actions: [
            TextButton(
              onPressed: () => context.read<AuthProvider>().logout(roomProvider: context.read<RoomProvider>(), expenseProvider: context.read<ExpenseProvider>()),
              child: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
        ).then((_) => context.read<ExpenseProvider>().fetchExpenses()),
        onMyExpenses: () => setState(() => _tab = 1),
        onGoToSummary: () => setState(() => _tab = 2),
      ),
      const MemberExpensesScreen(),
      const MemberSummaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoomMess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showProfileInfo(context),
          ),
          TextButton(
            onPressed: () => context.read<AuthProvider>().logout(roomProvider: context.read<RoomProvider>(), expenseProvider: context.read<ExpenseProvider>()),
            child: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 14)),
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

  void _showProfileInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

class _MemberDashboardTab extends StatefulWidget {
  final Future<void> Function() onAddExpense;
  final VoidCallback onMyExpenses;
  final VoidCallback onGoToSummary;

  const _MemberDashboardTab({
    required this.onAddExpense,
    required this.onMyExpenses,
    required this.onGoToSummary,
  });

  @override
  State<_MemberDashboardTab> createState() => _MemberDashboardTabState();
}

class _MemberDashboardTabState extends State<_MemberDashboardTab> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _expandedMember;
  String? _expandedExpenses;
  String? _selectedMonth; // null = current billing month
  List<String> _availableMonths = [];
  final _scrollController = ScrollController();
  final _balanceKey = GlobalKey();
  final _membersKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? month}) async {
    setState(() => _loading = true);
    _summary = await context.read<RoomProvider>().fetchMemberSummary(month: month ?? _selectedMonth);
    if (_availableMonths.isEmpty) {
      _availableMonths = await context.read<RoomProvider>().fetchAvailableMonths();
    }
    setState(() => _loading = false);
  }

  void _showMonthPicker(BuildContext context, String currentMonth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Month',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navy)),
            const SizedBox(height: 16),
            ..._availableMonths.map((m) {
              final isSelected = m == (_selectedMonth ?? currentMonth);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_month,
                  color: isSelected ? AppTheme.teal : AppTheme.textSecondary,
                ),
                title: Text(
                  _formatMonth(m),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.teal : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.teal)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedMonth = m;
                    _expandedMember = null;
                    _expandedExpenses = null;
                  });
                  _load(month: m);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      final year = int.parse(parts[0]);
      final mon = int.parse(parts[1]);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[mon - 1]} $year';
    } catch (_) {
      return yyyyMM;
    }
  }

  void _showRoomInfo(BuildContext context, {
    required String name,
    required String address,
    required String location,
    required String ownerName,
    required String ownerEmail,
    required String roomCode,
    required String billingMonth,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room $name',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('ROOM INFO',
                          style: TextStyle(
                              color: AppTheme.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: address.isNotEmpty ? address : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.map_outlined,
              label: 'Location',
              value: location.isNotEmpty ? location : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.person_outline,
              label: 'Owner',
              value: ownerName.isNotEmpty ? ownerName : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.email_outlined,
              label: 'Owner Email',
              value: ownerEmail.isNotEmpty ? ownerEmail : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.vpn_key_outlined,
              label: 'Room Code',
              value: roomCode.isNotEmpty ? roomCode : 'N/A',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Billing Month',
              value: billingMonth.isNotEmpty ? billingMonth : 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberInfo(BuildContext context, Map<String, dynamic> m) {
    final name = m['name'] ?? '';
    final email = m['email'] ?? '';
    final phone = m['phone'];
    final address = m['address'];
    final isOwner = m['isOwner'] ?? false;
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
                  backgroundColor: isOwner ? AppTheme.navy : AppTheme.teal,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        isOwner ? 'OWNER' : 'MEMBER',
                        style: TextStyle(
                          color: isOwner ? AppTheme.navy : AppTheme.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _MemberInfoRow(icon: Icons.email_outlined, label: 'Email', value: email.isNotEmpty ? email : 'Not set'),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: (phone != null && phone.toString().isNotEmpty) ? phone.toString() : 'Not set',
            ),
            const SizedBox(height: 12),
            _MemberInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: (address != null && address.toString().isNotEmpty) ? address.toString() : 'Not set',
            ),
          ],
        ),
      ),
    );
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
    final roomCode = room['roomCode'] ?? '';
    final billingMonth = room['billingMonth'] ?? '';
    final roomAddress = room['address'] ?? '';
    final roomLocation = room['location'] ?? '';
    final ownerName = room['ownerName'] ?? '';
    final ownerEmail = room['ownerEmail'] ?? '';
    final viewedMonth = room['viewedMonth'] ?? billingMonth;
    final totalRoomExpense = (_summary!['totalRoomExpense'] ?? 0).toDouble();
    final perPersonShare = (_summary!['perPersonShare'] ?? 0).toDouble();
    final myContribution = (_summary!['myContribution'] ?? 0).toDouble();
    final numberOfMembers = (_summary!['numberOfMembers'] ?? 0) as int;
    final balance = (_summary!['balance'] ?? 0).toDouble();
    final status = _summary!['status'] ?? 'settled';
    final eatsFood = _summary!['eatsFood'] ?? true;
    // Sort: current user first, owner second, then others
    final rawMembers = List<Map<String, dynamic>>.from(
      ((_summary!['memberSummary'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    rawMembers.sort((a, b) {
      final aIsOwner = (a['isOwner'] ?? false) as bool;
      final bIsOwner = (b['isOwner'] ?? false) as bool;
      final aIsMe = (a['isMe'] ?? false) as bool;
      final bIsMe = (b['isMe'] ?? false) as bool;
      if (aIsOwner) return -1;
      if (bIsOwner) return 1;
      if (aIsMe) return -1;
      if (bIsMe) return 1;
      return 0;
    });
    final members = rawMembers;
    final bills = (_summary!['monthlyBills'] ?? {}) as Map<String, dynamic>;

    // +1 to include the owner in the food split
    final foodEaters = members.where((m) => (m['eatsFood'] ?? true) as bool).length + 1;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room banner
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${context.read<AuthProvider>().user?.name ?? ''}!',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text('Room $roomName',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (roomCode.isNotEmpty) ...[
                            const Icon(Icons.meeting_room,
                                color: Colors.white54, size: 14),
                            const SizedBox(width: 4),
                            Text('Code: $roomCode',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const Spacer(),
                          ],
                          // Tappable month chip
                          GestureDetector(
                            onTap: () => _showMonthPicker(context, billingMonth),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Colors.white70, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatMonth(_selectedMonth ?? billingMonth),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down,
                                      color: Colors.white70, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Info button pinned to top-right corner
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _showRoomInfo(
                      context,
                      name: roomName,
                      address: roomAddress,
                      location: roomLocation,
                      ownerName: ownerName,
                      ownerEmail: ownerEmail,
                      roomCode: roomCode,
                      billingMonth: billingMonth,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
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
                GestureDetector(
                  onTap: widget.onGoToSummary,
                  child: InfoCard(
                    label: 'Total Bill',
                    value: '₹${totalRoomExpense.toStringAsFixed(0)}',
                    icon: Icons.currency_rupee,
                    color: AppTheme.teal,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_balanceKey.currentContext != null) {
                      Scrollable.ensureVisible(_balanceKey.currentContext!,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    }
                  },
                  child: InfoCard(
                    label: 'Your Share',
                    value: '₹${perPersonShare.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    color: AppTheme.navy,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onMyExpenses,
                  child: InfoCard(
                    label: 'You Spent',
                    value: '₹${myContribution.toStringAsFixed(0)}',
                    icon: Icons.shopping_bag_outlined,
                    color: AppTheme.success,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_membersKey.currentContext != null) {
                      Scrollable.ensureVisible(_membersKey.currentContext!,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    }
                  },
                  child: InfoCard(
                    label: 'Members',
                    value: '$numberOfMembers',
                    icon: Icons.people_outline,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Your Balance card
            Card(
              key: _balanceKey,
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
            SectionHeader(key: _membersKey, title: 'Room Members'),
            const SizedBox(height: 12),
            ...members.map((m) {
              final mId = m['_id'] ?? '';
              final name = m['name'] ?? '';
              final isMe = m['isMe'] ?? false;
              final isOwner = m['isOwner'] ?? false;
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOwner
                            ? AppTheme.navy
                            : isMe ? AppTheme.teal : Colors.grey.shade400,
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
                          if (isOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.navy.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Owner',
                                  style: TextStyle(
                                      color: AppTheme.navy,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isOwner)
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
                      trailing: isOwner
                          ? IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: AppTheme.navy, size: 20),
                              onPressed: () => _showMemberInfo(context, m),
                            )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusBadge(status: mStatus, balance: bal),
                          IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: AppTheme.teal, size: 20),
                            onPressed: () => _showMemberInfo(context, m),
                          ),
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
                    onPressed: () async {
                      await widget.onAddExpense();
                      _load();
                    },
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

// ─── Profile Info Sheet ───────────────────────────────────────────────────────

class _ProfileInfoSheet extends StatefulWidget {
  final dynamic user;
  final dynamic room;
  const _ProfileInfoSheet({required this.user, this.room});

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
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
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
          if (widget.room != null && widget.room.ownerName.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Room Info',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Room Owner',
              value: widget.room.ownerName,
            ),
            if (widget.room.ownerEmail.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Owner Email',
                value: widget.room.ownerEmail,
              ),
            ],
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
