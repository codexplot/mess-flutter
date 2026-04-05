import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/room_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class CarryForwardScreen extends StatefulWidget {
  const CarryForwardScreen({super.key});

  @override
  State<CarryForwardScreen> createState() => _CarryForwardScreenState();
}

class _CarryForwardScreenState extends State<CarryForwardScreen> {
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
    final totalOutstanding = (_data?['totalOutstanding'] ?? 0.0) as num;
    final membersWithDebt = (_data?['membersWithDebt'] ?? 0) as int;
    final members = (_data?['members'] as List?) ?? [];
    final activeMembers = members
        .where((m) => (m['currentOutstanding'] ?? 0) > 0 || (m['entries'] as List).isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Carry Forward',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Track & manage outstanding debts',
                            style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (!_loading)
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats bar
                            if (totalOutstanding > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.history_edu_outlined, color: Colors.orange, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('$sym${totalOutstanding.toStringAsFixed(0)} outstanding',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        Text('$membersWithDebt member${membersWithDebt == 1 ? '' : 's'} with unpaid carry-forward',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Empty state
                            if (activeMembers.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 48),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: const Column(children: [
                                  Icon(Icons.check_circle_outline, color: AppTheme.success, size: 48),
                                  SizedBox(height: 12),
                                  Text('No outstanding debts',
                                      style: TextStyle(color: AppTheme.success, fontSize: 16, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 6),
                                  Text('All members are up to date',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ]),
                              )
                            else
                              ...activeMembers.map((m) => _MemberDebtCard(
                                data: m,
                                sym: sym,
                                onRefresh: _load,
                              )),
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

// ─── Member Debt Card ─────────────────────────────────────────────────────────

class _MemberDebtCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sym;
  final Future<void> Function() onRefresh;
  const _MemberDebtCard({required this.data, required this.sym, required this.onRefresh});

  @override
  State<_MemberDebtCard> createState() => _MemberDebtCardState();
}

class _MemberDebtCardState extends State<_MemberDebtCard> {
  bool _expanded = false;

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
                      showSnack(context,
                          ok ? (isEditing ? 'Payment updated!' : 'Payment recorded!') : (context.read<RoomProvider>().error ?? 'Failed'),
                          error: !ok);
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
    final remaining = outstanding - partialPaid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
          border: Border.all(
            color: hasDebt ? Colors.orange.withOpacity(0.2) : AppTheme.success.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            // ── Header row ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: hasDebt ? Colors.orange.withOpacity(0.15) : AppTheme.success.withOpacity(0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: hasDebt ? Colors.orange : AppTheme.success,
                        fontWeight: FontWeight.bold, fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                      if (hasDebt)
                        Text(
                          partialPaid > 0
                              ? '$sym${partialPaid.toStringAsFixed(0)} paid · $sym${remaining.toStringAsFixed(0)} left'
                              : 'Owes $sym${outstanding.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: partialPaid > 0 ? Colors.purple : Colors.orange,
                            fontSize: 12, fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        const Text('All cleared ✓',
                            style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  if (hasDebt) ...[
                    GestureDetector(
                      onTap: _showPaySheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: partialPaid > 0 ? Colors.purple.withOpacity(0.1) : AppTheme.teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: partialPaid > 0 ? Colors.purple.withOpacity(0.3) : AppTheme.teal.withOpacity(0.2),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            partialPaid > 0 ? Icons.edit_outlined : Icons.payments_outlined,
                            size: 14,
                            color: partialPaid > 0 ? Colors.purple : AppTheme.teal,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            partialPaid > 0 ? 'Edit' : 'Pay',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: partialPaid > 0 ? Colors.purple : AppTheme.teal,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (entries.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            // ── Partial payment progress bar ─────────────────────
            if (hasDebt && partialPaid > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (partialPaid / outstanding).clamp(0.0, 1.0).toDouble(),
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Received: $sym${partialPaid.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.w500)),
                        Text('Remaining: $sym${remaining.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── History timeline (expandable) ────────────────────
            if (entries.isNotEmpty && _expanded) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.history, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      const Text('History',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      if (totalCarried > 0) ...[
                        const Spacer(),
                        Text('Total carried: $sym${totalCarried.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    ...entries.map((e) {
                      final isActive = e['isActive'] == true;
                      final month = e['month'] as String;
                      final amount = (e['amount'] as num).toDouble();
                      final clearedIn = e['clearedInMonth'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Column(children: [
                            Container(
                              width: 9, height: 9,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                ),
              ),
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

// ─── Info Pill ────────────────────────────────────────────────────────────────

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
