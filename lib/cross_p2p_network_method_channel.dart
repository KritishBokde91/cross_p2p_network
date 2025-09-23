import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cross_p2p_network_platform_interface.dart';

/// An implementation of [CrossP2pNetworkPlatform] that uses method channels.
class MethodChannelCrossP2pNetwork extends CrossP2pNetworkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('cross_p2p_network');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
