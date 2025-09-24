import 'dart:async';
import 'package:flutter/services.dart';
import 'cross_p2p_network_platform_interface.dart';

class MethodChannelCrossP2pNetwork extends CrossP2pNetworkPlatform {
  /// Method channel for synchronous method calls
  static const MethodChannel _methodChannel =
  MethodChannel('cross_p2p_network');

  /// Event channel for receiving events from the platform
  static const EventChannel _eventChannel =
  EventChannel('cross_p2p_network/events');

  /// Data channel for receiving data streams from the platform
  static const EventChannel _dataChannel =
  EventChannel('cross_p2p_network/data');

  /// Stream controllers for events and data
  final StreamController<Map<String, dynamic>> _eventStreamController =
  StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _dataStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  /// Stream subscriptions for platform channels
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _dataSubscription;

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await _methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Failed to get platform version: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> initialize(Map<String, dynamic> config) async {
    try {
      final result = await _methodChannel.invokeMethod('initialize', config);

      // Start listening to event and data streams after initialization
      _startStreamListeners();

      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Initialization failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('createRoom', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Room creation failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> joinNetwork(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('joinNetwork', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network join failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> scanNetworks() async {
    try {
      final result = await _methodChannel.invokeMethod('scanNetworks');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network scan failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> startServiceBroadcast(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('startBroadcast', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Service broadcast start failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> stopServiceBroadcast() async {
    try {
      final result = await _methodChannel.invokeMethod('stopBroadcast');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Service broadcast stop failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> startServiceScan(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('startScan', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Service scan start failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> stopServiceScan() async {
    try {
      final result = await _methodChannel.invokeMethod('stopScan');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Service scan stop failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> performSingleScan(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('singleScan', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Single scan failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> disconnect(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('disconnect', params);

      // Stop stream listeners when disconnecting
      await _stopStreamListeners();

      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Disconnect failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getBatteryLevel() async {
    try {
      final result = await _methodChannel.invokeMethod('getBatteryLevel');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Battery level query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getSignalStrength() async {
    try {
      final result = await _methodChannel.invokeMethod('getSignalStrength');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Signal strength query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Device info query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> refreshBroadcast() async {
    try {
      final result = await _methodChannel.invokeMethod('refreshBroadcast');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Broadcast refresh failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> continuousScan(Map<String, dynamic> params) async {
    try {
      final result = await _methodChannel.invokeMethod('continuousScan', params);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Continuous scan failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final result = await _methodChannel.invokeMethod('getNetworkInfo');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network info query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> isWifiEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isWifiEnabled');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Wi-Fi status query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> enableWifi() async {
    try {
      final result = await _methodChannel.invokeMethod('enableWifi');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Wi-Fi enable failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> disableWifi() async {
    try {
      final result = await _methodChannel.invokeMethod('disableWifi');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Wi-Fi disable failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getConnectedNetwork() async {
    try {
      final result = await _methodChannel.invokeMethod('getConnectedNetwork');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Connected network query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> forgetNetwork(String ssid) async {
    try {
      final result = await _methodChannel.invokeMethod('forgetNetwork', {'ssid': ssid});
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network forget failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getNetworkStats() async {
    try {
      final result = await _methodChannel.invokeMethod('getNetworkStats');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network stats query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> sendData(Map<String, dynamic> data) async {
    try {
      final result = await _methodChannel.invokeMethod('sendData', data);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Data send failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> setHeartbeatInterval(int intervalSeconds) async {
    try {
      final result = await _methodChannel.invokeMethod('setHeartbeatInterval', {
        'interval': intervalSeconds,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Heartbeat interval set failed: ${e.message}',
        details: e.details,
      );
    }
  }

  /// Get stream of events from the platform
  @override
  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  /// Get stream of data from the platform
  @override
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// Start listening to platform event and data streams
  void _startStreamListeners() {
    // Start event stream listener
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
        try {
          final eventMap = Map<String, dynamic>.from(event);
          _eventStreamController.add(eventMap);
        } catch (e) {
          // Handle parsing errors gracefully
          _eventStreamController.addError(
            PlatformException(
              code: 'STREAM_PARSE_ERROR',
              message: 'Failed to parse event: $e',
            ),
          );
        }
      },
      onError: (error) {
        _eventStreamController.addError(
          PlatformException(
            code: 'STREAM_ERROR',
            message: 'Event stream error: $error',
          ),
        );
      },
      cancelOnError: false,
    );

    // Start data stream listener
    _dataSubscription = _dataChannel.receiveBroadcastStream().listen(
          (data) {
        try {
          final dataMap = Map<String, dynamic>.from(data);
          _dataStreamController.add(dataMap);
        } catch (e) {
          // Handle parsing errors gracefully
          _dataStreamController.addError(
            PlatformException(
              code: 'STREAM_PARSE_ERROR',
              message: 'Failed to parse data: $e',
            ),
          );
        }
      },
      onError: (error) {
        _dataStreamController.addError(
          PlatformException(
            code: 'STREAM_ERROR',
            message: 'Data stream error: $error',
          ),
        );
      },
      cancelOnError: false,
    );
  }

  /// Stop listening to platform streams
  Future<void> _stopStreamListeners() async {
    await _eventSubscription?.cancel();
    await _dataSubscription?.cancel();

    _eventSubscription = null;
    _dataSubscription = null;
  }

  /// Dispose method to clean up resources
  Future<void> dispose() async {
    await _stopStreamListeners();
    await _eventStreamController.close();
    await _dataStreamController.close();
  }

  /// Additional utility methods for enhanced functionality

  @override
  Future<Map<String, dynamic>> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('checkPermissions');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Permission check failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('requestPermissions');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Permission request failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getConnectionQuality() async {
    try {
      final result = await _methodChannel.invokeMethod('getConnectionQuality');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Connection quality query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> optimizeBatteryUsage(bool optimize) async {
    try {
      final result = await _methodChannel.invokeMethod('optimizeBatteryUsage', {
        'optimize': optimize,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Battery optimization failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> setNetworkPriority(String networkType) async {
    try {
      final result = await _methodChannel.invokeMethod('setNetworkPriority', {
        'networkType': networkType,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Network priority set failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getAvailableNetworks() async {
    try {
      final result = await _methodChannel.invokeMethod('getAvailableNetworks');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Available networks query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> pingNode(String nodeId, {int timeout = 5000}) async {
    try {
      final result = await _methodChannel.invokeMethod('pingNode', {
        'nodeId': nodeId,
        'timeout': timeout,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Node ping failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getNodeInfo(String nodeId) async {
    try {
      final result = await _methodChannel.invokeMethod('getNodeInfo', {
        'nodeId': nodeId,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Node info query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> setDebugMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod('setDebugMode', {
        'enabled': enabled,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Debug mode set failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getLogs() async {
    try {
      final result = await _methodChannel.invokeMethod('getLogs');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Logs query failed: ${e.message}',
        details: e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> clearCache() async {
    try {
      final result = await _methodChannel.invokeMethod('clearCache');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Cache clear failed: ${e.message}',
        details: e.details,
      );
    }
  }

  /// Method to check if the platform is ready
  Future<bool> isPlatformReady() async {
    try {
      final result = await _methodChannel.invokeMethod('isPlatformReady');
      return result['ready'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Method to get platform capabilities
  Future<Map<String, dynamic>> getPlatformCapabilities() async {
    try {
      final result = await _methodChannel.invokeMethod('getPlatformCapabilities');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Platform capabilities query failed: ${e.message}',
        details: e.details,
      );
    }
  }
}