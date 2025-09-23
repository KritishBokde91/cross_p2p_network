import 'dart:async';
import 'package:flutter/services.dart';

class ServiceDiscovery {
  static const MethodChannel _channel = MethodChannel('cross_p2p_network/discovery');

  final StreamController<DiscoveryEvent> _eventController =
  StreamController<DiscoveryEvent>.broadcast();

  bool _isBroadcasting = false;
  bool _isScanning = false;
  Timer? _scanTimer;
  Timer? _broadcastTimer;

  final Set<String> _discoveredServices = {};
  final Map<String, ServiceInfo> _serviceCache = {};

  static const String defaultServiceType = '_attendance._tcp';
  static const Duration scanInterval = Duration(seconds: 10);
  static const Duration broadcastInterval = Duration(seconds: 5);
  static const Duration cacheTimeout = Duration(minutes: 2);

  Future<void> startBroadcast({
    required String roomId,
    required String ssid,
    required String brokerIp,
    required int brokerPort,
    String serviceType = defaultServiceType,
    Map<String, String>? additionalInfo,
  }) async {
    if (_isBroadcasting) {
      await stopBroadcast();
    }

    try {
      final serviceInfo = {
        'serviceType': serviceType,
        'serviceName': 'AttendanceRoom_$roomId',
        'port': brokerPort,
        'txtRecords': {
          'roomId': roomId,
          'ssid': ssid,
          'brokerIp': brokerIp,
          'brokerPort': brokerPort.toString(),
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          ...?additionalInfo,
        },
      };

      await _channel.invokeMethod('startBroadcast', serviceInfo);
      _isBroadcasting = true;

      _startBroadcastTimer();

      _eventController.add(DiscoveryEvent.broadcastStarted(roomId, ssid));

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Failed to start broadcast: $e'));
      rethrow;
    }
  }

  Future<void> stopBroadcast() async {
    if (!_isBroadcasting) return;

    try {
      await _channel.invokeMethod('stopBroadcast');
      _isBroadcasting = false;
      _broadcastTimer?.cancel();

      _eventController.add(DiscoveryEvent.broadcastStopped());

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Failed to stop broadcast: $e'));
    }
  }

  Future<List<ServiceInfo>> startScan({
    String serviceType = defaultServiceType,
    Duration? timeout,
  }) async {
    if (_isScanning) {
      await stopScan();
    }

    try {
      _isScanning = true;
      _discoveredServices.clear();

      final scanConfig = {
        'serviceType': serviceType,
        'timeout': (timeout?.inMilliseconds ?? 30000),
      };

      final result = await _channel.invokeMethod('startScan', scanConfig);
      final services = _parseDiscoveredServices(result);

      // Start continuous scanning
      _startScanTimer(serviceType);

      _eventController.add(DiscoveryEvent.scanStarted(serviceType));

      return services;

    } catch (e) {
      _isScanning = false;
      _eventController.add(DiscoveryEvent.error('Failed to start scan: $e'));
      return [];
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await _channel.invokeMethod('stopScan');
      _isScanning = false;
      _scanTimer?.cancel();

      _eventController.add(DiscoveryEvent.scanStopped());

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Failed to stop scan: $e'));
    }
  }

  Future<List<ServiceInfo>> performSingleScan({
    String serviceType = defaultServiceType,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final scanConfig = {
        'serviceType': serviceType,
        'timeout': timeout.inMilliseconds,
        'singleScan': true,
      };

      final result = await _channel.invokeMethod('singleScan', scanConfig);
      final services = _parseDiscoveredServices(result);

      _eventController.add(DiscoveryEvent.servicesDiscovered(services));

      return services;

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Single scan failed: $e'));
      return [];
    }
  }

  List<ServiceInfo> getCachedServices() {
    final now = DateTime.now();

    _serviceCache.removeWhere((key, service) {
      final age = now.difference(service.discoveredAt);
      return age > cacheTimeout;
    });

    return _serviceCache.values.toList();
  }

  ServiceInfo? getServiceByRoomId(String roomId) {
    return _serviceCache.values
        .where((service) => service.roomId == roomId)
        .firstOrNull;
  }

  List<ServiceInfo> filterServices({
    String? classCode,
    String? subject,
    List<String>? allowedSsids,
    int? minSignalStrength,
  }) {
    var services = getCachedServices();

    if (classCode != null) {
      services = services.where((s) =>
      s.additionalInfo['classCode'] == classCode).toList();
    }

    if (subject != null) {
      services = services.where((s) =>
      s.additionalInfo['subject'] == subject).toList();
    }

    if (allowedSsids != null && allowedSsids.isNotEmpty) {
      services = services.where((s) =>
          allowedSsids.contains(s.ssid)).toList();
    }

    if (minSignalStrength != null) {
      services = services.where((s) =>
      (s.signalStrength ?? 0) >= minSignalStrength).toList();
    }

    services.sort((a, b) =>
        (b.signalStrength ?? 0).compareTo(a.signalStrength ?? 0));

    return services;
  }

  Stream<DiscoveryEvent> get eventStream => _eventController.stream;

  bool get isBroadcasting => _isBroadcasting;

  bool get isScanning => _isScanning;

  Map<String, dynamic> getStats() {
    return {
      'isBroadcasting': _isBroadcasting,
      'isScanning': _isScanning,
      'cachedServices': _serviceCache.length,
      'discoveredServices': _discoveredServices.length,
      'lastScanTime': _scanTimer != null ? DateTime.now().toIso8601String() : null,
    };
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopScan();
    await _eventController.close();

    _serviceCache.clear();
    _discoveredServices.clear();
  }


  void _startBroadcastTimer() {
    _broadcastTimer = Timer.periodic(broadcastInterval, (timer) async {
      if (_isBroadcasting) {
        try {
          await _channel.invokeMethod('refreshBroadcast');
        } catch (e) {
          _eventController.add(DiscoveryEvent.error('Broadcast refresh failed: $e'));
        }
      }
    });
  }

  void _startScanTimer(String serviceType) {
    _scanTimer = Timer.periodic(scanInterval, (timer) async {
      if (_isScanning) {
        try {
          final result = await _channel.invokeMethod('continuousScan', {
            'serviceType': serviceType,
          });

          final services = _parseDiscoveredServices(result);
          if (services.isNotEmpty) {
            _eventController.add(DiscoveryEvent.servicesDiscovered(services));
          }

        } catch (e) {
          _eventController.add(DiscoveryEvent.error('Continuous scan failed: $e'));
        }
      }
    });
  }

  List<ServiceInfo> _parseDiscoveredServices(dynamic result) {
    final services = <ServiceInfo>[];

    try {
      final resultMap = Map<String, dynamic>.from(result);
      final servicesList = resultMap['services'] as List? ?? [];

      for (final serviceData in servicesList) {
        final service = _parseServiceInfo(Map<String, dynamic>.from(serviceData));
        if (service != null) {
          _serviceCache[service.serviceId] = service;
          _discoveredServices.add(service.serviceId);
          services.add(service);
        }
      }

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Failed to parse services: $e'));
    }

    return services;
  }

  ServiceInfo? _parseServiceInfo(Map<String, dynamic> data) {
    try {
      final txtRecords = Map<String, String>.from(data['txtRecords'] ?? {});

      return ServiceInfo(
        serviceId: data['serviceId'] ?? '',
        serviceName: data['serviceName'] ?? '',
        serviceType: data['serviceType'] ?? defaultServiceType,
        hostName: data['hostName'] ?? '',
        port: data['port'] ?? 0,
        roomId: txtRecords['roomId'] ?? '',
        ssid: txtRecords['ssid'] ?? '',
        brokerIp: txtRecords['brokerIp'] ?? '',
        brokerPort: int.tryParse(txtRecords['brokerPort'] ?? '1883') ?? 1883,
        signalStrength: data['signalStrength'],
        additionalInfo: txtRecords,
      );

    } catch (e) {
      _eventController.add(DiscoveryEvent.error('Failed to parse service info: $e'));
      return null;
    }
  }
}

class ServiceInfo {
  final String serviceId;
  final String serviceName;
  final String serviceType;
  final String hostName;
  final int port;
  final String roomId;
  final String ssid;
  final String brokerIp;
  final int brokerPort;
  final int? signalStrength;
  final Map<String, String> additionalInfo;
  final DateTime discoveredAt;

  ServiceInfo({
    required this.serviceId,
    required this.serviceName,
    required this.serviceType,
    required this.hostName,
    required this.port,
    required this.roomId,
    required this.ssid,
    required this.brokerIp,
    required this.brokerPort,
    this.signalStrength,
    Map<String, String>? additionalInfo,
    DateTime? discoveredAt,
  }) : additionalInfo = additionalInfo ?? {},
        discoveredAt = discoveredAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceType': serviceType,
      'hostName': hostName,
      'port': port,
      'roomId': roomId,
      'ssid': ssid,
      'brokerIp': brokerIp,
      'brokerPort': brokerPort,
      'signalStrength': signalStrength,
      'additionalInfo': additionalInfo,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory ServiceInfo.fromMap(Map<String, dynamic> map) {
    return ServiceInfo(
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      serviceType: map['serviceType'] ?? '',
      hostName: map['hostName'] ?? '',
      port: map['port'] ?? 0,
      roomId: map['roomId'] ?? '',
      ssid: map['ssid'] ?? '',
      brokerIp: map['brokerIp'] ?? '',
      brokerPort: map['brokerPort'] ?? 1883,
      signalStrength: map['signalStrength'],
      additionalInfo: Map<String, String>.from(map['additionalInfo'] ?? {}),
      discoveredAt: DateTime.tryParse(map['discoveredAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get classCode => additionalInfo['classCode'] ?? '';
  String get subject => additionalInfo['subject'] ?? '';

  bool get isExpired {
    final age = DateTime.now().difference(discoveredAt);
    return age > const Duration(minutes: 2);
  }
}

enum DiscoveryEventType {
  broadcastStarted,
  broadcastStopped,
  scanStarted,
  scanStopped,
  servicesDiscovered,
  serviceAdded,
  serviceRemoved,
  error,
}

class DiscoveryEvent {
  final DiscoveryEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  DiscoveryEvent({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DiscoveryEvent.broadcastStarted(String roomId, String ssid) {
    return DiscoveryEvent(
      type: DiscoveryEventType.broadcastStarted,
      message: 'Broadcast started for room $roomId (SSID: $ssid)',
      data: {'roomId': roomId, 'ssid': ssid},
    );
  }

  factory DiscoveryEvent.broadcastStopped() {
    return DiscoveryEvent(
      type: DiscoveryEventType.broadcastStopped,
      message: 'Broadcast stopped',
    );
  }

  factory DiscoveryEvent.scanStarted(String serviceType) {
    return DiscoveryEvent(
      type: DiscoveryEventType.scanStarted,
      message: 'Scan started for service type: $serviceType',
      data: {'serviceType': serviceType},
    );
  }

  factory DiscoveryEvent.scanStopped() {
    return DiscoveryEvent(
      type: DiscoveryEventType.scanStopped,
      message: 'Scan stopped',
    );
  }

  factory DiscoveryEvent.servicesDiscovered(List<ServiceInfo> services) {
    return DiscoveryEvent(
      type: DiscoveryEventType.servicesDiscovered,
      message: 'Discovered ${services.length} services',
      data: {
        'services': services.map((s) => s.toMap()).toList(),
        'count': services.length,
      },
    );
  }

  factory DiscoveryEvent.serviceAdded(ServiceInfo service) {
    return DiscoveryEvent(
      type: DiscoveryEventType.serviceAdded,
      message: 'Service added: ${service.serviceName}',
      data: service.toMap(),
    );
  }

  factory DiscoveryEvent.serviceRemoved(String serviceId) {
    return DiscoveryEvent(
      type: DiscoveryEventType.serviceRemoved,
      message: 'Service removed: $serviceId',
      data: {'serviceId': serviceId},
    );
  }

  factory DiscoveryEvent.error(String error) {
    return DiscoveryEvent(
      type: DiscoveryEventType.error,
      message: 'Discovery error: $error',
      data: {'error': error},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'message': message,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DiscoveryEvent.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] ?? '';
    DiscoveryEventType type = DiscoveryEventType.error;

    for (final eventType in DiscoveryEventType.values) {
      if (eventType.toString() == typeString) {
        type = eventType;
        break;
      }
    }

    return DiscoveryEvent(
      type: type,
      message: map['message'] ?? '',
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'])
          : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isError => type == DiscoveryEventType.error;
}