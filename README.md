# CrossP2P Network Plugin

A comprehensive Flutter plugin that enables cross-platform peer-to-peer networking for attendance systems with Wi-Fi Aware support, hotspot management, and service discovery across Android and iOS.

## Features

### 🚀 Core Capabilities
- **Cross-Platform P2P Networking**: Seamless Android-iOS communication
- **Wi-Fi Aware Support**: Native iOS 19+ and Android 8+ support for true P2P
- **Hotspot Fallback**: Automatic fallback to Wi-Fi hotspots when needed
- **Scalable Architecture**: BFS graph topology supporting 100+ devices
- **Real-time Communication**: Embedded MQTT for pub/sub messaging
- **Service Discovery**: DNS-SD/Bonjour for automatic network detection
- **Auto-healing**: Network resilience with automatic recovery
- **Battery Optimization**: Adaptive heartbeats and power management

### 📱 Platform Support
- **Android**: 8.0+ (API 26+) with enhanced support for Android 10+
- **iOS**: 12.0+ with Wi-Fi Aware support on iOS 19+
- **Device Compatibility**: Optimized for both old and new devices

### 🎯 Use Cases
- Educational attendance systems
- Classroom polling and quizzes
- Offline group communication
- Local mesh networking
- Event check-in systems

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  cross_p2p_network: ^1.2.0
```

## Quick Start

### 1. Initialize the Plugin

```dart
import 'package:cross_p2p_network/cross_p2p_network.dart';

// Initialize with default settings
await CrossP2PNetwork.initialize();

// Or with custom configuration
await CrossP2PNetwork.initialize(
  serviceType: '_attendance._tcp',
  preferAware: true,
  enableDebugLogs: false,
);
```

### 2. Teacher Mode (Create Room)

```dart
// Create a new attendance room
final result = await CrossP2PNetwork.createRoom(
  classCode: 'MATH101',
  expectedSize: 50,
  subject: 'Mathematics',
  onDataReceived: (data) {
    // Handle student data (attendance, responses, etc.)
    print('Received data: $data');
  },
  onQuizResponses: (responses) {
    // Handle quiz responses from students
    print('Quiz responses: ${responses.length}');
  },
);

if (result.success) {
  print('Room created: ${result.ssid}');
  print('Password: ${result.password}');
  print('Room ID: ${result.roomId}');
} else {
  print('Failed to create room: ${result.error}');
}
```

### 3. Student Mode (Join Room)

```dart
// Student information
final studentInfo = {
  'studentId': 'STU_12345',
  'rollNo': 'CS001',
  'studentName': 'John Doe',
  'studentEmail': 'john@example.com',
  'studentMobile': '+1234567890',
};

// Scan and join available networks
final joinResult = await CrossP2PNetwork.scanAndJoin(
  studentId: 'STU_12345',
  studentInfo: studentInfo,
  onDataReceived: (data) {
    // Handle teacher data (quizzes, announcements, etc.)
    if (data['topic']?.toString().contains('quiz')) {
      _handleQuiz(data);
    }
  },
);

if (joinResult.success) {
  print('Joined network successfully');
} else {
  print('Failed to join: ${joinResult.error}');
}
```

### 4. Send Data and Heartbeats

```dart
// Send attendance data
await CrossP2PNetwork.sendData({
  'action': 'attendance',
  'timestamp': DateTime.now().toIso8601String(),
  'location': 'Room 101',
});

// Send quiz response
await CrossP2PNetwork.sendData({
  'quizId': 'Q123',
  'questionId': '1',
  'answer': 'Option A',
}, topic: 'responses');

// Send periodic heartbeat
await CrossP2PNetwork.sendHeartbeat();
```

### 5. Listen to Events

```dart
// Listen to network events
CrossP2PNetwork.getEventStream().listen((event) {
  switch (event.type) {
    case NetworkEventType.initialized:
      print('Plugin initialized');
      break;
    case NetworkEventType.roomCreated:
      print('Room created: ${event.message}');
      break;
    case NetworkEventType.joined:
      print('Joined network: ${event.message}');
      break;
    case NetworkEventType.error:
      print('Error: ${event.message}');
      break;
  }
});

// Listen to data stream
CrossP2PNetwork.getDataStream(topic: 'quiz').listen((data) {
  print('Received quiz data: $data');
});
```

## Architecture Overview

### Network Topology
The plugin uses a **BFS (Breadth-First Search) graph topology** to create a hierarchical network:

```
Root (Teacher)
├── Student 1
├── Student 2
│   ├── Student 3
│   └── Student 4
└── Student 5
    ├── Student 6
    └── Student 7
```

### Key Components

1. **Network Formation**
    - **Wi-Fi Aware** (Primary): Direct P2P for iOS 19+ and Android 8+
    - **Wi-Fi Hotspot** (Fallback): LocalOnlyHotspot for Android, Manual setup for iOS

2. **Service Discovery**
    - **Android**: Network Service Discovery (NSD)
    - **iOS**: Bonjour/NetService
    - **Automatic filtering** based on class codes and allowed networks

3. **Communication Layer**
    - **MQTT**: Lightweight pub/sub messaging
    - **Topics**: `attendance/{roomId}/{nodeId}`, `quiz/{roomId}/{quizId}`
    - **QoS**: Configurable quality of service levels

4. **Auto-healing**
    - **Health monitoring**: Periodic heartbeat checking
    - **Node recovery**: Automatic reconnection of orphaned nodes
    - **Root election**: Bully algorithm for root node replacement

## Platform-Specific Implementation

### Android Features
- **Wi-Fi Aware**: Native `WifiAwareManager` support
- **Hotspot Creation**: `LocalOnlyHotspot` for Android 8+
- **Network Suggestions**: `WifiNetworkSuggestion` for auto-join (Android 10+)
- **Service Discovery**: Network Service Discovery (NSD)
- **Battery Optimization**: `BatteryManager` integration

### iOS Features
- **Wi-Fi Aware**: Native `WiFiAware` framework (iOS 19+)
- **Hotspot Join**: `NEHotspotConfiguration` with minimal prompts
- **Service Discovery**: Bonjour/NetService
- **Settings Integration**: Automatic clipboard and Settings app guidance
- **Network Extensions**: `NetworkExtension` framework support

## Configuration

### Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Required Permissions -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" 
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Hardware Features -->
<uses-feature android:name="android.hardware.wifi" android:required="true" />
<uses-feature android:name="android.hardware.wifi.aware" android:required="false" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<!-- Required Permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Wi-Fi scanning required for class detection</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access for attendance system</string>
<key>NSBonjourServices</key>
<array>
  <string>_attendance._tcp</string>
</array>

<!-- Entitlements -->
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

## API Reference

### Core Methods

#### `initialize()`
Initialize the plugin with configuration options.
```dart
static Future<void> initialize({
  String serviceType = '_attendance._tcp',
  bool preferAware = true,
  bool enableDebugLogs = false,
})
```

#### `createRoom()`
Create a new attendance room (Teacher mode).
```dart
static Future<RoomCreationResult> createRoom({
  required String classCode,
  required int expectedSize,
  String? subject,
  Duration? duration,
  Function(Map<String, dynamic>)? onDataReceived,
  Function(List<Map<String, dynamic>>)? onQuizResponses,
})
```

#### `scanAndJoin()`
Scan and join available networks (Student mode).
```dart
static Future<JoinResult> scanAndJoin({
  required String studentId,
  required Map<String, dynamic> studentInfo,
  Function(Map<String, dynamic>)? onDataReceived,
  List<String> allowedSsids = const [],
})
```

#### `sendData()`
Send data to the network.
```dart
static Future<void> sendData(
  Map<String, dynamic> data, {
  String topic = 'attendance',
  int qos = 1,
})
```

#### `sendQuiz()`
Send quiz to all students (Teacher only).
```dart
static Future<void> sendQuiz(
  Map<String, dynamic> quiz, {
  String? quizId,
})
```

### Event Streams

#### `getEventStream()`
Get stream of network events.
```dart
static Stream<NetworkEvent> getEventStream()
```

#### `getDataStream()`
Get stream of received data, optionally filtered by topic.
```dart
static Stream<Map<String, dynamic>> getDataStream({String? topic})
```

### Utility Methods

#### `scanNetworks()`
Scan for available networks.
```dart
static Future<List<NetworkInfo>> scanNetworks()
```

#### `sendHeartbeat()`
Send heartbeat signal.
```dart
static Future<void> sendHeartbeat()
```

#### `disconnect()`
Disconnect from network with optional healing.
```dart
static Future<void> disconnect({bool heal = true})
```

## Data Models

### NetworkEvent
```dart
class NetworkEvent {
  final NetworkEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
}
```

### RoomCreationResult
```dart
class RoomCreationResult {
  final String roomId;
  final String ssid;
  final String password;
  final String brokerIp;
  final int brokerPort;
  final bool success;
  final String? error;
}
```

### JoinResult
```dart
class JoinResult {
  final bool success;
  final String? error;
  final NetworkInfo? networkInfo;
  final List<NetworkInfo> availableNetworks;
}
```

### StudentInfo
```dart
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
}
```

## Advanced Usage

### Custom Network Configuration

```dart
// Initialize with custom settings
await CrossP2PNetwork.initialize(
  serviceType: '_myapp._tcp',
  preferAware: false, // Force hotspot mode
  enableDebugLogs: true,
);

// Create room with specific parameters
final result = await CrossP2PNetwork.createRoom(
  classCode: 'CS101',
  expectedSize: 100,
  subject: 'Computer Science',
  duration: Duration(hours: 2),
);
```

### Real-time Quiz System

```dart
// Teacher: Send quiz
await CrossP2PNetwork.sendQuiz({
  'quizId': 'Q001',
  'title': 'Quick Assessment',
  'questions': [
    {
      'id': '1',
      'text': 'What is 2+2?',
      'type': 'multiple_choice',
      'options': ['3', '4', '5', '6'],
      'correct': '4',
    }
  ],
  'timeLimit': 60, // seconds
});

// Student: Listen for quizzes
CrossP2PNetwork.getDataStream(topic: 'quiz').listen((data) {
  final quiz = data['quiz'];
  showQuizDialog(quiz);
});

// Student: Submit response
await CrossP2PNetwork.sendData({
  'quizId': 'Q001',
  'questionId': '1',
  'answer': '4',
  'submittedAt': DateTime.now().toIso8601String(),
}, topic: 'responses');
```

### Network Health Monitoring

```dart
// Monitor network events
CrossP2PNetwork.getEventStream().listen((event) {
  switch (event.type) {
    case NetworkEventType.nodeConnected:
      final nodeId = event.data?['nodeId'];
      print('Student $nodeId joined');
      break;
    case NetworkEventType.nodeDisconnected:
      final nodeId = event.data?['nodeId'];
      print('Student $nodeId left');
      break;
    case NetworkEventType.error:
      handleNetworkError(event.message);
      break;
  }
});

// Periodic health checks
Timer.periodic(Duration(seconds: 30), (timer) async {
  try {
    await CrossP2PNetwork.sendHeartbeat();
    
    // Check connection quality
    final events = await CrossP2PNetwork.getEventStream()
        .where((e) => e.type == NetworkEventType.heartbeat)
        .take(1)
        .timeout(Duration(seconds: 5))
        .toList();
        
    if (events.isEmpty) {
      print('Warning: Heartbeat timeout - connection may be unstable');
    }
  } catch (e) {
    print('Health check failed: $e');
    // Attempt reconnection if needed
  }
});
```

### Battery Optimization

```dart
// Adaptive heartbeat based on battery level
class BatteryOptimizedHeartbeat {
  Timer? _heartbeatTimer;
  
  void startAdaptiveHeartbeat() {
    _scheduleNextHeartbeat();
  }
  
  void _scheduleNextHeartbeat() async {
    // Get battery level (this would be implemented in the plugin)
    final batteryLevel = await getBatteryLevel();
    
    // Adjust interval based on battery
    int interval = 30; // default 30 seconds
    if (batteryLevel < 20) {
      interval = 120; // 2 minutes when low
    } else if (batteryLevel < 50) {
      interval = 60; // 1 minute when medium
    }
    
    _heartbeatTimer = Timer(Duration(seconds: interval), () async {
      await CrossP2PNetwork.sendHeartbeat();
      _scheduleNextHeartbeat(); // Schedule next
    });
  }
  
  void stop() {
    _heartbeatTimer?.cancel();
  }
}
```

## Error Handling

### Common Error Scenarios

```dart
// Comprehensive error handling
try {
  final result = await CrossP2PNetwork.createRoom(
    classCode: 'MATH101',
    expectedSize: 50,
  );
  
  if (!result.success) {
    switch (result.error) {
      case 'PERMISSION_DENIED':
        showPermissionDialog();
        break;
      case 'HOTSPOT_CREATION_FAILED':
        showHotspotGuidance();
        break;
      case 'WIFI_AWARE_UNAVAILABLE':
        fallbackToHotspot();
        break;
      default:
        showGenericError(result.error);
    }
  }
} catch (e) {
  if (e is TimeoutException) {
    showTimeoutError();
  } else if (e is PlatformException) {
    handlePlatformError(e);
  } else {
    showUnknownError(e);
  }
}
```

### Auto-Recovery Mechanisms

```dart
// Implement auto-recovery for network issues
class NetworkRecoveryManager {
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;
  
  void startMonitoring() {
    CrossP2PNetwork.getEventStream().listen((event) {
      if (event.type == NetworkEventType.disconnected) {
        _handleDisconnection();
      } else if (event.type == NetworkEventType.joined) {
        _reconnectAttempts = 0; // Reset on successful connection
      }
    });
  }
  
  Future<void> _handleDisconnection() async {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      showReconnectionFailedDialog();
      return;
    }
    
    _reconnectAttempts++;
    
    // Wait with exponential backoff
    final delay = Duration(seconds: pow(2, _reconnectAttempts).toInt());
    await Future.delayed(delay);
    
    try {
      // Attempt to rejoin last known network
      await attemptReconnection();
    } catch (e) {
      print('Reconnection attempt ${_reconnectAttempts} failed: $e');
      _handleDisconnection(); // Retry
    }
  }
}
```

## Testing

### Unit Testing

```dart
// test/cross_p2p_network_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_p2p_network/cross_p2p_network.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('CrossP2PNetwork', () {
    test('should initialize successfully', () async {
      // Test initialization
      await CrossP2PNetwork.initialize();
      
      // Verify initialization state
      expect(CrossP2PNetwork.isInitialized, true);
    });
    
    test('should create room with valid parameters', () async {
      final result = await CrossP2PNetwork.createRoom(
        classCode: 'TEST101',
        expectedSize: 10,
      );
      
      expect(result.success, true);
      expect(result.roomId, isNotEmpty);
      expect(result.ssid, contains('TEST101'));
    });
    
    test('should handle invalid room creation', () async {
      expect(
        () => CrossP2PNetwork.createRoom(
          classCode: '',
          expectedSize: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
```

### Integration Testing

```dart
// integration_test/network_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cross_p2p_network/cross_p2p_network.dart';

void main() {
  IntegrationTestWidgetsBinding.ensureInitialized();
  
  group('Network Integration Tests', () {
    testWidgets('complete teacher-student flow', (tester) async {
      // Initialize plugin
      await CrossP2PNetwork.initialize();
      
      // Create room (teacher)
      final roomResult = await CrossP2PNetwork.createRoom(
        classCode: 'INTEGRATION_TEST',
        expectedSize: 2,
      );
      
      expect(roomResult.success, true);
      
      // Simulate student joining
      final studentInfo = {
        'studentId': 'TEST_STUDENT',
        'rollNo': 'T001',
        'studentName': 'Test Student',
        'studentEmail': 'test@example.com',
      };
      
      final joinResult = await CrossP2PNetwork.scanAndJoin(
        studentId: 'TEST_STUDENT',
        studentInfo: studentInfo,
      );
      
      expect(joinResult.success, true);
      
      // Test data exchange
      await CrossP2PNetwork.sendData({'test': 'data'});
      
      // Clean up
      await CrossP2PNetwork.disconnect();
    });
  });
}
```

## Performance Optimization

### Memory Management

```dart
// Implement proper cleanup
class AttendanceManager {
  Timer? _heartbeatTimer;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _dataSubscription;
  
  void initialize() {
    _eventSubscription = CrossP2PNetwork.getEventStream().listen(_handleEvent);
    _dataSubscription = CrossP2PNetwork.getDataStream().listen(_handleData);
  }
  
  void dispose() {
    _heartbeatTimer?.cancel();
    _eventSubscription?.cancel();
    _dataSubscription?.cancel();
    CrossP2PNetwork.dispose();
  }
}
```

### Network Efficiency

```dart
// Batch data sending for efficiency
class DataBatcher {
  final List<Map<String, dynamic>> _batch = [];
  Timer? _batchTimer;
  
  void addData(Map<String, dynamic> data) {
    _batch.add(data);
    
    if (_batch.length >= 10) {
      _sendBatch(); // Send when batch is full
    } else {
      _scheduleBatchSend(); // Or after timeout
    }
  }
  
  void _scheduleBatchSend() {
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(seconds: 5), _sendBatch);
  }
  
  Future<void> _sendBatch() async {
    if (_batch.isEmpty) return;
    
    await CrossP2PNetwork.sendData({
      'batch': List.from(_batch),
      'count': _batch.length,
    });
    
    _batch.clear();
    _batchTimer?.cancel();
  }
}
```

## Security Considerations

### Network Security

```dart
// Implement basic data validation
class SecureDataHandler {
  static Map<String, dynamic> sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      if (_isValidKey(entry.key) && _isValidValue(entry.value)) {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }
  
  static bool _isValidKey(String key) {
    // Validate key format
    return key.length <= 50 && RegExp(r'^[a-zA-Z0-9_]+).hasMatch(key);
  }
  
  static bool _isValidValue(dynamic value) {
    // Validate value type and size
    if (value is String) {
      return value.length <= 1000;
    } else if (value is num) {
      return value.isFinite;
    } else if (value is bool) {
      return true;
    }
    return false;
  }
}
```

### Privacy Protection

```dart
// Anonymize sensitive data
class PrivacyManager {
  static Map<String, dynamic> anonymizeStudentData(Map<String, dynamic> data) {
    final anonymized = Map<String, dynamic>.from(data);
    
    // Replace sensitive fields with hashes
    if (anonymized.containsKey('studentEmail')) {
      anonymized['studentEmailHash'] = _hashString(anonymized['studentEmail']);
      anonymized.remove('studentEmail');
    }
    
    if (anonymized.containsKey('studentMobile')) {
      anonymized['studentMobileHash'] = _hashString(anonymized['studentMobile']);
      anonymized.remove('studentMobile');
    }
    
    return anonymized;
  }
  
  static String _hashString(String input) {
    // Use crypto library for proper hashing
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
```

## Troubleshooting

### Common Issues

#### 1. Permission Denied Errors
```dart
// Check and request permissions properly
Future<bool> checkPermissions() async {
  final permissions = [
    Permission.location,
    Permission.nearbyWifiDevices,
  ];
  
  for (final permission in permissions) {
    final status = await permission.status;
    if (!status.isGranted) {
      final result = await permission.request();
      if (!result.isGranted) {
        return false;
      }
    }
  }
  return true;
}
```

#### 2. Network Discovery Issues
```dart
// Debug network discovery
Future<void> debugNetworkDiscovery() async {
  print('Scanning for networks...');
  final networks = await CrossP2PNetwork.scanNetworks();
  
  if (networks.isEmpty) {
    print('No networks found. Checking:');
    print('- Wi-Fi enabled: ${await isWifiEnabled()}');
    print('- Location enabled: ${await isLocationEnabled()}');
    print('- Permissions granted: ${await checkPermissions()}');
  } else {
    for (final network in networks) {
      print('Found: ${network.ssid} (${network.signalStrength} dBm)');
    }
  }
}
```

#### 3. Connection Timeouts
```dart
// Handle connection timeouts gracefully
Future<JoinResult> joinWithRetry(NetworkInfo network, int maxRetries) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      print('Connection attempt $attempt/$maxRetries');
      
      final result = await CrossP2PNetwork.scanAndJoin(
        studentId: 'STUDENT_ID',
        studentInfo: {},
        allowedSsids: [network.ssid],
      ).timeout(Duration(seconds: 30));
      
      if (result.success) return result;
      
    } catch (e) {
      print('Attempt $attempt failed: $e');
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
  
  return JoinResult(success: false, error: 'Max retries exceeded');
}
```

### Platform-Specific Issues

#### Android
- **Hotspot Creation**: Requires location permission and Wi-Fi enabled
- **Wi-Fi Aware**: Only available on Android 8+ with hardware support
- **Network Suggestions**: Android 10+ feature, fallback to legacy methods

#### iOS
- **Manual Setup**: Hotspot creation requires user interaction
- **Entitlements**: Requires proper entitlements in provisioning profile
- **Background**: Limited background networking capabilities

## Changelog

### Version 1.2.0
- ✅ Wi-Fi Aware support for iOS 19+ and Android 8+
- ✅ Improved auto-join with minimal prompting
- ✅ Enhanced error handling and recovery
- ✅ Battery optimization features
- ✅ Comprehensive example application

### Version 1.1.0
- ✅ BFS graph topology implementation
- ✅ Auto-healing network recovery
- ✅ MQTT embedded broker
- ✅ Service discovery enhancement

### Version 1.0.0
- ✅ Initial release
- ✅ Basic P2P networking
- ✅ Hotspot creation and joining
- ✅ Cross-platform support

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run example: `cd example && flutter run`
4. Run tests: `flutter test`

### Reporting Issues

Please report issues on our [GitHub Issues](https://github.com/your-org/cross_p2p_network/issues) page.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📧 Email: support@yourorg.com
- 💬 Discord: [Join our community](https://discord.gg/yourlink)
- 📖 Documentation: [Full API docs](https://docs.yourorg.com)
- 🐛 Bug Reports: [GitHub Issues](https://github.com/your-org/cross_p2p_network/issues)

---

**Made with ❤️ for the Flutter community**