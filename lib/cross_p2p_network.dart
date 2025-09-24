import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cross_p2p_network/src/models/network_models.dart';
import 'package:cross_p2p_network/src/discovery/service_discovery.dart';
import 'package:cross_p2p_network/src/graph/bfs_graph.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

export 'src/models/network_models.dart';

class CrossP2PNetwork {
  static final CrossP2PNetwork _instance = CrossP2PNetwork._internal();
  factory CrossP2PNetwork() => _instance;
  CrossP2PNetwork._internal();

  static const MethodChannel _methodChannel =
  MethodChannel('cross_p2p_network');
  static const EventChannel _eventChannel =
  EventChannel('cross_p2p_network/events');
  static const EventChannel _dataChannel =
  EventChannel('cross_p2p_network/data');

  final StreamController<NetworkEvent> _eventController =
  StreamController<NetworkEvent>.broadcast();
  final StreamController<Map<String, dynamic>> _dataController =
  StreamController<Map<String, dynamic>>.broadcast();

  // Core components
  late ServiceDiscovery _serviceDiscovery;
  late BfsGraph _networkGraph;
  MqttServerClient? _mqttClient;
  NetworkNode? _currentNode;
  NetworkInfo? _currentNetwork;

  // State management
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRoot = false;
  String? _currentRoomId;

  // Configuration
  String _serviceType = '_attendance._tcp';
  bool preferWifiAware = true;
  bool _enableDebugLogs = false;

  // Timers
  Timer? _heartbeatTimer;
  Timer? _healthCheckTimer;

  // Stream subscriptions
  StreamSubscription? _eventSubscription;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _graphEventSubscription;

  /// Initialize the plugin with configuration
  static Future<void> initialize({
    String serviceType = '_attendance._tcp',
    bool preferAware = true,
    bool enableDebugLogs = false,
  }) async {
    return _instance._initialize(
      serviceType: serviceType,
      preferAware: preferAware,
      enableDebugLogs: enableDebugLogs,
    );
  }

  Future<void> _initialize({
    required String serviceType,
    required bool preferAware,
    required bool enableDebugLogs,
  }) async {
    if (_isInitialized) {
      throw StateError('Plugin already initialized');
    }

    _serviceType = serviceType;
    preferWifiAware = preferAware;
    _enableDebugLogs = enableDebugLogs;

    try {
      // Initialize native platform
      // final result = await _methodChannel.invokeMethod('initialize', {
      //   'serviceType': serviceType,
      //   'preferAware': preferAware,
      //   'enableDebugLogs': enableDebugLogs,
      // });

      // Initialize components
      _serviceDiscovery = ServiceDiscovery();
      _networkGraph = BfsGraph();

      // Listen to platform events
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(_handlePlatformEvent);
      _dataSubscription = _dataChannel.receiveBroadcastStream().listen(_handlePlatformData);

      // Listen to graph events
      _graphEventSubscription = _networkGraph.eventStream.listen(_handleGraphEvent);

      _isInitialized = true;

      _eventController.add(NetworkEvent.initialized());

      if (_enableDebugLogs) {
        debugPrint('CrossP2PNetwork: Plugin initialized successfully');
      }

    } catch (e) {
      _eventController.add(NetworkEvent.error('Initialization failed: $e'));
      rethrow;
    }
  }

  /// Create a new room (Teacher mode)
  static Future<RoomCreationResult> createRoom({
    required String classCode,
    required int expectedSize,
    String? subject,
    Duration? duration,
    Function(Map<String, dynamic>)? onDataReceived,
    Function(List<Map<String, dynamic>>)? onQuizResponses,
  }) async {
    return _instance._createRoom(
      classCode: classCode,
      expectedSize: expectedSize,
      subject: subject,
      duration: duration,
      onDataReceived: onDataReceived,
      onQuizResponses: onQuizResponses,
    );
  }

  Future<RoomCreationResult> _createRoom({
    required String classCode,
    required int expectedSize,
    String? subject,
    Duration? duration,
    Function(Map<String, dynamic>)? onDataReceived,
    Function(List<Map<String, dynamic>>)? onQuizResponses,
  }) async {
    _checkInitialized();

    try {
      // Generate unique room ID and credentials
      final roomId = _generateRoomId();
      final ssid = _generateSsid(classCode, subject);
      final password = _generatePassword();

      // Create room on native platform
      final result = await _methodChannel.invokeMethod('createRoom', {
        'roomId': roomId,
        'ssid': ssid,
        'password': password,
        'expectedSize': expectedSize,
        'classCode': classCode,
        'subject': subject,
      });

      final resultMap = Map<String, dynamic>.from(result);
      final roomResult = RoomCreationResult.fromMap(resultMap);

      if (roomResult.success) {
        _isRoot = true;
        _currentRoomId = roomId;
        _currentNetwork = NetworkInfo(
          ssid: ssid,
          password: password,
          signalStrength: 100,
          roomId: roomId,
          brokerIp: roomResult.brokerIp,
          brokerPort: roomResult.brokerPort,
          classCode: classCode,
          subject: subject,
        );

        // Initialize as root node
        await _initializeAsRootNode();

        // Start MQTT broker
        await _startMqttBroker();

        // Start service discovery
        await _serviceDiscovery.startBroadcast(
          roomId: roomId,
          ssid: ssid,
          brokerIp: roomResult.brokerIp,
          brokerPort: roomResult.brokerPort,
          additionalInfo: {
            'classCode': classCode,
            'subject': subject ?? '',
            'expectedSize': expectedSize.toString(),
          },
        );

        // Set up data handlers
        if (onDataReceived != null) {
          _dataController.stream.listen(onDataReceived);
        }

        _eventController.add(NetworkEvent.roomCreated(roomResult));

        if (_enableDebugLogs) {
          print('CrossP2PNetwork: Room created successfully - $ssid');
        }
      }

      return roomResult;

    } catch (e) {
      _eventController.add(NetworkEvent.error('Room creation failed: $e'));
      rethrow;
    }
  }

  /// Scan and join available networks (Student mode)
  static Future<JoinResult> scanAndJoin({
    required String studentId,
    required Map<String, dynamic> studentInfo,
    Function(Map<String, dynamic>)? onDataReceived,
    List<String> allowedSsids = const [],
  }) async {
    return _instance._scanAndJoin(
      studentId: studentId,
      studentInfo: studentInfo,
      onDataReceived: onDataReceived,
      allowedSsids: allowedSsids,
    );
  }

  Future<JoinResult> _scanAndJoin({
    required String studentId,
    required Map<String, dynamic> studentInfo,
    Function(Map<String, dynamic>)? onDataReceived,
    List<String> allowedSsids = const [],
  }) async {
    _checkInitialized();

    try {
      // Scan for available services
      final services = await _serviceDiscovery.startScan(
        serviceType: _serviceType,
        timeout: const Duration(seconds: 15),
      );

      // Convert ServiceInfo to NetworkInfo for compatibility
      final networkInfos = services.map((service) => NetworkInfo(
        ssid: service.ssid,
        password: service.additionalInfo['password'] ?? '',
        signalStrength: service.signalStrength ?? 0,
        roomId: service.roomId,
        brokerIp: service.brokerIp,
        brokerPort: service.brokerPort,
        classCode: service.additionalInfo['classCode'] ?? '',
        subject: service.additionalInfo['subject'] ?? '',
        isSecure: true,
      )).toList();

      // Filter services based on allowed SSIDs
      final filteredNetworks = networkInfos.where((network) {
        if (allowedSsids.isNotEmpty && !allowedSsids.contains(network.ssid)) {
          return false;
        }
        return network.signalStrength > -70;
      }).toList();

      if (filteredNetworks.isEmpty) {
        return JoinResult(
          success: false,
          error: 'No suitable networks found',
          availableNetworks: networkInfos,
        );
      }

      // Select best network
      final bestNetwork = filteredNetworks.first;

      // Join the network
      final joinResultMap = await _joinNetwork(
        network: bestNetwork,
        studentId: studentId,
      );

      final joinResult = JoinResult.fromMap(joinResultMap);

      if (joinResult.success) {
        _isRoot = false;
        _currentRoomId = bestNetwork.roomId;
        _currentNetwork = bestNetwork;

        // Connect to MQTT broker
        await _connectToMqttBroker(bestNetwork.brokerIp, bestNetwork.brokerPort);

        // Initialize as student node
        await _initializeAsStudentNode(studentId, studentInfo);

        // Set up data handler
        if (onDataReceived != null) {
          _dataController.stream.listen(onDataReceived);
        }

        // Send join notification
        await _sendJoinData(studentId, studentInfo);

        _eventController.add(NetworkEvent.joined(bestNetwork));

        if (_enableDebugLogs) {
          print('CrossP2PNetwork: Joined network successfully - ${bestNetwork.ssid}');
        }
      }

      return JoinResult(
        success: joinResult.success,
        error: joinResult.error,
        networkInfo: bestNetwork,
        availableNetworks: networkInfos,
      );

    } catch (e) {
      _eventController.add(NetworkEvent.error('Network join failed: $e'));
      rethrow;
    }
  }

  /// Send data to the network
  static Future<void> sendData(
      Map<String, dynamic> data, {
        String topic = 'attendance',
        int qos = 1,
      }) async {
    return _instance._sendData(data, topic: topic, qos: qos);
  }

  Future<void> _sendData(
      Map<String, dynamic> data, {
        String topic = 'attendance',
        int qos = 1,
      }) async {
    _checkConnected();

    try {
      final payload = json.encode(data);
      final mqttTopic = '${_getTopicPrefix()}/$topic';

      if (_mqttClient?.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(payload);

        _mqttClient!.publishMessage(mqttTopic, MqttQos.atLeastOnce, builder.payload!);

        _eventController.add(NetworkEvent.dataSent(topic, data));

        if (_enableDebugLogs) {
          print('CrossP2PNetwork: Data sent to topic $mqttTopic');
        }
      } else {
        throw Exception('MQTT client not connected');
      }
    } catch (e) {
      _eventController.add(NetworkEvent.error('Data send failed: $e'));
      rethrow;
    }
  }

  /// Send quiz to all students (Teacher only)
  static Future<void> sendQuiz(
      Map<String, dynamic> quiz, {
        String? quizId,
      }) async {
    return _instance._sendQuiz(quiz, quizId: quizId);
  }

  Future<void> _sendQuiz(
      Map<String, dynamic> quiz, {
        String? quizId,
      }) async {
    _checkRoot();

    final quizData = {
      'quizId': quizId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'quiz': quiz,
      'timestamp': DateTime.now().toIso8601String(),
      'fromRoot': true,
    };

    await _sendData(quizData, topic: 'quiz/${quizData['quizId']}');
    _eventController.add(NetworkEvent.quizSent(quizData));
  }

  /// Send heartbeat signal
  static Future<void> sendHeartbeat() async {
    return _instance._sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    _checkConnected();

    try {
      final heartbeat = {
        'nodeId': _currentNode?.nodeId,
        'timestamp': DateTime.now().toIso8601String(),
        'batteryLevel': await _getBatteryLevel(),
        'signalStrength': await _getSignalStrength(),
        'isRoot': _isRoot,
      };

      await _sendData(heartbeat, topic: 'heartbeat');
      _eventController.add(NetworkEvent.heartbeat(_currentNode?.nodeId ?? 'unknown'));

    } catch (e) {
      _eventController.add(NetworkEvent.error('Heartbeat failed: $e'));
    }
  }

  /// Scan for available networks
  static Future<List<NetworkInfo>> scanNetworks() async {
    return _instance._scanNetworks();
  }

  Future<List<NetworkInfo>> _scanNetworks() async {
    _checkInitialized();

    try {
      final result = await _methodChannel.invokeMethod('scanNetworks');
      final resultMap = Map<String, dynamic>.from(result);
      final networksList = resultMap['networks'] as List? ?? [];

      final networks = networksList.map((n) => NetworkInfo.fromMap(Map<String, dynamic>.from(n))).toList();

      return networks;
    } catch (e) {
      _eventController.add(NetworkEvent.error('Network scan failed: $e'));
      return [];
    }
  }

  /// Disconnect from network
  static Future<void> disconnect({bool heal = true}) async {
    return _instance._disconnect(heal: heal);
  }

  Future<void> _disconnect({bool heal = true}) async {
    try {
      // Stop timers
      _heartbeatTimer?.cancel();
      _healthCheckTimer?.cancel();

      // Disconnect MQTT
      _mqttClient?.disconnect();

      // Stop service discovery
      await _serviceDiscovery.stopBroadcast();
      await _serviceDiscovery.stopScan();

      // Notify network graph
      if (_currentNode != null && heal) {
        await _networkGraph.handleNodeDisconnect(_currentNode!.nodeId);
      }

      // Clear state
      _isConnected = false;
      _isRoot = false;
      _currentNode = null;
      _currentNetwork = null;
      _currentRoomId = null;

      // Call native disconnect
      await _methodChannel.invokeMethod('disconnect', {'heal': heal});

      _eventController.add(NetworkEvent.disconnected());

      if (_enableDebugLogs) {
        print('CrossP2PNetwork: Disconnected from network');
      }

    } catch (e) {
      _eventController.add(NetworkEvent.error('Disconnect failed: $e'));
    }
  }

  /// Get stream of network events
  static Stream<NetworkEvent> getEventStream() {
    return _instance._eventController.stream;
  }

  /// Get stream of received data
  static Stream<Map<String, dynamic>> getDataStream({String? topic}) {
    if (topic != null) {
      return _instance._dataController.stream.where((data) => data['topic'] == topic);
    }
    return _instance._dataController.stream;
  }

  // Utility methods
  String _generateRoomId() {
    return 'room_${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }

  String _generateSsid(String classCode, String? subject) {
    final prefix = 'EduP2P';
    final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 12);
    return '${prefix}_${classCode}_${subject ?? 'Class'}_$timestamp'.substring(0, 32);
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^&*';
    return List.generate(12, (index) => chars[DateTime.now().microsecond % chars.length]).join();
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length]).join();
  }

  String _getTopicPrefix() {
    return _currentRoomId != null ? 'attendance/$_currentRoomId' : 'attendance';
  }

  Future<int> _getBatteryLevel() async {
    try {
      final result = await _methodChannel.invokeMethod('getBatteryLevel');
      final resultMap = Map<String, dynamic>.from(result);
      return resultMap['batteryLevel'] ?? -1;
    } catch (e) {
      return -1;
    }
  }

  Future<int> _getSignalStrength() async {
    try {
      final result = await _methodChannel.invokeMethod('getSignalStrength');
      final resultMap = Map<String, dynamic>.from(result);
      return resultMap['signalStrength'] ?? -100;
    } catch (e) {
      return -100;
    }
  }

  // MQTT Methods
  Future<void> _startMqttBroker() async {
    // For root node, we'd typically start an embedded broker
    // This is a simplified implementation - in production you'd use a proper embedded broker
    _mqttClient = MqttServerClient('localhost', '');
    await _connectMqttClient();
  }

  Future<void> _connectToMqttBroker(String brokerIp, int brokerPort) async {
    _mqttClient = MqttServerClient(brokerIp, '');
    _mqttClient!.port = brokerPort;
    await _connectMqttClient();
  }

  Future<void> _connectMqttClient() async {
    if (_mqttClient == null) return;

    try {
      // Set logging if debug is enabled
      if (_enableDebugLogs) {
        _mqttClient!.logging(on: true);
      }

      // Set connection parameters
      _mqttClient!.keepAlivePeriod = 60;
      _mqttClient!.onDisconnected = _onMqttDisconnected;
      _mqttClient!.onConnected = _onMqttConnected;
      _mqttClient!.onSubscribed = _onMqttSubscribed;

      final connMessage = MqttConnectMessage()
          .authenticateAs(_currentNode?.nodeId ?? 'unknown', '')
          .withWillTopic('${_getTopicPrefix()}/disconnect')
          .withWillMessage('{"nodeId": "${_currentNode?.nodeId}", "timestamp": "${DateTime.now().toIso8601String()}"}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _mqttClient!.connectionMessage = connMessage;

      await _mqttClient!.connect();

    } catch (e) {
      _eventController.add(NetworkEvent.error('MQTT connection failed: $e'));
    }
  }

  void _onMqttConnected() {
    _isConnected = true;

    // Subscribe to relevant topics
    final topicPrefix = _getTopicPrefix();
    _mqttClient!.subscribe('$topicPrefix/#', MqttQos.atLeastOnce);

    // Set up message listener
    _mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final message in messages) {
        _handleMqttMessage(message);
      }
    });

    _eventController.add(NetworkEvent.info('MQTT connected successfully'));
  }

  void _onMqttDisconnected() {
    _isConnected = false;
    _eventController.add(NetworkEvent.info('MQTT disconnected'));
  }

  void _onMqttSubscribed(String topic) {
    if (_enableDebugLogs) {
      print('CrossP2PNetwork: Subscribed to topic: $topic');
    }
  }

  void _handleMqttMessage(MqttReceivedMessage<MqttMessage> message) {
    try {
      final topic = message.topic;
      final payload = message.payload;

      if (payload is MqttPublishMessage) {
        final payloadBytes = payload.payload.message;
        final payloadString = utf8.decode(payloadBytes);
        final data = json.decode(payloadString) as Map<String, dynamic>;

        // Add topic information to data
        data['topic'] = topic;

        // Forward to data controller
        _dataController.add(data);

        // Handle specific message types
        if (topic.contains('heartbeat') && data['nodeId'] != null) {
          _handleHeartbeatMessage(data);
        }
      }
    } catch (e) {
      if (_enableDebugLogs) {
        print('CrossP2PNetwork: Failed to parse MQTT message: $e');
      }
    }
  }

  void _handleHeartbeatMessage(Map<String, dynamic> data) {
    final nodeId = data['nodeId'] as String;
    final heartbeat = HeartbeatData(
      batteryLevel: data['batteryLevel'] as int? ?? 0,
      signalStrength: data['signalStrength'] as int? ?? 0,
      latency: 0, // Would calculate based on timestamp
    );

    _networkGraph.updateNodeHeartbeat(nodeId, heartbeat);
  }

  // Node initialization
  Future<void> _initializeAsRootNode() async {
    final deviceInfo = await _getDeviceInfo();
    _currentNode = NetworkNode(
      nodeId: 'root_${deviceInfo['deviceId']}',
      isRoot: true,
      deviceInfo: deviceInfo,
    );

    _networkGraph.initialize(_currentNode!);
    _startHeartbeatTimer();
    _startHealthCheckTimer();
  }

  Future<void> _initializeAsStudentNode(String studentId, Map<String, dynamic> studentInfo) async {
    final deviceInfo = await _getDeviceInfo();
    _currentNode = NetworkNode(
      nodeId: 'student_${studentId}_${deviceInfo['deviceId']}',
      isRoot: false,
      deviceInfo: deviceInfo,
    );

    // Don't call addNode here - wait for the graph to handle it properly
    _startHeartbeatTimer();
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'platform': 'unknown',
        'version': 'unknown',
        'deviceId': 'unknown',
      };
    }
  }

  Future<Map<String, dynamic>> _joinNetwork({
    required NetworkInfo network,
    required String studentId,
  }) async {
    final result = await _methodChannel.invokeMethod('joinNetwork', {
      'ssid': network.ssid,
      'password': network.password,
      'studentId': studentId,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<void> _sendJoinData(String studentId, Map<String, dynamic> studentInfo) async {
    final joinData = {
      'studentId': studentId,
      'studentInfo': studentInfo,
      'action': 'join',
      'timestamp': DateTime.now().toIso8601String(),
      'nodeId': _currentNode?.nodeId,
    };

    await _sendData(joinData, topic: 'join');
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    // Implementation would check network health and trigger rebalancing if needed
    if (_isRoot) {
      final stats = _networkGraph.getNetworkStats();
      if (stats['loadBalance'] as double < 0.7) {
        _eventController.add(NetworkEvent.info('Network may need rebalancing'));
      }
    }
  }

  // Event handlers
  void _handlePlatformEvent(dynamic event) {
    try {
      final eventMap = Map<String, dynamic>.from(event);
      final networkEvent = NetworkEvent.fromMap(eventMap);
      _eventController.add(networkEvent);
    } catch (e) {
      if (_enableDebugLogs) {
        print('CrossP2PNetwork: Failed to parse platform event: $e');
      }
    }
  }

  void _handlePlatformData(dynamic data) {
    try {
      final dataMap = Map<String, dynamic>.from(data);
      _dataController.add(dataMap);
    } catch (e) {
      if (_enableDebugLogs) {
        print('CrossP2PNetwork: Failed to parse platform data: $e');
      }
    }
  }

  void _handleGraphEvent(GraphEvent event) {
    // Convert graph events to network events
    final networkEvent = NetworkEvent.info('Graph event: ${event.message}');
    _eventController.add(networkEvent);
  }

  // Validation methods
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('Plugin not initialized. Call initialize() first.');
    }
  }

  void _checkConnected() {
    if (!_isConnected) {
      throw StateError('Not connected to any network.');
    }
  }

  void _checkRoot() {
    if (!_isRoot) {
      throw StateError('This operation is only available for root nodes.');
    }
  }

  // Cleanup
  Future<void> dispose() async {
    await disconnect(heal: false);

    _heartbeatTimer?.cancel();
    _healthCheckTimer?.cancel();

    _eventSubscription?.cancel();
    _dataSubscription?.cancel();
    _graphEventSubscription?.cancel();

    await _eventController.close();
    await _dataController.close();

    _isInitialized = false;

    if (_enableDebugLogs) {
      print('CrossP2PNetwork: Plugin disposed');
    }
  }

  // Getters for current state
  static bool get isInitialized => _instance._isInitialized;
  static bool get isConnected => _instance._isConnected;
  static bool get isRoot => _instance._isRoot;
  static String? get currentRoomId => _instance._currentRoomId;
  static NetworkNode? get currentNode => _instance._currentNode;
  static NetworkInfo? get currentNetwork => _instance._currentNetwork;
  static BfsGraph get networkGraph => _instance._networkGraph;
}