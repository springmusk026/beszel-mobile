class UserSettings {
  final String id;
  final String userId;
  final String chartTime; // '1h' | '12h' | '24h' | '1w' | '30d' | '1m'
  final String? unitTemp; // 'Celsius'|'Fahrenheit'
  final String? unitNet; // e.g. 'Bytes'
  final String? unitDisk;
  final List<String> emails;
  final List<String> webhooks;

  const UserSettings({
    required this.id,
    required this.userId,
    required this.chartTime,
    this.unitTemp,
    this.unitNet,
    this.unitDisk,
    this.emails = const [],
    this.webhooks = const [],
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    final settings = (map['settings'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return UserSettings(
      id: map['id']?.toString() ?? '',
      userId: map['user']?.toString() ?? '',
      chartTime: settings['chartTime']?.toString() ?? '1h',
      unitTemp: settings['unitTemp']?.toString(),
      unitNet: settings['unitNet']?.toString(),
      unitDisk: settings['unitDisk']?.toString(),
      emails: List<String>.from((settings['emails'] as List?)?.map((e) => e.toString()) ?? const []),
      webhooks: List<String>.from((settings['webhooks'] as List?)?.map((e) => e.toString()) ?? const []),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    final settings = <String, dynamic>{
      'chartTime': chartTime,
      'emails': emails,
      'webhooks': webhooks,
    };
    if (unitTemp != null) settings['unitTemp'] = unitTemp;
    if (unitNet != null) settings['unitNet'] = unitNet;
    if (unitDisk != null) settings['unitDisk'] = unitDisk;
    return {'settings': settings};
  }

  UserSettings copyWith({
    String? chartTime,
    String? unitTemp,
    String? unitNet,
    String? unitDisk,
    List<String>? emails,
    List<String>? webhooks,
  }) {
    return UserSettings(
      id: id,
      userId: userId,
      chartTime: chartTime ?? this.chartTime,
      unitTemp: unitTemp ?? this.unitTemp,
      unitNet: unitNet ?? this.unitNet,
      unitDisk: unitDisk ?? this.unitDisk,
      emails: emails ?? this.emails,
      webhooks: webhooks ?? this.webhooks,
    );
  }
}

