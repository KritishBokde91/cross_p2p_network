import 'package:flutter_test/flutter_test.dart';
import 'package:cross_p2p_network/cross_p2p_network_platform_interface.dart';
import 'package:cross_p2p_network/cross_p2p_network_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCrossP2PNetworkPlatform
    with MockPlatformInterfaceMixin
    implements CrossP2pNetworkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>> checkPermissions() {
    // TODO: implement checkPermissions
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> clearCache() {
    // TODO: implement clearCache
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> continuousScan(Map<String, dynamic> params) {
    // TODO: implement continuousScan
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> params) {
    // TODO: implement createRoom
    throw UnimplementedError();
  }

  @override
  // TODO: implement dataStream
  Stream<Map<String, dynamic>> get dataStream => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> disableWifi() {
    // TODO: implement disableWifi
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> disconnect(Map<String, dynamic> params) {
    // TODO: implement disconnect
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> enableWifi() {
    // TODO: implement enableWifi
    throw UnimplementedError();
  }

  @override
  // TODO: implement eventStream
  Stream<Map<String, dynamic>> get eventStream => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> forgetNetwork(String ssid) {
    // TODO: implement forgetNetwork
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getAvailableNetworks() {
    // TODO: implement getAvailableNetworks
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getBatteryLevel() {
    // TODO: implement getBatteryLevel
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getConnectedNetwork() {
    // TODO: implement getConnectedNetwork
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getConnectionQuality() {
    // TODO: implement getConnectionQuality
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() {
    // TODO: implement getDeviceInfo
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getLogs() {
    // TODO: implement getLogs
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getNetworkInfo() {
    // TODO: implement getNetworkInfo
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getNetworkStats() {
    // TODO: implement getNetworkStats
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getNodeInfo(String nodeId) {
    // TODO: implement getNodeInfo
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getSignalStrength() {
    // TODO: implement getSignalStrength
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> initialize(Map<String, dynamic> config) {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> isWifiEnabled() {
    // TODO: implement isWifiEnabled
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> joinNetwork(Map<String, dynamic> params) {
    // TODO: implement joinNetwork
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> optimizeBatteryUsage(bool optimize) {
    // TODO: implement optimizeBatteryUsage
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> performSingleScan(Map<String, dynamic> params) {
    // TODO: implement performSingleScan
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> pingNode(String nodeId, {int timeout = 5000}) {
    // TODO: implement pingNode
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> refreshBroadcast() {
    // TODO: implement refreshBroadcast
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> requestPermissions() {
    // TODO: implement requestPermissions
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> scanNetworks() {
    // TODO: implement scanNetworks
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> sendData(Map<String, dynamic> data) {
    // TODO: implement sendData
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> setDebugMode(bool enabled) {
    // TODO: implement setDebugMode
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> setHeartbeatInterval(int intervalSeconds) {
    // TODO: implement setHeartbeatInterval
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> setNetworkPriority(String networkType) {
    // TODO: implement setNetworkPriority
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> startServiceBroadcast(
    Map<String, dynamic> params,
  ) {
    // TODO: implement startServiceBroadcast
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> startServiceScan(Map<String, dynamic> params) {
    // TODO: implement startServiceScan
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> stopServiceBroadcast() {
    // TODO: implement stopServiceBroadcast
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> stopServiceScan() {
    // TODO: implement stopServiceScan
    throw UnimplementedError();
  }
}

void main() {
  final CrossP2pNetworkPlatform initialPlatform =
      CrossP2pNetworkPlatform.instance;

  test('$MethodChannelCrossP2pNetwork is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCrossP2pNetwork>());
  });
}
