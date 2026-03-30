import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RoomProvider>().fetchSummary());
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.watch<RoomProvider>();
    final summary = roomProv.summary;

    if (roomProv.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No summary available',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => roomProv.fetchSummary(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final members = (summary['memberSummary'] as List?) ?? [];
    final totalBills = (summary['fixedBillsTotal'] ?? 0).toDouble();
    final totalContributions = (summary['memberExpensesTotal'] ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: () => roomProv.fetchSummary(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                InfoCard(
                  label: 'Total Bills',
                  value: '₹${totalBills.toStringAsFixed(0)}',
                  icon: Icons.receipt,
                  color: AppTheme.navy,
                ),
                InfoCard(
                  label: 'Contributions',
                  value: '₹${totalContributions.toStringAsFixed(0)}',
                  icon: Icons.savings,
                  color: AppTheme.teal,
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SectionHeader(title: 'Member Balances'),
            const SizedBox(height: 12),
            ...members.map((m) => _MemberBalance(data: m)),
          ],
        ),
      ),
    );
  }
}

class _MemberBalance extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MemberBalance({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final share = (data['perPersonShare'] ?? 0).toDouble();
    final contribution = (data['contribution'] ?? 0).toDouble();
    final balance = (data['balance'] ?? 0).toDouble();
    final isPaid = data['isPaid'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.teal.withOpacity(0.15),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppTheme.teal, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (isPaid)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PAID',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _StatItem(label: 'Share', value: '₹${share.toStringAsFixed(0)}'),
                _StatItem(
                    label: 'Contributed',
                    value: '₹${contribution.toStringAsFixed(0)}'),
                _StatItem(
                  label: balance >= 0 ? 'Owes' : 'Overpaid',
                  value: '₹${balance.abs().toStringAsFixed(0)}',
                  color: balance > 0
                      ? AppTheme.error
                      : (balance < 0 ? AppTheme.success : AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
