import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../api/pb_client.dart';
import '../models/system_record.dart';
import '../services/public_key_service.dart';

enum _InstallMode { docker, binary }

class AddSystemScreen extends StatefulWidget {
  const AddSystemScreen({super.key, this.system});

  final SystemRecord? system;

  @override
  State<AddSystemScreen> createState() => _AddSystemScreenState();
}

class _AddSystemScreenState extends State<AddSystemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '45876');
  _InstallMode _installMode = _InstallMode.docker;
  String? _publicKey;
  String? _token;
  bool _loading = false;
  bool _loadingKey = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.system != null) {
      _nameController.text = widget.system!.name;
      _hostController.text = widget.system!.host ?? '';
      _portController.text = widget.system!.port?.toString() ?? '45876';
      _loadToken();
    } else {
      _token = PublicKeyService.generateToken();
    }
    _loadPublicKey();
  }

  Future<void> _loadPublicKey() async {
    try {
      final key = await PublicKeyService().getPublicKey();
      setState(() {
        _publicKey = key;
        _loadingKey = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load public key: $e';
        _loadingKey = false;
      });
    }
  }

  Future<void> _loadToken() async {
    if (widget.system == null) return;
    try {
      final fp = await pb.collection('fingerprints').getFirstListItem(
        'system = "${widget.system!.id}"',
        fields: 'token',
      );
      setState(() => _token = fp.data['token'] as String?);
    } catch (e) {
      // Token might not exist, generate new one
      setState(() => _token = PublicKeyService.generateToken());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final host = _hostController.text.trim();
      final isUnixSocket = host.startsWith('/');
      final data = {
        'name': _nameController.text.trim(),
        'host': host,
        if (!isUnixSocket) 'port': int.tryParse(_portController.text.trim()) ?? 45876,
        'users': pb.authStore.record?.id,
      };
      if (widget.system != null) {
        await pb.collection('systems').update(widget.system!.id, body: data);
      } else {
        final created = await pb.collection('systems').create(body: data);
        await pb.collection('fingerprints').create(body: {
          'system': created.id,
          'token': _token,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Failed to save system: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnixSocket = _hostController.text.startsWith('/');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.system != null ? 'Edit System' : 'Add System'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _loadingKey
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host / IP',
                        prefixIcon: Icon(Icons.computer),
                        border: OutlineInputBorder(),
                        helperText: 'Enter IP address or Unix socket path (e.g., /var/run/docker.sock)',
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Host is required' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!isUnixSocket) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Port is required';
                          final port = int.tryParse(v);
                          if (port == null || port < 1 || port > 65535) return 'Invalid port number';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_publicKey != null) ...[
                      const Text('Public Key', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _publicKey!,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copyToClipboard(_publicKey!, 'Public key'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_token != null) ...[
                      const Text('Token', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _token!,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copyToClipboard(_token!, 'Token'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Use the public key and token above to configure your agent. The token is unique to this system.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    if (_publicKey != null && _token != null)
                      ValueListenableBuilder<String>(
                        valueListenable: PocketBaseManager.instance.baseUrl,
                        builder: (context, hubUrl, _) {
                          final listenValue = _listenValue(isUnixSocket);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Installation',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<_InstallMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: _InstallMode.docker,
                                    label: Text('Docker'),
                                    icon: Icon(Icons.dns_outlined),
                                  ),
                                  ButtonSegment(
                                    value: _InstallMode.binary,
                                    label: Text('Direct Install'),
                                    icon: Icon(Icons.terminal_outlined),
                                  ),
                                ],
                                selected: {_installMode},
                                onSelectionChanged: (selection) {
                                  setState(() => _installMode = selection.first);
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_installMode == _InstallMode.docker)
                                _DockerInstallCard(
                                  compose: _dockerComposeYaml(listenValue, _publicKey!, _token!, hubUrl),
                                  dockerRun: _dockerRunCommand(listenValue, _publicKey!, _token!, hubUrl),
                                  onCopy: _copyToClipboard,
                                )
                              else
                                _BinaryInstallCard(
                                  linux: _linuxCommand(listenValue, _publicKey!, _token!, hubUrl),
                                  linuxBrew: _linuxCommand(listenValue, _publicKey!, _token!, hubUrl, brew: true),
                                  windows: _windowsCommand(listenValue, _publicKey!, _token!, hubUrl),
                                  freeBsd: _linuxCommand(listenValue, _publicKey!, _token!, hubUrl),
                                  onCopy: _copyToClipboard,
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _listenValue(bool isUnixSocket) {
    final host = _hostController.text.trim();
    if (isUnixSocket) return host.isEmpty ? '/var/run/docker.sock' : host;
    final portText = _portController.text.trim();
    return portText.isEmpty ? '45876' : portText;
  }

  String _dockerComposeYaml(String listen, String key, String token, String hubUrl) {
    return '''
services:
  beszel-agent:
    image: henrygd/beszel-agent
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./beszel_agent_data:/var/lib/beszel-agent
      # monitor other disks / partitions by mounting a folder in /extra-filesystems
      # - /mnt/disk/.beszel:/extra-filesystems/sda1:ro
    environment:
      LISTEN: $listen
      KEY: '$key'
      TOKEN: $token
      HUB_URL: $hubUrl''';
  }

  String _dockerRunCommand(String listen, String key, String token, String hubUrl) {
    return 'docker run -d --name beszel-agent --network host --restart unless-stopped '
        '-v /var/run/docker.sock:/var/run/docker.sock:ro '
        '-v ./beszel_agent_data:/var/lib/beszel-agent '
        '-e KEY="$key" -e LISTEN=$listen -e TOKEN="$token" -e HUB_URL="$hubUrl" henrygd/beszel-agent';
  }

  String _linuxCommand(String listen, String key, String token, String hubUrl, {bool brew = false}) {
    final path = brew ? '/brew' : '';
    return 'curl -sL https://get.beszel.dev$path -o /tmp/install-agent.sh && '
        'chmod +x /tmp/install-agent.sh && '
        '/tmp/install-agent.sh -p $listen -k "$key" -t "$token" -url "$hubUrl"';
  }

  String _windowsCommand(String listen, String key, String token, String hubUrl) {
    return r'& iwr -useb https://get.beszel.dev -OutFile "$env:TEMP\install-agent.ps1"; '
        r'& Powershell -ExecutionPolicy Bypass -File "$env:TEMP\install-agent.ps1" '
        '-Key "$key" -Port $listen -Token "$token" -Url "$hubUrl"';
  }
}

class _DockerInstallCard extends StatelessWidget {
  const _DockerInstallCard({
    required this.compose,
    required this.dockerRun,
    required this.onCopy,
  });

  final String compose;
  final String dockerRun;
  final void Function(String text, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommandCard(
          title: 'Docker Compose',
          subtitle: 'Copy the docker-compose snippet to deploy the agent.',
          command: compose,
          onCopy: () => onCopy(compose, 'Docker compose'),
          multiline: true,
        ),
        const SizedBox(height: 12),
        _CommandCard(
          title: 'Docker Run',
          subtitle: 'Copy a single-line docker run command.',
          command: dockerRun,
          onCopy: () => onCopy(dockerRun, 'Docker run command'),
        ),
      ],
    );
  }
}

class _BinaryInstallCard extends StatelessWidget {
  const _BinaryInstallCard({
    required this.linux,
    required this.linuxBrew,
    required this.windows,
    required this.freeBsd,
    required this.onCopy,
  });

  final String linux;
  final String linuxBrew;
  final String windows;
  final String freeBsd;
  final void Function(String text, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommandCard(
          title: 'Linux',
          subtitle: 'Download and run the installer script on Linux hosts.',
          command: linux,
          onCopy: () => onCopy(linux, 'Linux command'),
        ),
        const SizedBox(height: 12),
        _CommandCard(
          title: 'macOS (Homebrew)',
          subtitle: 'Use the Homebrew-friendly installer.',
          command: linuxBrew,
          onCopy: () => onCopy(linuxBrew, 'Homebrew command'),
        ),
        const SizedBox(height: 12),
        _CommandCard(
          title: 'Windows',
          subtitle: 'Run this PowerShell command as administrator.',
          command: windows,
          onCopy: () => onCopy(windows, 'Windows command'),
        ),
        const SizedBox(height: 12),
        _CommandCard(
          title: 'FreeBSD',
          subtitle: 'Use the FreeBSD-compatible installer script.',
          command: freeBsd,
          onCopy: () => onCopy(freeBsd, 'FreeBSD command'),
        ),
      ],
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.title,
    required this.subtitle,
    required this.command,
    required this.onCopy,
    this.multiline = false,
  });

  final String title;
  final String subtitle;
  final String command;
  final VoidCallback onCopy;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy',
                  onPressed: onCopy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: multiline
                  ? SelectableText(
                      command,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        command,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
