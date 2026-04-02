import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart'; // includes CurrencyText

class MemberSummaryScreen extends StatefulWidget {
  const MemberSummaryScreen({super.key});

  @override
  State<MemberSummaryScreen> createState() => _MemberSummaryScreenState();
}

class _MemberSummaryScreenState extends State<MemberSummaryScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _expandedMemberId;

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
            const Text('Unable to load summary',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final allMembers = (_summary!['memberSummary'] as List?) ?? [];
    final bills = (_summary!['monthlyBills'] ?? {}) as Map<String, dynamic>;
    final myShare = (_summary!['perPersonShare'] ?? 0).toDouble();
    final myContribution = (_summary!['myContribution'] ?? 0).toDouble();
    final balance = (_summary!['balance'] ?? 0).toDouble();
    final isPaid = _summary!['isPaid'] ?? false;
    final isFoodOptOut = !(_summary!['eatsFood'] ?? true);
    final myId = context.read<AuthProvider>().user?.id;

    // Bill breakdown calculations
    final memberCount = (_summary!['numberOfMembers'] ?? allMembers.length) as int;
    // +1 to include the owner in the food split
    final foodEaters = allMembers.where((m) => (m['eatsFood'] ?? true) as bool).length + 1;
    final rent = (bills['rent'] ?? 0).toDouble();
    final food = (bills['food'] ?? 0).toDouble();
    final electricity = (bills['electricity'] ?? 0).toDouble();
    final water = (bills['water'] ?? 0).toDouble();
    final rentShare = memberCount > 0 ? rent / memberCount : 0.0;
    final foodShare = (!isFoodOptOut && foodEaters > 0) ? food / foodEaters : 0.0;
    final electricityShare = memberCount > 0 ? electricity / memberCount : 0.0;
    final waterShare = memberCount > 0 ? water / memberCount : 0.0;

    final sym = context.read<RoomProvider>().currencySymbol;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPaid
                      ? [AppTheme.success, const Color(0xFF66BB6A)]
                      : balance > 0
                          ? [AppTheme.error, const Color(0xFFE57373)]
                          : balance < 0
                              ? [AppTheme.teal, const Color(0xFF26A69A)]
                              : [AppTheme.navy, AppTheme.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (isPaid || balance == 0)
                    Text(
                      isPaid ? 'PAID ✓' : 'Settled Up!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          balance > 0 ? 'You Owe  ' : 'You Receive  ',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15),
                        ),
                        CurrencyText(
                          symbol: sym,
                          amount: balance.abs().toStringAsFixed(2),
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Chip('Share: $sym${myShare.toStringAsFixed(0)}'),
                      const SizedBox(width: 8),
                      _Chip('Spent: $sym${myContribution.toStringAsFixed(0)}'),
                      if (isFoodOptOut) ...[
                        const SizedBox(width: 8),
                        _Chip('No Food'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // My bill breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Bill Breakdown',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    if (rent > 0)
                      _BillRow('Rent', rentShare,
                          '$sym${rent.toStringAsFixed(0)} ÷ $memberCount'),
                    if (food > 0)
                      isFoodOptOut
                          ? _BillRow('Food', 0, 'Opted out', optOut: true)
                          : _BillRow('Food', foodShare,
                              '$sym${food.toStringAsFixed(0)} ÷ $foodEaters'),
                    if (electricity > 0)
                      _BillRow('Electricity', electricityShare,
                          '$sym${electricity.toStringAsFixed(0)} ÷ $memberCount'),
                    if (water > 0)
                      _BillRow('Water', waterShare,
                          '$sym${water.toStringAsFixed(0)} ÷ $memberCount'),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Share',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$sym${myShare.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('- Your Contributions',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        Text('$sym${myContribution.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppTheme.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('= Balance',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          balance >= 0
                              ? '$sym${balance.toStringAsFixed(2)}'
                              : '-$sym${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: balance > 0
                                  ? AppTheme.error
                                  : AppTheme.success,
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'All Members'),
            const SizedBox(height: 12),
            ...allMembers.map((m) {
              final mId = m['_id'] ?? '';
              final name = m['name'] ?? '';
              final contribution = (m['contribution'] ?? 0).toDouble();
              final share = (m['perPersonShare'] ?? 0).toDouble();
              final bal = (m['balance'] ?? 0).toDouble();
              final mPaid = m['isPaid'] ?? false;
              final mFoodOptOut = !(m['eatsFood'] ?? true);
              final isMe = mId == myId;
              final isExpanded = _expandedMemberId == mId;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isMe ? AppTheme.teal.withOpacity(0.05) : null,
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isMe ? AppTheme.teal : AppTheme.navy.withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: isMe ? Colors.white : AppTheme.navy,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text('$name${isMe ? ' (You)' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (mFoodOptOut) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('No Food',
                                  style: TextStyle(
                                      color: AppTheme.error, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('Spent: $sym${contribution.toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          mPaid
                              ? const _PayChip('PAID', AppTheme.success)
                              : bal > 0
                                  ? _PayChip('Pay $sym${bal.toStringAsFixed(0)}', AppTheme.error)
                                  : bal < 0
                                      ? _PayChip('Get $sym${bal.abs().toStringAsFixed(0)}', AppTheme.teal)
                                      : const _PayChip('Settled', AppTheme.textSecondary),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() =>
                                _expandedMemberId = isExpanded ? null : mId),
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          children: [
                            const Divider(),
                            if (rent > 0)
                              _BillRowSmall('Rent',
                                  memberCount > 0 ? rent / memberCount : 0,
                                  '÷ $memberCount members'),
                            if (food > 0)
                              mFoodOptOut
                                  ? const _BillRowSmall(
                                      'Food', 0, 'opted out',
                                      optOut: true)
                                  : _BillRowSmall(
                                      'Food',
                                      foodEaters > 0 ? food / foodEaters : 0,
                                      '÷ $foodEaters eaters'),
                            if (electricity > 0)
                              _BillRowSmall('Electricity',
                                  memberCount > 0 ? electricity / memberCount : 0,
                                  '÷ $memberCount members'),
                            if (water > 0)
                              _BillRowSmall('Water',
                                  memberCount > 0 ? water / memberCount : 0,
                                  '÷ $memberCount members'),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Share',
                                    style: TextStyle(color: AppTheme.textSecondary)),
                                Text('$sym${share.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Contributed',
                                    style: TextStyle(color: AppTheme.textSecondary)),
                                Text('$sym${contribution.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppTheme.success)),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;
  final String calc;
  final bool optOut;

  const _BillRow(this.label, this.amount, this.calc, {this.optOut = false});

  @override
  Widget build(BuildContext context) {
    final sym = context.read<RoomProvider>().currencySymbol;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary))),
          Text(calc,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            optOut ? 'Opted out' : '$sym${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: optOut ? AppTheme.textSecondary : AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _BillRowSmall extends StatelessWidget {
  final String label;
  final double amount;
  final String calc;
  final bool optOut;

  const _BillRowSmall(this.label, this.amount, this.calc, {this.optOut = false});

  @override
  Widget build(BuildContext context) {
    final sym = context.read<RoomProvider>().currencySymbol;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13))),
          Text(calc,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 8),
          Text(
            optOut ? 'opted out' : '$sym${amount.toStringAsFixed(0)}',
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

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _PayChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PayChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
