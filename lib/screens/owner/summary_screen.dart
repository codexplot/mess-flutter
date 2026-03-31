import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().fetchSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.watch<RoomProvider>();
    final expProv = context.watch<ExpenseProvider>();
    final summary = roomProv.summary;
    final room = roomProv.room;

    if (roomProv.loading) {
      return const Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (summary == null) {
      return Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No summary available',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => roomProv.fetchSummary(),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    final members = (summary['memberSummary'] as List?) ?? [];
    final totalBills = (summary['fixedBillsTotal'] ?? 0).toDouble();
    final totalContributions =
        (summary['memberExpensesTotal'] ?? 0).toDouble();
    final totalExpenses = totalBills + totalContributions;
    final memberCount = (room?.members.length ?? 0) + 1;
    final perPerson = memberCount > 0 ? totalExpenses / memberCount : 0.0;
    final transactionCount = expProv.expenses.length;
    final billingMonth = room?.billingMonth ?? '';

    // Category data from monthly bills
    final bills = room?.monthlyBills;
    final utilities = (bills?.electricity ?? 0) + (bills?.water ?? 0);
    final food = bills?.food ?? 0;
    final rent = bills?.rent ?? 0;
    final other = totalContributions;

    final categories = <_CategoryData>[
      if (utilities > 0)
        _CategoryData(
            name: 'Utilities', value: utilities, color: AppTheme.teal),
      if (food > 0)
        _CategoryData(
            name: 'Food', value: food, color: const Color(0xFF26A69A)),
      if (rent > 0)
        _CategoryData(
            name: 'Rent', value: rent, color: AppTheme.warning),
      if (other > 0)
        _CategoryData(
            name: 'Other', value: other, color: const Color(0xFF9E9E9E)),
    ];

    // Max contribution for progress bar scaling
    final maxContrib = members.isEmpty
        ? 1.0
        : members
            .map<double>((m) => (m['contribution'] ?? 0).toDouble())
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

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
                  Row(
                    children: [
                      const Text(
                        'Monthly Summary',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF243560),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.download_outlined,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month selector
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF243560),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          billingMonth.isNotEmpty
                              ? billingMonth
                              : 'Current Month',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ],
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
              child: RefreshIndicator(
                onRefresh: () => roomProv.fetchSummary(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Expenses card
                      _TotalCard(
                        total: totalExpenses,
                        perPerson: perPerson,
                        transactions: transactionCount,
                      ),
                      const SizedBox(height: 16),

                      // Category Breakdown
                      if (categories.isNotEmpty) ...[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Category Breakdown',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: _DonutChart(
                                    categories: categories, size: 160),
                              ),
                              const SizedBox(height: 16),
                              // Legend
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: categories
                                    .map((c) => _LegendDot(
                                        label: c.name, color: c.color))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(
                                  height: 1, color: Color(0xFFF0F0F0)),
                              const SizedBox(height: 12),
                              // Category rows
                              ...categories.map(
                                  (c) => _CategoryRow(data: c)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Member Contributions
                      if (members.isNotEmpty) ...[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Member Contributions',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 16),
                              ...members.map((m) => _ContributionRow(
                                    data: m,
                                    maxContrib: maxContrib,
                                    total: totalExpenses,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Total Card ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final double perPerson;
  final int transactions;

  const _TotalCard({
    required this.total,
    required this.perPerson,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          const Text('Total Expenses',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₹${total.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Per Person',
                  value: '₹${perPerson.toStringAsFixed(0)}',
                ),
              ),
              Container(
                  width: 1, height: 32, color: const Color(0xFFF0F0F0)),
              Expanded(
                child: _StatItem(
                  label: 'Transactions',
                  value: '$transactions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ─── Category Row ─────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final _CategoryData data;
  const _CategoryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: data.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(data.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Text(
            '₹${data.value.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Contribution Row ─────────────────────────────────────────────────────────

class _ContributionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final double maxContrib;
  final double total;

  const _ContributionRow({
    required this.data,
    required this.maxContrib,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final contribution = (data['contribution'] ?? 0).toDouble();
    final share = (data['perPersonShare'] ?? 0).toDouble();
    final delta = contribution - share; // positive = overpaid, negative = owes
    final pct = total > 0 ? (contribution / total * 100) : 0.0;
    final progress = maxContrib > 0 ? (contribution / maxContrib) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontSize: 14)),
              Text('₹${contribution.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EBF0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.teal),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(1)}% of total',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                delta >= 0
                    ? '+₹${delta.toStringAsFixed(0)}'
                    : '-₹${delta.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  color: delta >= 0 ? AppTheme.success : AppTheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

// ─── Card Wrapper ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }
}

// ─── Category Data ────────────────────────────────────────────────────────────

class _CategoryData {
  final String name;
  final double value;
  final Color color;
  const _CategoryData(
      {required this.name, required this.value, required this.color});
}

// ─── Donut Chart (CustomPainter) ──────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final List<_CategoryData> categories;
  final double size;

  const _DonutChart({required this.categories, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(categories: categories),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_CategoryData> categories;
  _DonutPainter({required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final total = categories.fold(0.0, (s, c) => s + c.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 28.0;
    const gap = 0.03; // radians between segments

    double startAngle = -pi / 2;

    for (final cat in categories) {
      final sweepAngle = (cat.value / total) * 2 * pi;
      final paint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweepAngle - gap,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => false;
}
