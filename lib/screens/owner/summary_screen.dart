import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'carry_forward_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String? _selectedMonth;
  List<String> _availableMonths = [];
  final _shareKey = GlobalKey();
  final _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<RoomProvider>();
      await prov.fetchSummary();
      final months = await prov.fetchSummaryMonths();
      if (mounted) setState(() => _availableMonths = months);
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    if (_availableMonths.isEmpty) return;
    final current = _selectedMonth ?? context.read<RoomProvider>().room?.billingMonth;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              Icon(Icons.calendar_month_outlined, color: AppTheme.navy),
              SizedBox(width: 10),
              Text('Select Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(),
          ...(_availableMonths.map((m) => ListTile(
            title: Text(_formatMonth(m),
                style: TextStyle(
                    fontWeight: m == (current) ? FontWeight.bold : FontWeight.normal,
                    color: m == (current) ? AppTheme.teal : AppTheme.textPrimary)),
            trailing: m == (current) ? const Icon(Icons.check, color: AppTheme.teal) : null,
            onTap: () {
              Navigator.pop(ctx);
              if (m != _selectedMonth) {
                setState(() => _selectedMonth = m);
                context.read<RoomProvider>().fetchSummary(month: m);
              }
            },
          ))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _shareReport(BuildContext context, String month) async {
    try {
      final roomProv = context.read<RoomProvider>();
      final summary = roomProv.summary;
      final room = roomProv.room;
      if (summary == null) return;

      final sym = roomProv.currencySymbol;
      final roomName = room?.name ?? 'Room';

      // Render the report card off-screen
      final repaintKey = GlobalKey();
      final widget = RepaintBoundary(
        key: repaintKey,
        child: _ReportCard(
          summary: summary,
          sym: sym,
          month: _formatMonth(month),
          roomName: roomName,
        ),
      );

      // Insert into overlay to render
      final overlayEntry = OverlayEntry(
        builder: (_) => Positioned(
          left: -2000,
          top: 0,
          child: MediaQuery(
            data: MediaQuery.of(context),
            child: widget,
          ),
        ),
      );
      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) { overlayEntry.remove(); return; }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      overlayEntry.remove();
      if (byteData == null) return;

      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/roommess_report.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'RoomMess Report - ${_formatMonth(month)}',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        showSnack(context, 'Share failed: $e', error: true);
      }
    }
  }

  String _formatMonth(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return ym;
    return '${months[m - 1]} ${parts[0]}';
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
    final totalContributions = (summary['memberExpensesTotal'] ?? 0).toDouble();
    final totalExpenses = totalBills + totalContributions;
    final memberCount = (room?.members.length ?? 0) + 1;
    final perPerson = memberCount > 0 ? totalExpenses / memberCount : 0.0;
    final transactionCount = expProv.expenses.length;
    final billingMonth = room?.billingMonth ?? '';
    final viewedMonth = (summary['room']?['viewedMonth'] as String?) ?? _selectedMonth ?? billingMonth;
    final sym = roomProv.currencySymbol;

    // Category data from summary monthlyBills (respects selected month snapshot)
    final billsMap = summary['monthlyBills'] as Map<String, dynamic>? ?? {};
    final utilities = ((billsMap['electricity'] ?? 0) as num).toDouble() + ((billsMap['water'] ?? 0) as num).toDouble();
    final food = ((billsMap['food'] ?? 0) as num).toDouble();
    final rent = ((billsMap['rent'] ?? 0) as num).toDouble();
    final other = totalContributions;

    final categories = <_CategoryData>[
      if (utilities > 0)
        _CategoryData(name: 'Utilities', value: utilities, color: AppTheme.teal),
      if (food > 0)
        _CategoryData(name: 'Food', value: food, color: const Color(0xFF26A69A)),
      if (rent > 0)
        _CategoryData(name: 'Rent', value: rent, color: AppTheme.warning),
      if (other > 0)
        _CategoryData(name: 'Other', value: other, color: const Color(0xFF9E9E9E)),
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
                      GestureDetector(
                        key: _shareKey,
                        onTap: () => _shareReport(context, viewedMonth),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF243560),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.share_outlined,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month selector
                  GestureDetector(
                    onTap: () => _pickMonth(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF243560),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              viewedMonth.isNotEmpty ? _formatMonth(viewedMonth) : 'Current Month',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ),
                          if (_selectedMonth != null && _selectedMonth != billingMonth)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.teal.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('History', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.expand_more, color: Colors.white54, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White Body ───────────────────────────────────────────────
          Expanded(
            child: RepaintBoundary(
              key: _captureKey,
              child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

                      // ── Carry-Forward Nav Card ───────────────────────
                      _CarryForwardNavCard(sym: sym),
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
                                child: _DonutChart(categories: categories, size: 160),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: categories
                                    .map((c) => _LegendDot(label: c.name, color: c.color))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Color(0xFFF0F0F0)),
                              const SizedBox(height: 12),
                              ...categories.map((c) => _CategoryRow(data: c)),
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
            ), // end RepaintBoundary child Container
          ),
        ],
      ),
    );
  }
}

// ─── Carry-Forward Tracker ────────────────────────────────────────────────────

// ─── Carry-Forward Nav Card ───────────────────────────────────────────────────

class _CarryForwardNavCard extends StatefulWidget {
  final String sym;
  const _CarryForwardNavCard({required this.sym});

  @override
  State<_CarryForwardNavCard> createState() => _CarryForwardNavCardState();
}

class _CarryForwardNavCardState extends State<_CarryForwardNavCard> {
  num _outstanding = 0;
  int _debtors = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<RoomProvider>().fetchCarryForwardHistory();
    if (mounted) setState(() {
      _outstanding = (data?['totalOutstanding'] ?? 0) as num;
      _debtors = (data?['membersWithDebt'] ?? 0) as int;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sym = widget.sym;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryForwardScreen()));
        _load(); // refresh preview on return
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history_edu_outlined, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Carry Forward',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              if (!_loaded)
                const Text('Loading...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
              else if (_outstanding > 0)
                Text(
                  '$sym${_outstanding.toStringAsFixed(0)} outstanding · $_debtors member${_debtors == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                )
              else
                const Text('All members up to date ✓',
                    style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
        ]),
      ),
    );
  }
}

class _CarryForwardTracker extends StatefulWidget {
  const _CarryForwardTracker();

  @override
  State<_CarryForwardTracker> createState() => _CarryForwardTrackerState();
}

class _CarryForwardTrackerState extends State<_CarryForwardTracker> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final data = await context.read<RoomProvider>().fetchCarryForwardHistory();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.read<RoomProvider>().currencySymbol;

    if (_loading) {
      return _Card(child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ));
    }

    final totalOutstanding = (_data?['totalOutstanding'] ?? 0.0) as num;
    final membersWithDebt = (_data?['membersWithDebt'] ?? 0) as int;
    final members = (_data?['members'] as List?) ?? [];
    final activeMembers = members.where((m) => (m['currentOutstanding'] ?? 0) > 0 || (m['entries'] as List).isNotEmpty).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_edu_outlined, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Carry-Forward Tracker',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ),
            if (totalOutstanding > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$sym${totalOutstanding.toStringAsFixed(0)} owed',
                    style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 16),

          // Empty state
          if (activeMembers.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: const Column(children: [
                Icon(Icons.check_circle_outline, color: AppTheme.success, size: 32),
                SizedBox(height: 8),
                Text('No outstanding debts', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('All members are up to date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
          ] else ...[
            // Stats
            if (totalOutstanding > 0) ...[
              Row(children: [
                Expanded(child: _CFStat(label: 'Outstanding', value: '$sym${totalOutstanding.toStringAsFixed(0)}', color: Colors.orange)),
                Container(width: 1, height: 28, color: const Color(0xFFF0F0F0)),
                Expanded(child: _CFStat(label: 'Members in Debt', value: '$membersWithDebt', color: AppTheme.error)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 12),
            ],

            // Member entries
            ...activeMembers.map((m) => _CFMemberRow(data: m, sym: sym, onRefresh: _load)),
          ],
        ],
      ),
    );
  }
}

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

class _CFStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CFStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _CFMemberRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sym;
  final Future<void> Function() onRefresh;
  const _CFMemberRow({required this.data, required this.sym, required this.onRefresh});

  @override
  State<_CFMemberRow> createState() => _CFMemberRowState();
}

class _CFMemberRowState extends State<_CFMemberRow> {
  void _showPaySheet() {
    final data = widget.data;
    final sym = widget.sym;
    final memberId = (data['memberId'] ?? '') as String;
    final outstanding = (data['currentOutstanding'] ?? 0.0) as num;
    final partialPaid = (data['partialPaid'] ?? 0.0) as num;
    final isEditing = partialPaid > 0;
    final ctrl = TextEditingController(text: isEditing ? partialPaid.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool loading = false;
        bool clearLoading = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_outlined, color: Colors.purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isEditing ? 'Edit Payment' : 'Record Payment',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text((data['name'] ?? '') as String,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ]),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: clearLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.error))
                          : const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: 'Remove payment',
                      onPressed: clearLoading || loading ? null : () async {
                        setS(() => clearLoading = true);
                        final ok = await context.read<RoomProvider>().clearPartialPay(memberId);
                        setS(() => clearLoading = false);
                        if (context.mounted) Navigator.pop(ctx);
                        await widget.onRefresh();
                        if (context.mounted) {
                          showSnack(context, ok ? 'Payment removed' : (context.read<RoomProvider>().error ?? 'Failed'), error: !ok);
                        }
                      },
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _InfoPill(label: 'Outstanding', value: '$sym${outstanding.toStringAsFixed(0)}', color: Colors.orange),
                  if (partialPaid > 0) ...[
                    const SizedBox(width: 8),
                    _InfoPill(label: 'Recorded', value: '$sym${partialPaid.toStringAsFixed(0)}', color: AppTheme.success),
                  ],
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Update amount received' : 'Amount received',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    hintText: '$sym${outstanding.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(height: 16),
                LoadingButton(
                  loading: loading,
                  onPressed: () async {
                    final amt = double.tryParse(ctrl.text.trim());
                    if (amt == null || amt <= 0) return;
                    setS(() => loading = true);
                    if (isEditing) {
                      await context.read<RoomProvider>().clearPartialPay(memberId);
                    }
                    final ok = await context.read<RoomProvider>().partialPay(memberId, amt);
                    setS(() => loading = false);
                    if (context.mounted) Navigator.pop(ctx);
                    await widget.onRefresh();
                    if (context.mounted) {
                      showSnack(context, ok ? (isEditing ? 'Payment updated!' : 'Payment recorded!') : (context.read<RoomProvider>().error ?? 'Failed'), error: !ok);
                    }
                  },
                  label: isEditing ? 'Update Payment' : 'Record Payment',
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
    final data = widget.data;
    final sym = widget.sym;
    final name = (data['name'] ?? '') as String;
    final outstanding = (data['currentOutstanding'] ?? 0.0) as num;
    final totalCarried = (data['totalCarried'] ?? 0.0) as num;
    final partialPaid = (data['partialPaid'] ?? 0.0) as num;
    final entries = (data['entries'] as List?) ?? [];
    final hasDebt = outstanding > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDebt ? Colors.orange.withOpacity(0.04) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDebt ? Colors.orange.withOpacity(0.25) : const Color(0xFFE8EBF0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member header
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: hasDebt ? Colors.orange.withOpacity(0.15) : AppTheme.success.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: hasDebt ? Colors.orange : AppTheme.success,
                    fontWeight: FontWeight.bold, fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                  Text(
                    hasDebt ? 'Owes $sym${outstanding.toStringAsFixed(0)}' : 'All cleared \u2713',
                    style: TextStyle(
                      color: hasDebt ? Colors.orange : AppTheme.success,
                      fontSize: 12, fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
              if (totalCarried > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Total carried: $sym${totalCarried.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              if (hasDebt) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _showPaySheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: partialPaid > 0 ? Colors.purple.withOpacity(0.1) : AppTheme.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: partialPaid > 0 ? Colors.purple.withOpacity(0.3) : AppTheme.teal.withOpacity(0.2),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        partialPaid > 0 ? Icons.edit_outlined : Icons.payments_outlined,
                        size: 13,
                        color: partialPaid > 0 ? Colors.purple : AppTheme.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        partialPaid > 0 ? '$sym${partialPaid.toStringAsFixed(0)} paid' : 'Pay',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: partialPaid > 0 ? Colors.purple : AppTheme.teal,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),

            // Partial payment note
            if (hasDebt && partialPaid > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 13, color: Colors.purple),
                  const SizedBox(width: 6),
                  Text(
                    '$sym${partialPaid.toStringAsFixed(0)} received · $sym${(outstanding - partialPaid).toStringAsFixed(0)} still pending',
                    style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],

            // History timeline
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...entries.map((e) {
                final isActive = e['isActive'] == true;
                final month = e['month'] as String;
                final amount = (e['amount'] as num).toDouble();
                final clearedIn = e['clearedInMonth'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Column(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.orange : AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(children: [
                        Text(_formatMonth(month),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('$sym${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isActive ? Colors.orange : AppTheme.textSecondary,
                              fontSize: 12, fontWeight: FontWeight.w600,
                            )),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.orange.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Cleared ${clearedIn != null ? _formatMonth(clearedIn) : ""}',
                        style: TextStyle(
                          color: isActive ? Colors.orange : AppTheme.success,
                          fontSize: 10, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMonth(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return ym;
    return '${months[m - 1]} ${parts[0]}';
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
    final sym = context.read<RoomProvider>().currencySymbol;
    return _Card(
      child: Column(
        children: [
          const Text('Total Expenses',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          CurrencyText(
            symbol: sym,
            amount: total.toStringAsFixed(0),
            fontSize: 36,
            color: AppTheme.textPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Per Person',
                  value: '$sym${perPerson.toStringAsFixed(0)}',
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFF0F0F0)),
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
    final sym = context.read<RoomProvider>().currencySymbol;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(data.name,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Text(
            '$sym${data.value.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
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
    final sym = context.read<RoomProvider>().currencySymbol;
    final name = data['name'] ?? '';
    final contribution = (data['contribution'] ?? 0).toDouble();
    final share = (data['perPersonShare'] ?? 0).toDouble();
    final delta = contribution - share;
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
              Text('$sym${contribution.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EBF0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.teal),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(1)}% of total',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                delta >= 0
                    ? '+$sym${delta.toStringAsFixed(0)}'
                    : '-$sym${delta.abs().toStringAsFixed(0)}',
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
            width: 10, height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
  const _CategoryData({required this.name, required this.value, required this.color});
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
    const gap = 0.03;

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

// ─── Report Card (for sharing) ────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String sym;
  final String month;
  final String roomName;

  const _ReportCard({
    required this.summary,
    required this.sym,
    required this.month,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    final members = (summary['memberSummary'] as List?) ?? [];
    final totalExpense = (summary['totalRoomExpense'] ?? 0).toDouble();
    final fixedBills = (summary['fixedBillsTotal'] ?? 0).toDouble();
    final purchases = (summary['memberExpensesTotal'] ?? 0).toDouble();
    final billsMap = summary['monthlyBills'] as Map<String, dynamic>? ?? {};
    final rent = (billsMap['rent'] ?? 0).toDouble();
    final food = (billsMap['food'] ?? 0).toDouble();
    final electricity = (billsMap['electricity'] ?? 0).toDouble();
    final water = (billsMap['water'] ?? 0).toDouble();

    final paidCount = members.where((m) => m['isPaid'] == true).length;
    final unpaidCount = members.length - paidCount;

    const navy = Color(0xFF1A2B5E);
    const teal = Color(0xFF26A69A);
    const bg = Color(0xFFF0F2F8);

    return Container(
      width: 420,
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header banner ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2B5E), Color(0xFF243A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App + room row
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('RM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text('RoomMess · Monthly Report', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(month, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 20),
                // Total amount
                const Text('Total Room Expense', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text('$sym${totalExpense.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, height: 1)),
                const SizedBox(height: 16),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    _HStatItem(label: 'Fixed Bills', value: '$sym${fixedBills.toStringAsFixed(0)}'),
                    _HDivider(),
                    _HStatItem(label: 'Purchases', value: '$sym${purchases.toStringAsFixed(0)}'),
                    _HDivider(),
                    _HStatItem(label: 'Members', value: '${members.length}'),
                    _HDivider(),
                    _HStatItem(label: 'Paid', value: '$paidCount/${ members.length}', valueColor: paidCount == members.length ? const Color(0xFF66BB6A) : Colors.white),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Bill Breakdown ─────────────────────────────────────────
          _RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RSectionHeader(icon: Icons.receipt_long_outlined, title: 'Bill Breakdown', color: navy),
                const SizedBox(height: 14),
                // Grid of bill items
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (rent > 0) _BillChip(label: 'Rent', value: '$sym${rent.toStringAsFixed(0)}', color: navy),
                    if (food > 0) _BillChip(label: 'Food', value: '$sym${food.toStringAsFixed(0)}', color: teal),
                    if (electricity > 0) _BillChip(label: 'Electricity', value: '$sym${electricity.toStringAsFixed(0)}', color: const Color(0xFFF57C00)),
                    if (water > 0) _BillChip(label: 'Water', value: '$sym${water.toStringAsFixed(0)}', color: const Color(0xFF29B6F6)),
                    if (purchases > 0) _BillChip(label: 'Purchases', value: '$sym${purchases.toStringAsFixed(0)}', color: const Color(0xFF7E57C2)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: const Color(0xFFE8EBF0)),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A2332))),
                  const Spacer(),
                  Text('$sym${totalExpense.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: teal)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Member Balances ────────────────────────────────────────
          _RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _RSectionHeader(icon: Icons.people_outline, title: 'Member Balances', color: navy),
                  const Spacer(),
                  if (paidCount > 0) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('$paidCount paid', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  if (unpaidCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('$unpaidCount pending', style: const TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                const SizedBox(height: 14),
                ...members.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final name = (m['name'] ?? '') as String;
                  final share = (m['perPersonShare'] ?? 0).toDouble();
                  final contribution = (m['contribution'] ?? 0).toDouble();
                  final balance = (m['balance'] ?? 0).toDouble();
                  final isPaid = m['isPaid'] == true;
                  final carry = (m['carryForward'] ?? 0).toDouble();
                  final partial = (m['partialPaid'] ?? 0).toDouble();
                  final isLast = i == members.length - 1;

                  return Column(
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isPaid
                              ? const Color(0xFF4CAF50).withOpacity(0.12)
                              : const Color(0xFF1A2B5E).withOpacity(0.08),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isPaid ? const Color(0xFF4CAF50) : navy,
                              fontWeight: FontWeight.bold, fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + detail
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A2332))),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text('Share $sym${share.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF8A9BB0), fontSize: 11)),
                              if (contribution > 0) ...[
                                const Text('  ·  ', style: TextStyle(color: Color(0xFF8A9BB0), fontSize: 11)),
                                Text('Contrib $sym${contribution.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF7E57C2), fontSize: 11)),
                              ],
                              if (carry > 0) ...[
                                const Text('  ·  ', style: TextStyle(color: Color(0xFF8A9BB0), fontSize: 11)),
                                Text('Carry $sym${carry.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.orange, fontSize: 11)),
                              ],
                            ]),
                          ],
                        )),
                        // Status
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                            ),
                            child: const Text('PAID ✓', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        else
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: balance > 0
                                    ? const Color(0xFFE53935).withOpacity(0.08)
                                    : const Color(0xFF4CAF50).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: balance > 0
                                      ? const Color(0xFFE53935).withOpacity(0.3)
                                      : const Color(0xFF4CAF50).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                balance > 0 ? 'Owes $sym${balance.toStringAsFixed(0)}' : 'Settled',
                                style: TextStyle(
                                  color: balance > 0 ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
                                  fontSize: 12, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (partial > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text('paid $sym${partial.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF7E57C2), fontSize: 10)),
                              ),
                          ]),
                      ]),
                      if (!isLast) ...[
                        const SizedBox(height: 8),
                        Container(height: 1, color: const Color(0xFFF0F2F5)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Footer
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 18, height: 18,
              decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(4)),
              child: const Center(child: Text('RM', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 6),
            Text('RoomMess · $month', style: const TextStyle(color: Color(0xFF8A9BB0), fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

class _HStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _HStatItem({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
  ]));
}

class _HDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: Colors.white12);
}

class _BillChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BillChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );
}

class _RSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _RSectionHeader({required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 6),
    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
  ]);
}

class _RCard extends StatelessWidget {
  final Widget child;
  const _RCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

class _RLabel extends StatelessWidget {
  final String text;
  const _RLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2332)));
}

class _RRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _RRow(this.label, this.value, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF1A2332), fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
    ]),
  );
}
