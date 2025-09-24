import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'cross_p2p_network_method_channel.dart';

/// The interface that implementations of cross_p2p_network must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `CrossP2pNetworkPlatform` does not consider newly added methods to be breaking
/// changes. Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements` this
/// interface will be broken by newly added [CrossP2pNetworkPlatform] methods.
abstract class CrossP2pNetworkPlatform extends PlatformInterface {
  /// Constructs a CrossP2pNetworkPlatform.
  CrossP2pNetworkPlatform() : super(token: _token);

  static final Object _token = Object();

  static CrossP2pNetworkPlatform _instance = MethodChannelCrossP2pNetwork();

  /// The default instance of [CrossP2pNetworkPlatform] to use.
  ///
  /// Defaults to [MethodChannelCrossP2pNetwork].
  static CrossP2pNetworkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CrossP2pNetworkPlatform] when
  /// they register themselves.
  static set instance(CrossP2pNetworkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the platform version.
  ///
  /// Returns a String containing the platform version (e.g., "Android 11", "iOS 15.0")
  /// or null if the version cannot be determined.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  // MARK: - Core Initialization and Configuration

  /// Initialize the plugin with configuration parameters.
  ///
  /// [config] should contain:
  /// - serviceType: Service type for discovery (default: "_attendance._tcp")
  /// - preferAware: Whether to prefer Wi-Fi Aware (default: true)
  /// - enableDebugLogs: Enable debug logging (default: false)
  ///
  /// Returns a map with initialization result:
  /// - success: Boolean indicating success
  /// - wifiAwareSupported: Boolean indicating Wi-Fi Aware availability
  /// - error: Error message if initialization failed
  Future<Map<String, dynamic>> initialize(Map<String, dynamic> config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  // MARK: - Room Management (Teacher Mode)

  /// Create a new room for attendance system (Teacher mode).
  ///
  /// [params] should contain:
  /// - roomId: Unique room identifier
  /// - ssid: Network SSID to create
  /// - password: Network password
  /// - expectedSize: Expected number of students
  /// - classCode: Class identification code
  /// - subject: Optional subject name
  ///
  /// Returns a map with room creation result:
  /// - success: Boolean indicating success
  /// - roomId: Created room ID
  /// - ssid: Created network SSID
  /// - password: Network password
  /// - brokerIp: MQTT broker IP address
  /// - brokerPort: MQTT broker port
  /// - networkInterface: Network interface used
  /// - method: Connection method used ("aware", "hotspot", "manual")
  /// - error: Error message if creation failed
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> params) {
    throw UnimplementedError('createRoom() has not been implemented.');
  }

  // MARK: - Network Connection (Student Mode)

  /// Join an existing network (Student mode).
  ///
  /// [params] should contain:
  /// - ssid: Network SSID to join
  /// - password: Network password (optional for open networks)
  /// - studentId: Unique student identifier
  ///
  /// Returns a map with join result:
  /// - success: Boolean indicating success
  /// - method: Join method used ("networkSuggestion", "legacy", "hotspotConfig")
  /// - message: Status message
  /// - networkId: Network ID (Android legacy mode)
  /// - alreadyConnected: Boolean indicating if already connected
  /// - requiresUserApproval: Boolean indicating if user approval needed
  /// - error: Error message if join failed
  /// - errorCode: Platform-specific error code
  Future<Map<String, dynamic>> joinNetwork(Map<String, dynamic> params) {
    throw UnimplementedError('joinNetwork() has not been implemented.');
  }

  /// Disconnect from current network.
  ///
  /// [params] should contain:
  /// - heal: Whether to trigger network healing (default: true)
  ///
  /// Returns a map with disconnect result:
  /// - success: Boolean indicating success
  /// - error: Error message if disconnection failed
  Future<Map<String, dynamic>> disconnect(Map<String, dynamic> params) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  // MARK: - Network Scanning and Discovery

  /// Scan for available Wi-Fi networks.
  ///
  /// Returns a map with scan results:
  /// - networks: List of discovered networks
  /// - count: Number of networks found
  /// - note: Platform-specific notes (e.g., iOS limitations)
  /// Each network contains:
  /// - ssid: Network SSID
  /// - bssid: Network BSSID
  /// - signalStrength: Signal strength in dBm
  /// - frequency: Network frequency
  /// - capabilities: Security capabilities
  /// - isSecure: Boolean indicating if network is secured
  /// - isCurrentNetwork: Boolean indicating if currently connected
  /// - timestamp: Scan timestamp
  Future<Map<String, dynamic>> scanNetworks() {
    throw UnimplementedError('scanNetworks() has not been implemented.');
  }

  // MARK: - Service Discovery (DNS-SD/Bonjour)

  /// Start broadcasting service for discovery.
  ///
  /// [params] should contain:
  /// - serviceName: Service name to broadcast
  /// - serviceType: Service type (e.g., "_attendance._tcp")
  /// - port: Service port
  /// - txtRecords: Map of TXT record key-value pairs
  ///
  /// Returns a map with broadcast result:
  /// - success: Boolean indicating success
  /// - error: Error message if broadcast failed
  Future<Map<String, dynamic>> startServiceBroadcast(Map<String, dynamic> params) {
    throw UnimplementedError('startServiceBroadcast() has not been implemented.');
  }

  /// Stop service broadcasting.
  ///
  /// Returns a map with stop result:
  /// - success: Boolean indicating success
  /// - error: Error message if stop failed
  Future<Map<String, dynamic>> stopServiceBroadcast() {
    throw UnimplementedError('stopServiceBroadcast() has not been implemented.');
  }

  /// Start scanning for services.
  ///
  /// [params] should contain:
  /// - serviceType: Service type to scan for
  ///
  /// Returns a map with scan start result:
  /// - success: Boolean indicating success
  /// - error: Error message if scan start failed
  Future<Map<String, dynamic>> startServiceScan(Map<String, dynamic> params) {
    throw UnimplementedError('startServiceScan() has not been implemented.');
  }

  /// Stop service scanning.
  ///
  /// Returns a map with stop result:
  /// - success: Boolean indicating success
  /// - error: Error message if stop failed
  Future<Map<String, dynamic>> stopServiceScan() {
    throw UnimplementedError('stopServiceScan() has not been implemented.');
  }

  /// Perform a single service scan with timeout.
  ///
  /// [params] should contain:
  /// - serviceType: Service type to scan for
  /// - timeout: Scan timeout in milliseconds
  /// - singleScan: Boolean indicating single scan mode
  ///
  /// Returns a map with scan results:
  /// - services: List of discovered services
  /// - count: Number of services found
  /// Each service contains:
  /// - serviceId: Unique service identifier
  /// - serviceName: Service name
  /// - serviceType: Service type
  /// - hostName: Host IP address
  /// - port: Service port
  /// - txtRecords: Map of TXT records
  /// - signalStrength: Signal strength (if available)
  Future<Map<String, dynamic>> performSingleScan(Map<String, dynamic> params) {
    throw UnimplementedError('performSingleScan() has not been implemented.');
  }

  /// Refresh active service broadcast.
  ///
  /// Returns a map with refresh result:
  /// - success: Boolean indicating success
  /// - error: Error message if refresh failed
  Future<Map<String, dynamic>> refreshBroadcast() {
    throw UnimplementedError('refreshBroadcast() has not been implemented.');
  }

  /// Perform continuous service scanning.
  ///
  /// [params] should contain:
  /// - serviceType: Service type to scan for
  ///
  /// Returns a map with scan results:
  /// - services: List of newly discovered services
  /// - count: Number of services found in this scan
  Future<Map<String, dynamic>> continuousScan(Map<String, dynamic> params) {
    throw UnimplementedError('continuousScan() has not been implemented.');
  }

  // MARK: - Device Information and Status

  /// Get current device battery level.
  ///
  /// Returns a map with battery information:
  /// - batteryLevel: Battery level percentage (0-100, -1 if unavailable)
  Future<Map<String, dynamic>> getBatteryLevel() {
    throw UnimplementedError('getBatteryLevel() has not been implemented.');
  }

  /// Get current Wi-Fi signal strength.
  ///
  /// Returns a map with signal information:
  /// - signalStrength: Signal strength in dBm (-1 if unavailable)
  Future<Map<String, dynamic>> getSignalStrength() {
    throw UnimplementedError('getSignalStrength() has not been implemented.');
  }

  /// Get device information for network node identification.
  ///
  /// Returns a map with device information:
  /// - platform: Platform name ("android" or "ios")
  /// - version: Platform version
  /// - deviceId: Unique device identifier
  /// - model: Device model
  /// - manufacturer: Device manufacturer
  Future<Map<String, dynamic>> getDeviceInfo() {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  /// Get current network information.
  ///
  /// Returns a map with network information:
  /// - ssid: Current network SSID
  /// - bssid: Current network BSSID
  /// - ipAddress: Device IP address
  /// - isConnected: Boolean indicating connection status
  /// - signalStrength: Current signal strength
  /// - frequency: Network frequency
  Future<Map<String, dynamic>> getNetworkInfo() {
    throw UnimplementedError('getNetworkInfo() has not been implemented.');
  }

  /// Check if Wi-Fi is currently enabled.
  ///
  /// Returns a map with Wi-Fi status:
  /// - enabled: Boolean indicating if Wi-Fi is enabled
  Future<Map<String, dynamic>> isWifiEnabled() {
    throw UnimplementedError('isWifiEnabled() has not been implemented.');
  }

  /// Enable Wi-Fi on the device.
  ///
  /// Returns a map with enable result:
  /// - success: Boolean indicating success
  /// - error: Error message if enable failed
  Future<Map<String, dynamic>> enableWifi() {
    throw UnimplementedError('enableWifi() has not been implemented.');
  }

  /// Disable Wi-Fi on the device.
  ///
  /// Returns a map with disable result:
  /// - success: Boolean indicating success
  /// - error: Error message if disable failed
  Future<Map<String, dynamic>> disableWifi() {
    throw UnimplementedError('disableWifi() has not been implemented.');
  }

  /// Get information about currently connected network.
  ///
  /// Returns a map with connected network information:
  /// - ssid: Connected network SSID
  /// - bssid: Connected network BSSID
  /// - signalStrength: Current signal strength
  /// - ipAddress: Assigned IP address
  /// - gateway: Gateway IP address
  /// - dns: DNS server addresses
  /// - isConnected: Boolean indicating connection status
  Future<Map<String, dynamic>> getConnectedNetwork() {
    throw UnimplementedError('getConnectedNetwork() has not been implemented.');
  }

  /// Forget a previously configured network.
  ///
  /// [ssid] The SSID of the network to forget
  ///
  /// Returns a map with forget result:
  /// - success: Boolean indicating success
  /// - error: Error message if forget failed
  Future<Map<String, dynamic>> forgetNetwork(String ssid) {
    throw UnimplementedError('forgetNetwork() has not been implemented.');
  }

  /// Get network statistics and performance metrics.
  ///
  /// Returns a map with network statistics:
  /// - bytesReceived: Total bytes received
  /// - bytesSent: Total bytes sent
  /// - packetsReceived: Total packets received
  /// - packetsSent: Total packets sent
  /// - connectionTime: Time connected in milliseconds
  /// - averageLatency: Average latency in milliseconds
  Future<Map<String, dynamic>> getNetworkStats() {
    throw UnimplementedError('getNetworkStats() has not been implemented.');
  }

  // MARK: - Data Communication

  /// Send data through the network.
  ///
  /// [data] should contain:
  /// - topic: Message topic
  /// - payload: Message payload
  /// - qos: Quality of service level
  /// - retain: Whether to retain the message
  ///
  /// Returns a map with send result:
  /// - success: Boolean indicating success
  /// - messageId: Message identifier
  /// - error: Error message if send failed
  Future<Map<String, dynamic>> sendData(Map<String, dynamic> data) {
    throw UnimplementedError('sendData() has not been implemented.');
  }

  /// Set heartbeat interval for network health monitoring.
  ///
  /// [intervalSeconds] Heartbeat interval in seconds
  ///
  /// Returns a map with set result:
  /// - success: Boolean indicating success
  /// - interval: Set interval in seconds
  /// - error: Error message if set failed
  Future<Map<String, dynamic>> setHeartbeatInterval(int intervalSeconds) {
    throw UnimplementedError('setHeartbeatInterval() has not been implemented.');
  }

  // MARK: - Permission Management

  /// Check current permission status.
  ///
  /// Returns a map with permission status:
  /// - location: Location permission status
  /// - wifi: Wi-Fi permission status
  /// - nearbyDevices: Nearby devices permission status
  /// - storage: Storage permission status
  /// - allGranted: Boolean indicating if all required permissions are granted
  Future<Map<String, dynamic>> checkPermissions() {
    throw UnimplementedError('checkPermissions() has not been implemented.');
  }

  /// Request required permissions from user.
  ///
  /// Returns a map with permission request result:
  /// - granted: List of granted permissions
  /// - denied: List of denied permissions
  /// - permanentlyDenied: List of permanently denied permissions
  /// - allGranted: Boolean indicating if all required permissions are granted
  Future<Map<String, dynamic>> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  // MARK: - Network Quality and Optimization

  /// Get current connection quality metrics.
  ///
  /// Returns a map with connection quality:
  /// - signalStrength: Current signal strength in dBm
  /// - linkSpeed: Link speed in Mbps
  /// - frequency: Network frequency in MHz
  /// - latency: Network latency in milliseconds
  /// - packetLoss: Packet loss percentage
  /// - quality: Overall quality score (0-100)
  Future<Map<String, dynamic>> getConnectionQuality() {
    throw UnimplementedError('getConnectionQuality() has not been implemented.');
  }

  /// Optimize battery usage for network operations.
  ///
  /// [optimize] Whether to enable battery optimization
  ///
  /// Returns a map with optimization result:
  /// - success: Boolean indicating success
  /// - optimized: Boolean indicating current optimization state
  /// - error: Error message if optimization failed
  Future<Map<String, dynamic>> optimizeBatteryUsage(bool optimize) {
    throw UnimplementedError('optimizeBatteryUsage() has not been implemented.');
  }

  /// Set network type priority for connections.
  ///
  /// [networkType] Network type to prioritize ("wifi", "cellular", "aware")
  ///
  /// Returns a map with priority set result:
  /// - success: Boolean indicating success
  /// - priority: Set network type priority
  /// - error: Error message if set failed
  Future<Map<String, dynamic>> setNetworkPriority(String networkType) {
    throw UnimplementedError('setNetworkPriority() has not been implemented.');
  }

  /// Get list of available networks with detailed information.
  ///
  /// Returns a map with available networks:
  /// - networks: List of available networks with details
  /// - count: Number of available networks
  /// Each network contains detailed information including security, capabilities, etc.
  Future<Map<String, dynamic>> getAvailableNetworks() {
    throw UnimplementedError('getAvailableNetworks() has not been implemented.');
  }

  // MARK: - Node Communication and Management

  /// Ping a specific node in the network.
  ///
  /// [nodeId] The ID of the node to ping
  /// [timeout] Ping timeout in milliseconds (default: 5000)
  ///
  /// Returns a map with ping result:
  /// - success: Boolean indicating if ping was successful
  /// - latency: Ping latency in milliseconds
  /// - nodeId: Target node ID
  /// - timestamp: Ping timestamp
  /// - error: Error message if ping failed
  Future<Map<String, dynamic>> pingNode(String nodeId, {int timeout = 5000}) {
    throw UnimplementedError('pingNode() has not been implemented.');
  }

  /// Get information about a specific node.
  ///
  /// [nodeId] The ID of the node to query
  ///
  /// Returns a map with node information:
  /// - nodeId: Node identifier
  /// - isOnline: Boolean indicating if node is online
  /// - lastSeen: Last seen timestamp
  /// - batteryLevel: Node battery level
  /// - signalStrength: Signal strength to node
  /// - deviceInfo: Device information
  /// - error: Error message if query failed
  Future<Map<String, dynamic>> getNodeInfo(String nodeId) {
    throw UnimplementedError('getNodeInfo() has not been implemented.');
  }

  // MARK: - Debug and Logging

  /// Enable or disable debug mode.
  ///
  /// [enabled] Whether to enable debug mode
  ///
  /// Returns a map with debug mode result:
  /// - success: Boolean indicating success
  /// - enabled: Boolean indicating current debug state
  /// - error: Error message if set failed
  Future<Map<String, dynamic>> setDebugMode(bool enabled) {
    throw UnimplementedError('setDebugMode() has not been implemented.');
  }

  /// Get debug logs from the platform.
  ///
  /// Returns a map with log information:
  /// - logs: List of log entries
  /// - count: Number of log entries
  /// - lastUpdated: Last log update timestamp
  /// Each log entry contains:
  /// - timestamp: Log timestamp
  /// - level: Log level (debug, info, warning, error)
  /// - message: Log message
  /// - tag: Log tag/category
  Future<Map<String, dynamic>> getLogs() {
    throw UnimplementedError('getLogs() has not been implemented.');
  }

  /// Clear cached data and temporary files.
  ///
  /// Returns a map with clear result:
  /// - success: Boolean indicating success
  /// - clearedItems: Number of items cleared
  /// - freedSpace: Amount of space freed in bytes
  /// - error: Error message if clear failed
  Future<Map<String, dynamic>> clearCache() {
    throw UnimplementedError('clearCache() has not been implemented.');
  }

  // MARK: - Stream Handlers

  /// Get stream of events from the platform.
  ///
  /// This stream provides real-time events such as:
  /// - Network state changes
  /// - Node connections/disconnections
  /// - Service discovery events
  /// - Error notifications
  /// - Status updates
  Stream<Map<String, dynamic>> get eventStream {
    throw UnimplementedError('eventStream has not been implemented.');
  }

  /// Get stream of data messages from the platform.
  ///
  /// This stream provides real-time data such as:
  /// - MQTT messages
  /// - Node data updates
  /// - Quiz responses
  /// - Heartbeat data
  /// - Custom application data
  Stream<Map<String, dynamic>> get dataStream {
    throw UnimplementedError('dataStream has not been implemented.');
  }
}