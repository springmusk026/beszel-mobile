class SystemRecord {
  final String id;
  final String name;
  final String host;
  final String status;
  final String port;
  final Map<String, dynamic> info;
  final String? version;
  final String? updated;

  const SystemRecord({
    required this.id,
    required this.name,
    required this.host,
    required this.status,
    required this.port,
    required this.info,
    this.version,
    this.updated,
  });

  factory SystemRecord.fromMap(Map<String, dynamic> map) {
    return SystemRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      status: map['status'] as String,
      port: map['port']?.toString() ?? '',
      info: Map<String, dynamic>.from(map['info'] as Map),
      version: map['v']?.toString(),
      updated: map['updated']?.toString(),
    );
  }
}


