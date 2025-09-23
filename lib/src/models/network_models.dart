import 'dart:convert';

class NetworkNode {
  final String nodeId;
  final bool isRoot;
  final Map<String, dynamic> deviceInfo;
  final DateTime joinTime;
  final List<String> children;
  String? parentId;
  int batteryLevel;
  int signalStrength;
  DateTime lastHeartbeat;

  NetworkNode({
    required this.nodeId,
    required this.isRoot,
    required this.deviceInfo,
    DateTime? joinTime,
    List<String>? children,
    this.parentId,
    this.batteryLevel = 100,
    this.signalStrength = 0,
    DateTime? lastHeartbeat,
  }) : joinTime = joinTime ?? DateTime.now(),
        children = children ?? [],
        lastHeartbeat = lastHeartbeat ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nodeId': nodeId,
      'isRoot': isRoot,
      'deviceInfo': deviceInfo,
      'joinTime': joinTime.toIso8601String(),
      'children': children,
      'parentId': parentId,
      'batteryLevel': batteryLevel,
      'signalStrength': signalStrength,
      'lastHeartbeat': lastHeartbeat.toIso8601String(),
    };
  }

  factory NetworkNode.fromMap(Map<String, dynamic> map) {
    return NetworkNode(
      nodeId: map['nodeId'] ?? '',
      isRoot: map['isRoot'] ?? false,
      deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] ?? {}),
      joinTime: DateTime.tryParse(map['joinTime'] ?? '') ?? DateTime.now(),
      children: List<String>.from(map['children'] ?? []),
      parentId: map['parentId'],
      batteryLevel: map['batteryLevel'] ?? 100,
      signalStrength: map['signalStrength'] ?? 0,
      lastHeartbeat: DateTime.tryParse(map['lastHeartbeat'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory NetworkNode.fromJson(String source) => NetworkNode.fromMap(json.decode(source));

  NetworkNode copyWith({
    String? nodeId,
    bool? isRoot,
    Map<String, dynamic>? deviceInfo,
    DateTime? joinTime,
    List<String>? children,
    String? parentId,
    int? batteryLevel,
    int? signalStrength,
    DateTime? lastHeartbeat,
  }) {
    return NetworkNode(
      nodeId: nodeId ?? this.nodeId,
      isRoot: isRoot ?? this.isRoot,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      joinTime: joinTime ?? this.joinTime,
      children: children ?? this.children,
      parentId: parentId ?? this.parentId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }

  bool get isHealthy {
    final timeSinceHeartbeat = DateTime.now().difference(lastHeartbeat);
    return timeSinceHeartbeat.inSeconds < 30 && batteryLevel > 10;
  }

  int get score {
    int score = 0;
    score += batteryLevel;
    score += signalStrength > 0 ? 50 : 0;
    score += isHealthy ? 25 : 0;
    score += children.length < 8 ? 25 : 0;
    return score;
  }
}

class NetworkInfo {
  final String ssid;
  final String? password;
  final int signalStrength;
  final String? roomId;
  final String brokerIp;
  final int brokerPort;
  final String? classCode;
  final String? subject;
  final bool isSecure;
  final DateTime discoveredAt;

  NetworkInfo({
    required this.ssid,
    this.password,
    required this.signalStrength,
    this.roomId,
    required this.brokerIp,
    required this.brokerPort,
    this.classCode,
    this.subject,
    this.isSecure = true,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'password': password,
      'signalStrength': signalStrength,
      'roomId': roomId,
      'brokerIp': brokerIp,
      'brokerPort': brokerPort,
      'classCode': classCode,
      'subject': subject,
      'isSecure': isSecure,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory NetworkInfo.fromMap(Map<String, dynamic> map) {
    return NetworkInfo(
      ssid: map['ssid'] ?? '',
      password: map['password'],
      signalStrength: map['signalStrength'] ?? 0,
      roomId: map['roomId'],
      brokerIp: map['brokerIp'] ?? '',
      brokerPort: map['brokerPort'] ?? 1883,
      classCode: map['classCode'],
      subject: map['subject'],
      isSecure: map['isSecure'] ?? true,
      discoveredAt: DateTime.tryParse(map['discoveredAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory NetworkInfo.fromJson(String source) => NetworkInfo.fromMap(json.decode(source));
}

class RoomCreationResult {
  final String roomId;
  final String ssid;
  final String password;
  final String brokerIp;
  final int brokerPort;
  final String? networkInterface;
  final bool success;
  final String? error;
  final DateTime createdAt;

  RoomCreationResult({
    required this.roomId,
    required this.ssid,
    required this.password,
    required this.brokerIp,
    required this.brokerPort,
    this.networkInterface,
    required this.success,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'ssid': ssid,
      'password': password,
      'brokerIp': brokerIp,
      'brokerPort': brokerPort,
      'networkInterface': networkInterface,
      'success': success,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RoomCreationResult.fromMap(Map<String, dynamic> map) {
    return RoomCreationResult(
      roomId: map['roomId'] ?? '',
      ssid: map['ssid'] ?? '',
      password: map['password'] ?? '',
      brokerIp: map['brokerIp'] ?? '',
      brokerPort: map['brokerPort'] ?? 1883,
      networkInterface: map['networkInterface'],
      success: map['success'] ?? false,
      error: map['error'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory RoomCreationResult.fromJson(String source) =>
      RoomCreationResult.fromMap(json.decode(source));
}

class JoinResult {
  final bool success;
  final String? error;
  final NetworkInfo? networkInfo;
  final String? brokerIp;
  final int? brokerPort;
  final List<NetworkInfo> availableNetworks;
  final DateTime joinedAt;

  JoinResult({
    required this.success,
    this.error,
    this.networkInfo,
    this.brokerIp,
    this.brokerPort,
    List<NetworkInfo>? availableNetworks,
    DateTime? joinedAt,
  }) : availableNetworks = availableNetworks ?? [],
        joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'error': error,
      'networkInfo': networkInfo?.toMap(),
      'brokerIp': brokerIp,
      'brokerPort': brokerPort,
      'availableNetworks': availableNetworks.map((n) => n.toMap()).toList(),
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory JoinResult.fromMap(Map<String, dynamic> map) {
    return JoinResult(
      success: map['success'] ?? false,
      error: map['error'],
      networkInfo: map['networkInfo'] != null
          ? NetworkInfo.fromMap(Map<String, dynamic>.from(map['networkInfo']))
          : null,
      brokerIp: map['brokerIp'],
      brokerPort: map['brokerPort'],
      availableNetworks: (map['availableNetworks'] as List?)
          ?.map((n) => NetworkInfo.fromMap(Map<String, dynamic>.from(n)))
          .toList() ?? [],
      joinedAt: DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory JoinResult.fromJson(String source) => JoinResult.fromMap(json.decode(source));
}

enum NetworkEventType {
  initialized,
  roomCreated,
  joined,
  disconnected,
  nodeConnected,
  nodeDisconnected,
  dataSent,
  dataReceived,
  quizSent,
  quizReceived,
  heartbeat,
  error,
  warning,
  info,
}

class NetworkEvent {
  final NetworkEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  NetworkEvent({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Factory constructors for common events
  factory NetworkEvent.initialized() {
    return NetworkEvent(
      type: NetworkEventType.initialized,
      message: 'Plugin initialized successfully',
    );
  }

  factory NetworkEvent.roomCreated(RoomCreationResult result) {
    return NetworkEvent(
      type: NetworkEventType.roomCreated,
      message: 'Room created: ${result.ssid}',
      data: result.toMap(),
    );
  }

  factory NetworkEvent.joined(NetworkInfo network) {
    return NetworkEvent(
      type: NetworkEventType.joined,
      message: 'Joined network: ${network.ssid}',
      data: network.toMap(),
    );
  }

  factory NetworkEvent.disconnected() {
    return NetworkEvent(
      type: NetworkEventType.disconnected,
      message: 'Disconnected from network',
    );
  }

  factory NetworkEvent.nodeConnected(NetworkNode node) {
    return NetworkEvent(
      type: NetworkEventType.nodeConnected,
      message: 'Node connected: ${node.nodeId}',
      data: node.toMap(),
    );
  }

  factory NetworkEvent.nodeDisconnected(String nodeId) {
    return NetworkEvent(
      type: NetworkEventType.nodeDisconnected,
      message: 'Node disconnected: $nodeId',
      data: {'nodeId': nodeId},
    );
  }

  factory NetworkEvent.dataSent(String topic, Map<String, dynamic> data) {
    return NetworkEvent(
      type: NetworkEventType.dataSent,
      message: 'Data sent to topic: $topic',
      data: {'topic': topic, 'payload': data},
    );
  }

  factory NetworkEvent.dataReceived(String topic, Map<String, dynamic> data) {
    return NetworkEvent(
      type: NetworkEventType.dataReceived,
      message: 'Data received from topic: $topic',
      data: {'topic': topic, 'payload': data},
    );
  }

  factory NetworkEvent.quizSent(Map<String, dynamic> quiz) {
    return NetworkEvent(
      type: NetworkEventType.quizSent,
      message: 'Quiz sent: ${quiz['quizId']}',
      data: quiz,
    );
  }

  factory NetworkEvent.quizReceived(Map<String, dynamic> quiz) {
    return NetworkEvent(
      type: NetworkEventType.quizReceived,
      message: 'Quiz received: ${quiz['quizId']}',
      data: quiz,
    );
  }

  factory NetworkEvent.heartbeat(String nodeId) {
    return NetworkEvent(
      type: NetworkEventType.heartbeat,
      message: 'Heartbeat from: $nodeId',
      data: {'nodeId': nodeId},
    );
  }

  factory NetworkEvent.error(String error) {
    return NetworkEvent(
      type: NetworkEventType.error,
      message: 'Error: $error',
      data: {'error': error},
    );
  }

  factory NetworkEvent.warning(String warning) {
    return NetworkEvent(
      type: NetworkEventType.warning,
      message: 'Warning: $warning',
      data: {'warning': warning},
    );
  }

  factory NetworkEvent.info(String info) {
    return NetworkEvent(
      type: NetworkEventType.info,
      message: 'Info: $info',
      data: {'info': info},
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

  factory NetworkEvent.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] ?? '';
    NetworkEventType type = NetworkEventType.info;

    for (final eventType in NetworkEventType.values) {
      if (eventType.toString() == typeString) {
        type = eventType;
        break;
      }
    }

    return NetworkEvent(
      type: type,
      message: map['message'] ?? '',
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'])
          : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory NetworkEvent.fromJson(String source) =>
      NetworkEvent.fromMap(json.decode(source));

  bool get isError => type == NetworkEventType.error;
  bool get isWarning => type == NetworkEventType.warning;
  bool get isInfo => type == NetworkEventType.info;
  bool get isSuccess => !isError && !isWarning;
}

/// Student information model
class StudentInfo {
  final String studentId;
  final String rollNo;
  final String studentName;
  final String studentEmail;
  final String studentMobile;
  final DateTime joiningTime;
  final DateTime? leavingTime;
  final int joiningDuration; // in seconds
  final List<QuizResponse> quizResponses;
  final List<HeartbeatData> heartbeats;

  StudentInfo({
    required this.studentId,
    required this.rollNo,
    required this.studentName,
    required this.studentEmail,
    required this.studentMobile,
    DateTime? joiningTime,
    this.leavingTime,
    this.joiningDuration = 0,
    List<QuizResponse>? quizResponses,
    List<HeartbeatData>? heartbeats,
  }) : joiningTime = joiningTime ?? DateTime.now(),
        quizResponses = quizResponses ?? [],
        heartbeats = heartbeats ?? [];

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'rollNo': rollNo,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentMobile': studentMobile,
      'joiningTime': joiningTime.toIso8601String(),
      'leavingTime': leavingTime?.toIso8601String(),
      'joiningDuration': joiningDuration,
      'quizResponses': quizResponses.map((x) => x.toMap()).toList(),
      'heartbeats': heartbeats.map((x) => x.toMap()).toList(),
    };
  }

  factory StudentInfo.fromMap(Map<String, dynamic> map) {
    return StudentInfo(
      studentId: map['studentId'] ?? '',
      rollNo: map['rollNo'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      studentMobile: map['studentMobile'] ?? '',
      joiningTime: DateTime.tryParse(map['joiningTime'] ?? '') ?? DateTime.now(),
      leavingTime: map['leavingTime'] != null
          ? DateTime.tryParse(map['leavingTime'])
          : null,
      joiningDuration: map['joiningDuration'] ?? 0,
      quizResponses: (map['quizResponses'] as List?)
          ?.map((x) => QuizResponse.fromMap(Map<String, dynamic>.from(x)))
          .toList() ?? [],
      heartbeats: (map['heartbeats'] as List?)
          ?.map((x) => HeartbeatData.fromMap(Map<String, dynamic>.from(x)))
          .toList() ?? [],
    );
  }

  String toJson() => json.encode(toMap());
  factory StudentInfo.fromJson(String source) =>
      StudentInfo.fromMap(json.decode(source));

  StudentInfo copyWith({
    String? studentId,
    String? rollNo,
    String? studentName,
    String? studentEmail,
    String? studentMobile,
    DateTime? joiningTime,
    DateTime? leavingTime,
    int? joiningDuration,
    List<QuizResponse>? quizResponses,
    List<HeartbeatData>? heartbeats,
  }) {
    return StudentInfo(
      studentId: studentId ?? this.studentId,
      rollNo: rollNo ?? this.rollNo,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      studentMobile: studentMobile ?? this.studentMobile,
      joiningTime: joiningTime ?? this.joiningTime,
      leavingTime: leavingTime ?? this.leavingTime,
      joiningDuration: joiningDuration ?? this.joiningDuration,
      quizResponses: quizResponses ?? this.quizResponses,
      heartbeats: heartbeats ?? this.heartbeats,
    );
  }

  bool get isActive => leavingTime == null;

  Duration get totalDuration {
    if (leavingTime != null) {
      return leavingTime!.difference(joiningTime);
    }
    return DateTime.now().difference(joiningTime);
  }
}

/// Quiz response model
class QuizResponse {
  final String quizId;
  final String questionId;
  final String answer;
  final DateTime answeredAt;
  final bool isCorrect;

  QuizResponse({
    required this.quizId,
    required this.questionId,
    required this.answer,
    DateTime? answeredAt,
    this.isCorrect = false,
  }) : answeredAt = answeredAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'questionId': questionId,
      'answer': answer,
      'answeredAt': answeredAt.toIso8601String(),
      'isCorrect': isCorrect,
    };
  }

  factory QuizResponse.fromMap(Map<String, dynamic> map) {
    return QuizResponse(
      quizId: map['quizId'] ?? '',
      questionId: map['questionId'] ?? '',
      answer: map['answer'] ?? '',
      answeredAt: DateTime.tryParse(map['answeredAt'] ?? '') ?? DateTime.now(),
      isCorrect: map['isCorrect'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());
  factory QuizResponse.fromJson(String source) =>
      QuizResponse.fromMap(json.decode(source));
}

/// Heartbeat data model
class HeartbeatData {
  final DateTime timestamp;
  final int batteryLevel;
  final int signalStrength;
  final int latency;
  final bool isHealthy;

  HeartbeatData({
    DateTime? timestamp,
    required this.batteryLevel,
    required this.signalStrength,
    required this.latency,
    bool? isHealthy,
  }) : timestamp = timestamp ?? DateTime.now(),
        isHealthy = isHealthy ?? (batteryLevel > 20 && signalStrength > -70);

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'batteryLevel': batteryLevel,
      'signalStrength': signalStrength,
      'latency': latency,
      'isHealthy': isHealthy,
    };
  }

  factory HeartbeatData.fromMap(Map<String, dynamic> map) {
    return HeartbeatData(
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      batteryLevel: map['batteryLevel'] ?? 0,
      signalStrength: map['signalStrength'] ?? 0,
      latency: map['latency'] ?? 0,
      isHealthy: map['isHealthy'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());
  factory HeartbeatData.fromJson(String source) =>
      HeartbeatData.fromMap(json.decode(source));
}