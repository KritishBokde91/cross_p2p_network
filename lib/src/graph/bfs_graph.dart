import 'dart:async';
import 'dart:collection';
import 'dart:math';
import '../models/network_models.dart';

class BfsGraph {
  final Map<String, NetworkNode> _nodes = {};
  final Map<String, Set<String>> _adjacencyList = {};
  NetworkNode? _rootNode;

  final StreamController<GraphEvent> _eventController =
  StreamController<GraphEvent>.broadcast();

  Timer? _healthCheckTimer;
  Timer? _rebalanceTimer;

  static const int maxChildrenPerNode = 8;
  static const int maxDepth = 4;
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const Duration rebalanceInterval = Duration(minutes: 2);

  void initialize(NetworkNode rootNode) {
    _rootNode = rootNode;
    _nodes[rootNode.nodeId] = rootNode;
    _adjacencyList[rootNode.nodeId] = <String>{};

    _startHealthCheck();
    _startRebalancing();

    _eventController.add(GraphEvent.graphInitialized(rootNode.nodeId));
  }

  Future<bool> addNode(NetworkNode node) async {
    if (_nodes.containsKey(node.nodeId)) {
      return false; // Node already exists
    }

    try {
      final parent = await _findBestParent(node);
      if (parent == null) {
        _eventController.add(GraphEvent.nodeRejected(
            node.nodeId,
            'No suitable parent found'
        ));
        return false;
      }

      _nodes[node.nodeId] = node;
      _adjacencyList[node.nodeId] = <String>{};

      node.parentId = parent.nodeId;
      parent.children.add(node.nodeId);
      _adjacencyList[parent.nodeId]!.add(node.nodeId);

      _eventController.add(GraphEvent.nodeAdded(node.nodeId, parent.nodeId));
      return true;

    } catch (e) {
      _eventController.add(GraphEvent.error('Failed to add node ${node.nodeId}: $e'));
      return false;
    }
  }

  Future<void> removeNode(String nodeId) async {
    final node = _nodes[nodeId];
    if (node == null) return;

    try {
      final children = List<String>.from(node.children);
      for (final childId in children) {
        await _reconnectOrphanedNode(childId);
      }

      if (node.parentId != null) {
        final parent = _nodes[node.parentId!];
        parent?.children.remove(nodeId);
        _adjacencyList[node.parentId!]?.remove(nodeId);
      }

      _nodes.remove(nodeId);
      _adjacencyList.remove(nodeId);

      _eventController.add(GraphEvent.nodeRemoved(nodeId));

    } catch (e) {
      _eventController.add(GraphEvent.error('Failed to remove node $nodeId: $e'));
    }
  }

  Future<void> handleNodeDisconnect(String nodeId) async {
    final node = _nodes[nodeId];
    if (node == null) return;

    if (node.isRoot) {
      await _handleRootDisconnect();
    } else {
      await removeNode(nodeId);
    }
  }

  NetworkNode? getNode(String nodeId) => _nodes[nodeId];

  List<NetworkNode> getAllNodes() => _nodes.values.toList();

  NetworkNode? get rootNode => _rootNode;

  List<NetworkNode> getChildren(String nodeId) {
    final childIds = _adjacencyList[nodeId] ?? <String>{};
    return childIds.map((id) => _nodes[id]).whereType<NetworkNode>().toList();
  }

  List<String> getPathToRoot(String nodeId) {
    final path = <String>[];
    String? currentId = nodeId;

    while (currentId != null && !path.contains(currentId)) {
      path.add(currentId);
      currentId = _nodes[currentId]?.parentId;
    }

    return path.reversed.toList();
  }

  int getNetworkDepth() {
    if (_rootNode == null) return 0;
    return _calculateDepth(_rootNode!.nodeId, 0);
  }

  Map<String, dynamic> getNetworkStats() {
    final stats = {
      'totalNodes': _nodes.length,
      'depth': getNetworkDepth(),
      'averageChildren': _calculateAverageChildren(),
      'healthyNodes': _nodes.values.where((n) => n.isHealthy).length,
      'leafNodes': _nodes.values.where((n) => n.children.isEmpty).length,
      'loadBalance': _calculateLoadBalance(),
    };

    return stats;
  }

  Stream<GraphEvent> get eventStream => _eventController.stream;

  Future<void> dispose() async {
    _healthCheckTimer?.cancel();
    _rebalanceTimer?.cancel();
    await _eventController.close();

    _nodes.clear();
    _adjacencyList.clear();
    _rootNode = null;
  }

  Future<NetworkNode?> _findBestParent(NetworkNode newNode) async {
    if (_rootNode == null) return null;

    final queue = Queue<NetworkNode>();
    final visited = <String>{};
    final candidates = <NetworkNode>[];

    queue.add(_rootNode!);
    visited.add(_rootNode!.nodeId);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current.children.length < maxChildrenPerNode && current.isHealthy) {
        candidates.add(current);
      }

      for (final childId in current.children) {
        final child = _nodes[childId];
        if (child != null && !visited.contains(childId)) {
          queue.add(child);
          visited.add(childId);
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.score.compareTo(a.score));

    return _filterCompatibleParent(candidates, newNode);
  }

  NetworkNode? _filterCompatibleParent(List<NetworkNode> candidates, NetworkNode newNode) {
    for (final candidate in candidates) {
      if (newNode.deviceInfo['platform'] == 'android') {
        final sdkVersion = newNode.deviceInfo['version'] as int? ?? 0;
        if (sdkVersion < 26 && candidate.children.isNotEmpty) {
          continue;
        }
      }

      final depth = _calculateDepth(candidate.nodeId, 0);
      if (depth >= maxDepth - 1) continue;

      return candidate;
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  int _calculateDepth(String nodeId, int currentDepth) {
    final node = _nodes[nodeId];
    if (node == null || node.children.isEmpty) return currentDepth;

    int maxChildDepth = currentDepth;
    for (final childId in node.children) {
      final childDepth = _calculateDepth(childId, currentDepth + 1);
      maxChildDepth = max(maxChildDepth, childDepth);
    }

    return maxChildDepth;
  }

  double _calculateAverageChildren() {
    if (_nodes.isEmpty) return 0.0;
    final totalChildren = _nodes.values.map((n) => n.children.length).reduce((a, b) => a + b);
    return totalChildren / _nodes.length;
  }

  double _calculateLoadBalance() {
    if (_nodes.isEmpty) return 1.0;

    final childCounts = _nodes.values.map((n) => n.children.length).toList();
    if (childCounts.isEmpty) return 1.0;

    final maxChildren = childCounts.reduce(max);
    final minChildren = childCounts.reduce(min);

    if (maxChildren == 0) return 1.0;
    return 1.0 - ((maxChildren - minChildren) / maxChildren);
  }

  Future<void> _reconnectOrphanedNode(String orphanId) async {
    final orphan = _nodes[orphanId];
    if (orphan == null) return;

    orphan.parentId = null;

    final newParent = await _findBestParent(orphan);
    if (newParent != null) {
      orphan.parentId = newParent.nodeId;
      newParent.children.add(orphanId);
      _adjacencyList[newParent.nodeId]!.add(orphanId);

      _eventController.add(GraphEvent.nodeReconnected(orphanId, newParent.nodeId));
    } else {
      await removeNode(orphanId);
    }
  }

  Future<void> _handleRootDisconnect() async {
    _eventController.add(GraphEvent.rootDisconnected());

    final eligibleNodes = _nodes.values
        .where((n) => !n.isRoot && n.isHealthy)
        .toList();

    if (eligibleNodes.isEmpty) {
      _eventController.add(GraphEvent.networkPartitioned());
      return;
    }

    eligibleNodes.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.nodeId.compareTo(a.nodeId);
    });

    final newRoot = eligibleNodes.first;
    await _electNewRoot(newRoot);
  }

  Future<void> _electNewRoot(NetworkNode newRoot) async {
    _rootNode?.copyWith(isRoot: false);
    _rootNode = newRoot.copyWith(isRoot: true);
    _nodes[newRoot.nodeId] = _rootNode!;

    await _rebuildGraphFromRoot();

    _eventController.add(GraphEvent.newRootElected(newRoot.nodeId));
  }

  Future<void> _rebuildGraphFromRoot() async {
    if (_rootNode == null) return;

    for (final node in _nodes.values) {
      node.children.clear();
      node.parentId = null;
    }
    _adjacencyList.clear();

    _adjacencyList[_rootNode!.nodeId] = <String>{};
    final queue = Queue<NetworkNode>();
    final remaining = _nodes.values.where((n) => !n.isRoot).toList();

    queue.add(_rootNode!);

    while (queue.isNotEmpty && remaining.isNotEmpty) {
      final current = queue.removeFirst();

      final availableSlots = maxChildrenPerNode - current.children.length;
      final candidatesForThis = remaining
          .where((n) => _isCompatibleChild(n, current))
          .take(availableSlots)
          .toList();

      for (final child in candidatesForThis) {
        child.parentId = current.nodeId;
        current.children.add(child.nodeId);
        _adjacencyList[current.nodeId]!.add(child.nodeId);
        _adjacencyList[child.nodeId] = <String>{};

        queue.add(child);
        remaining.remove(child);
      }
    }

    for (final unconnected in remaining) {
      await removeNode(unconnected.nodeId);
    }
  }

  bool _isCompatibleChild(NetworkNode child, NetworkNode parent) {
    if (child.deviceInfo['platform'] == 'android') {
      final sdkVersion = child.deviceInfo['version'] as int? ?? 0;
      if (sdkVersion < 26) return true;
    }

    if (child.batteryLevel < 20) return true;

    return true;
  }

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (timer) async {
      await _performHealthCheck();
    });
  }

  void _startRebalancing() {
    _rebalanceTimer = Timer.periodic(rebalanceInterval, (timer) async {
      await _performRebalancing();
    });
  }

  Future<void> _performHealthCheck() async {
    final unhealthyNodes = _nodes.values.where((n) => !n.isHealthy).toList();

    for (final node in unhealthyNodes) {
      if (node.isRoot) {
        if (_shouldElectNewRoot(node)) {
          await _handleRootDisconnect();
        }
      } else {
        await removeNode(node.nodeId);
      }
    }

    _eventController.add(GraphEvent.healthCheckCompleted(
        unhealthyNodes.map((n) => n.nodeId).toList()
    ));
  }

  bool _shouldElectNewRoot(NetworkNode root) {
    final timeSinceHeartbeat = DateTime.now().difference(root.lastHeartbeat);
    return timeSinceHeartbeat.inMinutes > 3 || root.batteryLevel < 15;
  }

  Future<void> _performRebalancing() async {
    final stats = getNetworkStats();
    final loadBalance = stats['loadBalance'] as double;

    if (loadBalance < 0.7) {
      _eventController.add(GraphEvent.rebalanceStarted());

      final overloadedNodes = _nodes.values
          .where((n) => n.children.length > maxChildrenPerNode * 0.8)
          .toList();

      for (final overloaded in overloadedNodes) {
        await _rebalanceNode(overloaded);
      }

      _eventController.add(GraphEvent.rebalanceCompleted());
    }
  }

  Future<void> _rebalanceNode(NetworkNode overloadedNode) async {
    // Move some children to less loaded nodes
    final excessChildren = overloadedNode.children.length - (maxChildrenPerNode ~/ 2);
    if (excessChildren <= 0) return;

    final childrenToMove = overloadedNode.children.take(excessChildren).toList();

    for (final childId in childrenToMove) {
      final child = _nodes[childId];
      if (child == null) continue;

      final newParent = await _findBestParent(child);
      if (newParent != null && newParent.nodeId != overloadedNode.nodeId) {
        overloadedNode.children.remove(childId);
        _adjacencyList[overloadedNode.nodeId]!.remove(childId);

        child.parentId = newParent.nodeId;
        newParent.children.add(childId);
        _adjacencyList[newParent.nodeId]!.add(childId);

        _eventController.add(GraphEvent.nodeReconnected(childId, newParent.nodeId));
      }
    }
  }

  void updateNodeHeartbeat(String nodeId, HeartbeatData heartbeat) {
    final node = _nodes[nodeId];
    if (node == null) return;

    node.lastHeartbeat = heartbeat.timestamp;
    node.batteryLevel = heartbeat.batteryLevel;
    node.signalStrength = heartbeat.signalStrength;
  }

  Map<String, dynamic> getHierarchyTree() {
    if (_rootNode == null) return {};
    return _buildNodeTree(_rootNode!);
  }

  Map<String, dynamic> _buildNodeTree(NetworkNode node) {
    final tree = {
      'nodeId': node.nodeId,
      'isRoot': node.isRoot,
      'batteryLevel': node.batteryLevel,
      'signalStrength': node.signalStrength,
      'isHealthy': node.isHealthy,
      'children': <Map<String, dynamic>>[],
    };

    for (final childId in node.children) {
      final child = _nodes[childId];
      if (child != null) {
        (tree['children'] as List<Map<String, dynamic>>).add(_buildNodeTree(child));
      }
    }

    return tree;
  }
}

enum GraphEventType {
  graphInitialized,
  nodeAdded,
  nodeRemoved,
  nodeReconnected,
  nodeRejected,
  rootDisconnected,
  newRootElected,
  networkPartitioned,
  healthCheckCompleted,
  rebalanceStarted,
  rebalanceCompleted,
  error,
}

class GraphEvent {
  final GraphEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  GraphEvent({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GraphEvent.graphInitialized(String rootId) {
    return GraphEvent(
      type: GraphEventType.graphInitialized,
      message: 'Graph initialized with root: $rootId',
      data: {'rootId': rootId},
    );
  }

  factory GraphEvent.nodeAdded(String nodeId, String parentId) {
    return GraphEvent(
      type: GraphEventType.nodeAdded,
      message: 'Node $nodeId added under parent $parentId',
      data: {'nodeId': nodeId, 'parentId': parentId},
    );
  }

  factory GraphEvent.nodeRemoved(String nodeId) {
    return GraphEvent(
      type: GraphEventType.nodeRemoved,
      message: 'Node $nodeId removed from graph',
      data: {'nodeId': nodeId},
    );
  }

  factory GraphEvent.nodeReconnected(String nodeId, String newParentId) {
    return GraphEvent(
      type: GraphEventType.nodeReconnected,
      message: 'Node $nodeId reconnected under $newParentId',
      data: {'nodeId': nodeId, 'newParentId': newParentId},
    );
  }

  factory GraphEvent.nodeRejected(String nodeId, String reason) {
    return GraphEvent(
      type: GraphEventType.nodeRejected,
      message: 'Node $nodeId rejected: $reason',
      data: {'nodeId': nodeId, 'reason': reason},
    );
  }

  factory GraphEvent.rootDisconnected() {
    return GraphEvent(
      type: GraphEventType.rootDisconnected,
      message: 'Root node disconnected',
    );
  }

  factory GraphEvent.newRootElected(String newRootId) {
    return GraphEvent(
      type: GraphEventType.newRootElected,
      message: 'New root elected: $newRootId',
      data: {'newRootId': newRootId},
    );
  }

  factory GraphEvent.networkPartitioned() {
    return GraphEvent(
      type: GraphEventType.networkPartitioned,
      message: 'Network partitioned - no suitable root found',
    );
  }

  factory GraphEvent.healthCheckCompleted(List<String> removedNodes) {
    return GraphEvent(
      type: GraphEventType.healthCheckCompleted,
      message: 'Health check completed, removed ${removedNodes.length} unhealthy nodes',
      data: {'removedNodes': removedNodes},
    );
  }

  factory GraphEvent.rebalanceStarted() {
    return GraphEvent(
      type: GraphEventType.rebalanceStarted,
      message: 'Network rebalancing started',
    );
  }

  factory GraphEvent.rebalanceCompleted() {
    return GraphEvent(
      type: GraphEventType.rebalanceCompleted,
      message: 'Network rebalancing completed',
    );
  }

  factory GraphEvent.error(String error) {
    return GraphEvent(
      type: GraphEventType.error,
      message: 'Graph error: $error',
      data: {'error': error},
    );
  }
}