import '../api/pb_client.dart';

class SmartAttributeData {
  final int? id;
  final String name;
  final num? value;
  final num? worst;
  final num? threshold;
  final String? rawString;
  final num? rawValue;
  final String? whenFailed;

  const SmartAttributeData({
    this.id,
    required this.name,
    this.value,
    this.worst,
    this.threshold,
    this.rawString,
    this.rawValue,
    this.whenFailed,
  });

  factory SmartAttributeData.fromMap(Map<String, dynamic> map) {
    return SmartAttributeData(
      id: map['id'] as int?,
      name: map['n']?.toString() ?? '',
      value: map['v'] is num ? map['v'] as num : num.tryParse(map['v']?.toString() ?? ''),
      worst: map['w'] is num ? map['w'] as num : num.tryParse(map['w']?.toString() ?? ''),
      threshold: map['t'] is num ? map['t'] as num : num.tryParse(map['t']?.toString() ?? ''),
      rawString: map['rs']?.toString(),
      rawValue: map['rv'] is num ? map['rv'] as num : num.tryParse(map['rv']?.toString() ?? ''),
      whenFailed: map['wf']?.toString(),
    );
  }
}

class SmartDiskData {
  final String device;
  final String? model;
  final String? serialNumber;
  final String? firmwareVersion;
  final num? capacity;
  final String? status;
  final num? temperature;
  final String? deviceType;
  final Map<String, dynamic> raw;
  final List<SmartAttributeData> attributes;

  const SmartDiskData({
    required this.device,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
    this.capacity,
    this.status,
    this.temperature,
    this.deviceType,
    required this.raw,
    required this.attributes,
  });

  factory SmartDiskData.fromEntry(String diskKey, Map<String, dynamic> data) {
    final attrs = (data['a'] as List?)
            ?.map((attr) => SmartAttributeData.fromMap((attr as Map).cast<String, dynamic>()))
            .toList() ??
        const <SmartAttributeData>[];
    return SmartDiskData(
      device: data['dn']?.toString() ?? diskKey,
      model: data['mn']?.toString(),
      serialNumber: data['sn']?.toString(),
      firmwareVersion: data['fv']?.toString(),
      capacity: data['c'] is num ? data['c'] as num : num.tryParse(data['c']?.toString() ?? ''),
      status: data['s']?.toString(),
      temperature: data['t'] is num ? data['t'] as num : num.tryParse(data['t']?.toString() ?? ''),
      deviceType: data['dt']?.toString(),
      raw: data,
      attributes: attrs,
    );
  }
}

class SmartService {
  Future<List<SmartDiskData>> fetchSmart(String systemId) async {
    try {
      final res = await pb.send<Map<String, dynamic>>(
        '/api/beszel/smart',
        query: {'system': systemId},
      );
      if (res.isEmpty) return const [];
      final List<SmartDiskData> disks = [];
      res.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          disks.add(SmartDiskData.fromEntry(key, value));
        } else if (value is Map) {
          disks.add(SmartDiskData.fromEntry(key, (value).cast<String, dynamic>()));
        }
      });
      disks.sort((a, b) => a.device.toLowerCase().compareTo(b.device.toLowerCase()));
      return disks;
    } catch (e) {
      // Re-throw with a readable message so UI can show it
      throw Exception('SMART fetch failed for system $systemId: $e');
    }
  }
}


