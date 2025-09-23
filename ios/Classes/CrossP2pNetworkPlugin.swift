import Flutter
import UIKit
import NetworkExtension
import Network
import SystemConfiguration.CaptiveNetwork
import CoreLocation

@available(iOS 12.0, *)
extension CrossP2PNetworkPlugin: NetServiceDelegate {

    public func netServiceDidPublish(_ sender: NetService) {
        sendEvent([
            "type": "serviceRegistered",
            "message": "Service registered: \(sender.name)",
            "data": [
                "serviceName": sender.name,
                "serviceType": sender.type
            ]
        ])
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        let errorCode = errorDict[NetService.ErrorCode.rawValue]?.intValue ?? -1
        sendEvent([
            "type": "error",
            "message": "Service registration failed: \(errorCode)"
        ])
    }

    public func netServiceDidStop(_ sender: NetService) {
        sendEvent([
            "type": "serviceUnregistered",
            "message": "Service unregistered"
        ])
    }
}

// MARK: - NetServiceBrowser Delegate

@available(iOS 12.0, *)
extension CrossP2PNetworkPlugin: NetServiceBrowserDelegate {

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        sendEvent([
            "type": "serviceFound",
            "message": "Service found: \(service.name)",
            "data": [
                "serviceName": service.name,
                "serviceType": service.type
            ]
        ])

        // Resolve service for detailed information
        service.delegate = self
        service.resolve(withTimeout: 10.0)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let serviceKey = "\(service.name)_\(service.type)"
        discoveredServices.removeValue(forKey: serviceKey)

        sendEvent([
            "type": "serviceLost",
            "message": "Service lost: \(service.name)"
        ])
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        sendEvent([
            "type": "discoveryStopped",
            "message": "Discovery stopped"
        ])
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        let errorCode = errorDict[NetService.ErrorCode.rawValue]?.intValue ?? -1
        sendEvent([
            "type": "error",
            "message": "Discovery failed: \(errorCode)"
        ])
    }
}

// MARK: - NetService Resolution Delegate

@available(iOS 12.0, *)
extension CrossP2PNetworkPlugin {

    public func netServiceDidResolveAddress(_ sender: NetService) {
        let serviceKey = "\(sender.name)_\(sender.type)"

        // Extract TXT records
        var txtRecords: [String: String] = [:]
        if let txtData = sender.txtRecordData() {
            let txtDict = NetService.dictionary(fromTXTRecord: txtData)
            for (key, value) in txtDict {
                if let stringValue = String(data: value, encoding: .utf8) {
                    txtRecords[key] = stringValue
                }
            }
        }

        // Get IP address from addresses
        var hostAddress = ""
        if let addresses = sender.addresses {
            for addressData in addresses {
                let address = addressData.withUnsafeBytes { bytes in
                    bytes.bindMemory(to: sockaddr.self).baseAddress!.pointee
                }

                if address.sa_family == sa_family_t(AF_INET) {
                    let addr = addressData.withUnsafeBytes { bytes in
                        bytes.bindMemory(to: sockaddr_in.self).baseAddress!.pointee
                    }
                    hostAddress = String(cString: inet_ntoa(addr.sin_addr))
                    break
                }
            }
        }

        let serviceInfo: [String: Any] = [
            "serviceId": serviceKey,
            "serviceName": sender.name,
            "serviceType": sender.type,
            "hostName": hostAddress,
            "port": sender.port,
            "txtRecords": txtRecords
        ]

        discoveredServices[serviceKey] = serviceInfo

        sendEvent([
            "type": "serviceResolved",
            "message": "Service resolved: \(sender.name)",
            "data": serviceInfo
        ])
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // Resolution failed - ignore or retry
    }
}

// MARK: - Flutter Event Stream Handler

@available(iOS 12.0, *)
extension CrossP2PNetworkPlugin: FlutterStreamHandler {

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if let args = arguments as? [String: Any],
           let channel = args["channel"] as? String {

            if channel == "events" {
                eventSink = events
            } else if channel == "data" {
                dataSink = events
            }
        } else {
            // Default to event sink for backward compatibility
            eventSink = events
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let args = arguments as? [String: Any],
           let channel = args["channel"] as? String {

            if channel == "events" {
                eventSink = nil
            } else if channel == "data" {
                dataSink = nil
            }
        } else {
            // Default to clearing event sink
            eventSink = nil
        }

        return nil
    }
} *)
public class CrossP2PNetworkPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties
    private var eventChannel: FlutterEventChannel?
    private var dataChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var dataSink: FlutterEventSink?

    // Network components
    private var wifiAwareManager: Any? // WiFiAware manager (iOS 19+)
    private var netServiceBrowser: NetServiceBrowser?
    private var netService: NetService?
    private var currentHotspotConfig: NEHotspotConfiguration?

    // Network discovery
    private var discoveredServices: [String: [String: Any]] = [:]
    private var isScanning = false
    private var isBroadcasting = false

    // Configuration
    private var preferWifiAware = true
    private var serviceType = "_attendance._tcp"
    private var currentRoomId: String?

    // Timers
    private var scanTimer: Timer?
    private var broadcastTimer: Timer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cross_p2p_network", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "cross_p2p_network/events", binaryMessenger: registrar.messenger())
        let dataChannel = FlutterEventChannel(name: "cross_p2p_network/data", binaryMessenger: registrar.messenger())

        let instance = CrossP2PNetworkPlugin()
        instance.eventChannel = eventChannel
        instance.dataChannel = dataChannel

        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        dataChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call: call, result: result)
        case "createRoom":
            createRoom(call: call, result: result)
        case "joinNetwork":
            joinNetwork(call: call, result: result)
        case "scanNetworks":
            scanNetworks(call: call, result: result)
        case "singleScan":
            performSingleScan(call: call, result: result)
        case "startBroadcast":
            startServiceBroadcast(call: call, result: result)
        case "stopBroadcast":
            stopServiceBroadcast(call: call, result: result)
        case "startScan":
            startServiceScan(call: call, result: result)
        case "stopScan":
            stopServiceScan(call: call, result: result)
        case "disconnect":
            disconnect(call: call, result: result)
        case "getBatteryLevel":
            getBatteryLevel(call: call, result: result)
        case "getSignalStrength":
            getSignalStrength(call: call, result: result)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialization

    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        serviceType = args["serviceType"] as? String ?? "_attendance._tcp"
        preferWifiAware = args["preferAware"] as? Bool ?? true
        let enableDebugLogs = args["enableDebugLogs"] as? Bool ?? false

        // Check Wi-Fi Aware availability (iOS 19+)
        let wifiAwareSupported = checkWifiAwareSupport()

        sendEvent([
            "type": "initialized",
            "message": "Plugin initialized successfully",
            "data": [
                "wifiAwareSupported": wifiAwareSupported,
                "iosVersion": UIDevice.current.systemVersion,
                "serviceType": serviceType
            ]
        ])

        result([
            "success": true,
            "wifiAwareSupported": wifiAwareSupported
        ])
    }

    private func checkWifiAwareSupport() -> Bool {
        // Wi-Fi Aware support check for iOS 19+
        if #available(iOS 19.0, *) {
            // Check if WiFiAware framework is available
            return true // Placeholder - actual implementation would check WiFiAware availability
        }
        return false
    }

    // MARK: - Room Creation

    private func createRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomId = args["roomId"] as? String,
              let ssid = args["ssid"] as? String,
              let password = args["password"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let expectedSize = args["expectedSize"] as? Int ?? 50
        currentRoomId = roomId

        // Try Wi-Fi Aware first if supported
        if preferWifiAware && checkWifiAwareSupport() {
            createWifiAwareNetwork(roomId: roomId, ssid: ssid, expectedSize: expectedSize) { awareResult in
                if let success = awareResult["success"] as? Bool, success {
                    result(awareResult)
                } else {
                    // Fallback to hotspot guidance
                    self.createHotspotGuidance(ssid: ssid, password: password, result: result)
                }
            }
        } else {
            // Use hotspot guidance for iOS
            createHotspotGuidance(ssid: ssid, password: password, result: result)
        }
    }

    @available(iOS 19.0, *)
    private func createWifiAwareNetwork(roomId: String, ssid: String, expectedSize: Int, completion: @escaping ([String: Any]) -> Void) {
        // Wi-Fi Aware implementation for iOS 19+
        // This would use the WiFiAware framework when available

        // Placeholder implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let localIp = self.getLocalIpAddress()
            completion([
                "success": true,
                "brokerIp": localIp,
                "brokerPort": 1883,
                "networkInterface": "WiFiAware",
                "method": "aware"
            ])

            self.sendEvent([
                "type": "wifiAwareStarted",
                "message": "Wi-Fi Aware network created",
                "data": ["roomId": roomId, "ssid": ssid]
            ])
        }
    }

    private func createHotspotGuidance(ssid: String, password: String, result: @escaping FlutterResult) {
        // iOS requires manual hotspot setup
        // Provide user guidance with clipboard integration

        // Copy password to clipboard
        UIPasteboard.general.string = password

        // Open Wi-Fi settings
        DispatchQueue.main.async {
            if let settingsUrl = URL(string: "App-Prefs:Wifi") {
                UIApplication.shared.open(settingsUrl, options: [:]) { success in
                    let localIp = self.getLocalIpAddress()

                    result([
                        "success": true,
                        "requiresManualSetup": true,
                        "ssid": ssid,
                        "password": password,
                        "passwordCopied": true,
                        "settingsOpened": success,
                        "brokerIp": localIp,
                        "brokerPort": 1883,
                        "networkInterface": "ManualHotspot",
                        "method": "manual"
                    ])

                    self.sendEvent([
                        "type": "hotspotGuidanceProvided",
                        "message": "Manual hotspot setup required - password copied to clipboard",
                        "data": [
                            "ssid": ssid,
                            "passwordCopied": true,
                            "settingsOpened": success
                        ]
                    ])
                }
            } else {
                result([
                    "success": false,
                    "error": "Cannot open Wi-Fi settings"
                ])
            }
        }
    }

    // MARK: - Network Joining

    private func joinNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ssid = args["ssid"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let password = args["password"] as? String
        let studentId = args["studentId"] as? String ?? ""

        joinNetworkProgrammatically(ssid: ssid, password: password) { joinResult in
            if let success = joinResult["success"] as? Bool, success {
                self.sendEvent([
                    "type": "networkJoined",
                    "message": "Successfully joined network: \(ssid)",
                    "data": [
                        "ssid": ssid,
                        "studentId": studentId
                    ]
                ])
            }
            result(joinResult)
        }
    }

    private func joinNetworkProgrammatically(ssid: String, password: String?, completion: @escaping ([String: Any]) -> Void) {
        let config = NEHotspotConfiguration(ssid: ssid)

        if let password = password, !password.isEmpty {
            config.preSharedKey = password
        }

        config.joinOnce = false // Keep configuration for future connections

        NEHotspotConfigurationManager.shared.apply(config) { error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorCode = (error as NSError).code

                    if errorCode == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        // Already connected to this network
                        completion([
                            "success": true,
                            "method": "hotspotConfig",
                            "message": "Already connected to network",
                            "alreadyConnected": true
                        ])
                    } else if errorCode == NEHotspotConfigurationError.userDenied.rawValue {
                        // User denied the connection
                        completion([
                            "success": false,
                            "error": "User denied network connection",
                            "requiresUserApproval": true
                        ])
                    } else {
                        completion([
                            "success": false,
                            "error": "Network join failed: \(error.localizedDescription)",
                            "errorCode": errorCode
                        ])
                    }
                } else {
                    // Successfully configured
                    self.currentHotspotConfig = config
                    completion([
                        "success": true,
                        "method": "hotspotConfig",
                        "message": "Network configuration applied successfully"
                    ])
                }
            }
        }
    }

    // MARK: - Network Scanning

    private func scanNetworks(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't allow direct Wi-Fi scanning without special entitlements
        // Return cached/known networks or guidance

        let knownNetworks = getKnownNetworks()

        result([
            "networks": knownNetworks,
            "count": knownNetworks.count,
            "note": "iOS Wi-Fi scanning requires special entitlements"
        ])
    }

    private func getKnownNetworks() -> [[String: Any]] {
        var networks: [[String: Any]] = []

        // Get current Wi-Fi info if available
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                if let interfaceName = interface as? String,
                   let info = CNCopyCurrentNetworkInfo(interfaceName as CFString) as NSDictionary? {

                    if let ssid = info[kCNNetworkInfoKeySSID as String] as? String,
                       let bssid = info[kCNNetworkInfoKeyBSSID as String] as? String {

                        networks.append([
                            "ssid": ssid,
                            "bssid": bssid,
                            "signalStrength": -50, // Placeholder
                            "isSecure": true,
                            "isCurrentNetwork": true,
                            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                        ])
                    }
                }
            }
        }

        return networks
    }

    // MARK: - Service Discovery

    private func startServiceBroadcast(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let serviceName = args["serviceName"] as? String,
              let serviceType = args["serviceType"] as? String,
              let port = args["port"] as? Int else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let txtRecords = args["txtRecords"] as? [String: String] ?? [:]

        // Stop existing service
        netService?.stop()

        // Create new service
        netService = NetService(domain: "", type: serviceType, name: serviceName, port: Int32(port))

        guard let service = netService else {
            result(FlutterError(code: "SERVICE_ERROR", message: "Failed to create service", details: nil))
            return
        }

        service.delegate = self

        // Set TXT records
        if !txtRecords.isEmpty {
            var txtData: [String: Data] = [:]
            for (key, value) in txtRecords {
                txtData[key] = value.data(using: .utf8)
            }
            service.setTXTRecord(NetService.data(fromTXTRecord: txtData))
        }

        service.publish()
        isBroadcasting = true

        result(["success": true])
    }

    private func stopServiceBroadcast(call: FlutterMethodCall, result: @escaping FlutterResult) {
        netService?.stop()
        netService = nil
        isBroadcasting = false

        result(["success": true])
    }

    private func startServiceScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let serviceType = args["serviceType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        // Stop existing browser
        netServiceBrowser?.stop()

        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: serviceType, inDomain: "")

        isScanning = true

        result(["success": true])
    }

    private func stopServiceScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
        netServiceBrowser?.stop()
        netServiceBrowser = nil
        isScanning = false

        result(["success": true])
    }

    private func performSingleScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let serviceType = args["serviceType"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let timeout = args["timeout"] as? Double ?? 10.0
        discoveredServices.removeAll()

        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: serviceType, inDomain: "")

        // Stop after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            browser.stop()

            let services = Array(self.discoveredServices.values)
            result([
                "services": services,
                "count": services.count
            ])
        }
    }

    // MARK: - Utility Methods

    private func disconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Stop all services
        netService?.stop()
        netServiceBrowser?.stop()

        // Remove hotspot configuration
        if let config = currentHotspotConfig {
            NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: config.ssid)
        }

        // Clean up
        netService = nil
        netServiceBrowser = nil
        currentHotspotConfig = nil
        currentRoomId = nil
        discoveredServices.removeAll()
        isScanning = false
        isBroadcasting = false

        sendEvent([
            "type": "disconnected",
            "message": "Disconnected from network"
        ])

        result(["success": true])
    }

    private func getBatteryLevel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = Int(UIDevice.current.batteryLevel * 100)

        result(["batteryLevel": batteryLevel >= 0 ? batteryLevel : -1])
    }

    private func getSignalStrength(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't provide direct access to Wi-Fi signal strength
        // Return estimated value or -1 if unavailable
        result(["signalStrength": -1])
    }

    private func getLocalIpAddress() -> String {
        var address: String = "192.168.1.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr

            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)

                    if name == "en0" || name == "pdp_ip0" || name.hasPrefix("en") {
                        var addr = interface?.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                        if getnameinfo(&addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
            }

            freeifaddrs(ifaddr)
        }

        return address
    }

    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    private func sendData(_ data: [String: Any]) {
        DispatchQueue.main.async {
            self.dataSink?(data)
        }
    }
}