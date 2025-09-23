import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'cross_p2p_network_method_channel.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
