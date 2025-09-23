
import 'cross_p2p_network_platform_interface.dart';

class CrossP2pNetwork {
  Future<String?> getPlatformVersion() {
    return CrossP2pNetworkPlatform.instance.getPlatformVersion();
  }
}
