import 'package:flutter_test/flutter_test.dart';
import 'package:cross_p2p_network/cross_p2p_network.dart';
import 'package:cross_p2p_network/cross_p2p_network_platform_interface.dart';
import 'package:cross_p2p_network/cross_p2p_network_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCrossP2pNetworkPlatform
    with MockPlatformInterfaceMixin
    implements CrossP2pNetworkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CrossP2pNetworkPlatform initialPlatform = CrossP2pNetworkPlatform.instance;

  test('$MethodChannelCrossP2pNetwork is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCrossP2pNetwork>());
  });

  test('getPlatformVersion', () async {
    CrossP2pNetwork crossP2pNetworkPlugin = CrossP2pNetwork();
    MockCrossP2pNetworkPlatform fakePlatform = MockCrossP2pNetworkPlatform();
    CrossP2pNetworkPlatform.instance = fakePlatform;

    expect(await crossP2pNetworkPlugin.getPlatformVersion(), '42');
  });
}
