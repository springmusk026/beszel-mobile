import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';

class ContainerDetailsScreen extends StatefulWidget {
  const ContainerDetailsScreen({
    super.key,
    required this.systemId,
    required this.containerId,
    required this.containerName,
  });

  final String systemId;
  final String containerId;
  final String containerName;

  @override
  State<ContainerDetailsScreen> createState() => _ContainerDetailsScreenState();
}

class _ContainerDetailsScreenState extends State<ContainerDetailsScreen> {
  String? _logs;
  String? _info;
  bool _loadingLogs = false;
  bool _loadingInfo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadLogs(), _loadInfo()]);
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loadingLogs = true;
      _error = null;
    });
    try {
            final response = await pb.send<Map<String, dynamic>>(
              '/api/beszel/containers/logs',
              query: {
                'system': widget.systemId,
                'container': widget.containerId,
              },
            );
      setState(() {
        _logs = response['logs'] as String?;
        _loadingLogs = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load logs: $e';
        _loadingLogs = false;
      });
    }
  }

  Future<void> _loadInfo() async {
    setState(() {
      _loadingInfo = true;
    });
    try {
            final response = await pb.send<Map<String, dynamic>>(
              '/api/beszel/containers/info',
              query: {
                'system': widget.systemId,
                'container': widget.containerId,
              },
            );
      String info = response['info'] as String? ?? '';
      // Try to format as JSON if possible
      try {
        final parsed = jsonDecode(info);
        info = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (_) {
        // Not JSON, use as-is
      }
      setState(() {
        _info = info;
        _loadingInfo = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load info: $e';
        _loadingInfo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.containerName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.description), text: 'Logs'),
              Tab(icon: Icon(Icons.info), text: 'Details'),
            ],
          ),
          actions: [
            if (_loadingLogs || _loadingInfo)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
          ],
        ),
        body: _error != null && _logs == null && _info == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  _LogsView(logs: _logs, loading: _loadingLogs, onRefresh: _loadLogs),
                  _InfoView(info: _info, loading: _loadingInfo),
                ],
              ),
      ),
    );
  }
}

class _LogsView extends StatelessWidget {
  const _LogsView({required this.logs, required this.loading, required this.onRefresh});

  final String? logs;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && logs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (logs == null || logs!.isEmpty) {
      return const Center(child: Text('No logs available'));
    }
    return Container(
      color: Colors.black87,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          logs!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _InfoView extends StatelessWidget {
  const _InfoView({required this.info, required this.loading});

  final String? info;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && info == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (info == null || info!.isEmpty) {
      return const Center(child: Text('No info available'));
    }
    return Container(
      color: Colors.black87,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          info!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

