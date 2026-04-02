import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _AdminDashboard(),
      const _ManageUsers(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(roomProvider: context.read<RoomProvider>(), expenseProvider: context.read<ExpenseProvider>()),
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
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Users'),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ───────────────────────────────────────────────────────────

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  Map<String, dynamic>? _stats;
  List<dynamic> _recentUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final statsRes = await ApiService.get('/admin/stats');
    final usersRes = await ApiService.get('/admin/users');
    if (mounted) {
      setState(() {
        if (statsRes['success']) _stats = statsRes['data'];
        if (usersRes['success']) {
          final all = usersRes['data'] as List;
          _recentUsers = all.take(5).toList();
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  label: 'Total Users',
                  value: '${_stats?['totalUsers'] ?? 0}',
                  icon: Icons.people,
                  color: AppTheme.navy,
                ),
                InfoCard(
                  label: 'Room Owners',
                  value: '${_stats?['totalOwners'] ?? 0}',
                  icon: Icons.admin_panel_settings,
                  color: AppTheme.teal,
                ),
                InfoCard(
                  label: 'Members',
                  value: '${_stats?['totalMembers'] ?? 0}',
                  icon: Icons.person,
                  color: AppTheme.success,
                ),
                InfoCard(
                  label: 'Total Rooms',
                  value: '${_stats?['totalRooms'] ?? 0}',
                  icon: Icons.home,
                  color: AppTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Recent Users'),
            const SizedBox(height: 12),
            ..._recentUsers.map((u) => _UserTile(user: u, onDeleted: _load)),
          ],
        ),
      ),
    );
  }
}

// ─── Manage Users Tab ────────────────────────────────────────────────────────

class _ManageUsers extends StatefulWidget {
  const _ManageUsers();

  @override
  State<_ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<_ManageUsers> {
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/admin/users');
    if (mounted) {
      setState(() {
        if (res['success']) _users = res['data'];
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _users.where((u) {
        final matchSearch = _search.isEmpty ||
            (u['name'] ?? '').toLowerCase().contains(_search.toLowerCase()) ||
            (u['email'] ?? '').toLowerCase().contains(_search.toLowerCase());
        final matchRole =
            _roleFilter == 'all' || u['role'] == _roleFilter;
        return matchSearch && matchRole;
      }).toList();
    });
  }

  void _showCreateOwner() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Room Owner',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 20),
                LoadingButton(
                  loading: loading,
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty ||
                        emailCtrl.text.isEmpty ||
                        passCtrl.text.isEmpty) {
                      showSnack(context, 'Fill all fields', error: true);
                      return;
                    }
                    setS(() => loading = true);
                    final res = await ApiService.post('/admin/create-owner', {
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'password': passCtrl.text,
                    });
                    setS(() => loading = false);
                    Navigator.pop(ctx);
                    if (res['success']) {
                      showSnack(context, 'Owner created!');
                      _load();
                    } else {
                      showSnack(context, res['message'] ?? 'Failed',
                          error: true);
                    }
                  },
                  label: 'Create Owner',
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
    return Column(
      children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _search = v;
                    _applyFilter();
                  },
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _roleFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                ],
                onChanged: (v) {
                  _roleFilter = v!;
                  _applyFilter();
                },
              ),
            ],
          ),
        ),

        // Create owner button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Create Room Owner'),
              onPressed: _showCreateOwner,
            ),
          ),
        ),

        // Users list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('No users found',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _UserTile(user: _filtered[i], onDeleted: _load),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── Shared User Tile ────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onDeleted;

  const _UserTile({required this.user, required this.onDeleted});

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'owner':
        return AppTheme.teal;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? '';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'member';
    final room = user['room'];
    final roomName = room is Map ? room['name'] : null;
    final createdAt = user['createdAt'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(user['createdAt']))
        : '';
    final isAdmin = role == 'admin';
    final color = _roleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style:
                  TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(role.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            Row(
              children: [
                if (roomName != null) ...[
                  const Icon(Icons.home_outlined,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(roomName,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(createdAt,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: isAdmin
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: () => _confirmDelete(context),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete "${user['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final res =
                  await ApiService.delete('/admin/users/${user['_id']}');
              if (context.mounted) {
                showSnack(
                  context,
                  res['success'] ? 'User deleted' : (res['message'] ?? 'Failed'),
                  error: !res['success'],
                );
                if (res['success']) onDeleted();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
