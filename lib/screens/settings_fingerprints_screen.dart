import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/fingerprints_service.dart';
import '../services/universal_token_service.dart';

class SettingsFingerprintsScreen extends StatefulWidget {
  const SettingsFingerprintsScreen({super.key});

  @override
  State<SettingsFingerprintsScreen> createState() => _SettingsFingerprintsScreenState();
}

class _SettingsFingerprintsScreenState extends State<SettingsFingerprintsScreen> {
  final _svc = FingerprintsService();
  final _universalSvc = UniversalTokenService();
  late Future<List<RecordModel>> _future;
  Future<UniversalTokenState>? _universalFuture;
  UniversalTokenState? _universal;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchAll();
    _universalFuture = _universalSvc.getState().then((s) => _universal = s);
  }

  Future<void> _rotateToken(RecordModel r) async {
    final newToken = _generateToken(24);
    await _svc.rotateToken(r.id, newToken);
    setState(() => _future = _svc.fetchAll());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token rotated')));
  }

  Future<void> _clearFingerprint(RecordModel r) async {
    await _svc.clearFingerprint(r.id);
    setState(() => _future = _svc.fetchAll());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fingerprint cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tokens & Fingerprints')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _svc.fetchAll());
          await _future;
          setState(() => _universalFuture = _universalSvc.getState().then((s) => _universal = s));
          await _universalFuture;
        },
        child: FutureBuilder<List<RecordModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load tokens/fingerprints'));
            }
            final items = snapshot.data ?? const <RecordModel>[];
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildUniversalCard(context);
                }
                final r = items[index - 1];
                final systemName = r.data['expand']?['system']?['name']?.toString() ?? r.data['system']?.toString() ?? '';
                final token = r.data['token']?.toString() ?? '';
                final fp = r.data['fingerprint']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.key)),
                    title: Text(systemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mono('Token', token),
                          const SizedBox(height: 4),
                          _mono('Fingerprint', fp.isEmpty ? '—' : fp),
                        ],
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rotate') _rotateToken(r);
                        if (value == 'clear') _clearFingerprint(r);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rotate', child: Text('Rotate token')),
                        const PopupMenuItem(value: 'clear', child: Text('Delete fingerprint')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUniversalCard(BuildContext context) {
    return FutureBuilder<UniversalTokenState>(
      future: _universalFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting && _universal == null;
        final state = _universal;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Universal token', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'When enabled, agents can self-register with this token. It expires on hub restart or after one hour.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else
                  Row(
                    children: [
                      Switch(
                        value: state?.active == true,
                        onChanged: (val) async {
                          final newState = await _universalSvc.setActive(val, token: state?.token ?? '');
                          setState(() => _universal = newState);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(state?.token ?? '—', style: const TextStyle(fontFamily: 'monospace')),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy token',
                        onPressed: (state?.token.isNotEmpty ?? false)
                            ? () async {
                                await Clipboard.setData(ClipboardData(text: state!.token));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied')));
                              }
                            : null,
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mono(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      ],
    );
  }

  String _generateToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[(chars.length * (i * 2654435761 % 4294967296) / 4294967296).floor() % chars.length]);
    }
    return buf.toString();
  }
}


