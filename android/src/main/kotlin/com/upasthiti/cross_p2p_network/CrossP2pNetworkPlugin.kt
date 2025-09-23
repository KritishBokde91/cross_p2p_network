package com.upasthiti.cross_p2p_network

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkRequest
import android.net.wifi.*
import android.net.wifi.aware.*
import android.os.BatteryManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import kotlinx.coroutines.*
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** CrossP2PNetworkPlugin */
class CrossP2PNetworkPlugin: FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var dataChannel: EventChannel

    private var context: Context? = null
    private var activity: android.app.Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    // Network components
    private var wifiManager: WifiManager? = null
    private var wifiAwareManager: WifiAwareManager? = null
    private var connectivityManager: ConnectivityManager? = null

    // Hotspot and networking
    private var localOnlyHotspot: WifiManager.LocalOnlyHotspot? = null
    private var currentNetworkCallback: ConnectivityManager.NetworkCallback? = null

    // Wi-Fi Aware components
    private var awareSession: WifiAwareSession? = null
    private var publishSession: PublishDiscoverySession? = null
    private var subscribeSession: SubscribeDiscoverySession? = null

    // Service Discovery
    private var nsdManager: android.net.nsd.NsdManager? = null
    private var registrationListener: android.net.nsd.NsdManager.RegistrationListener? = null
    private var discoveryListener: android.net.nsd.NsdManager.DiscoveryListener? = null

    // Event streams
    private var eventSink: EventChannel.EventSink? = null
    private var dataSink: EventChannel.EventSink? = null

    // State management
    private var isInitialized = false
    private var preferWifiAware = true
    private var serviceType = "_attendance._tcp"
    private var currentRoomId: String? = null

    // Coroutine scope
    private val pluginScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Cache for network information
    private val networkCache = ConcurrentHashMap<String, Map<String, Any>>()

    companion object {
        private const val TAG = "CrossP2PNetwork"
        private const val HOTSPOT_REQUEST_CODE = 1001
        private const val CHANNEL_NAME = "cross_p2p_network"
        private const val EVENT_CHANNEL_NAME = "cross_p2p_network/events"
        private const val DATA_CHANNEL_NAME = "cross_p2p_network/data"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL_NAME)
        dataChannel = EventChannel(flutterPluginBinding.binaryMessenger, DATA_CHANNEL_NAME)

        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(EventStreamHandler())
        dataChannel.setStreamHandler(DataStreamHandler())

        context = flutterPluginBinding.applicationContext
        initializeManagers()
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cleanup()
        pluginScope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResult)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResult)
    }

    override fun onDetachedFromActivity() {
        activity = null
        activityBinding?.removeRequestPermissionsResultListener(::onRequestPermissionsResult)
        activityBinding = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "createRoom" -> createRoom(call, result)
            "joinNetwork" -> joinNetwork(call, result)
            "scanNetworks" -> scanNetworks(call, result)
            "singleScan" -> performSingleScan(call, result)
            "startBroadcast" -> startServiceBroadcast(call, result)
            "stopBroadcast" -> stopServiceBroadcast(call, result)
            "startScan" -> startServiceScan(call, result)
            "stopScan" -> stopServiceScan(call, result)
            "disconnect" -> disconnect(call, result)
            "getBatteryLevel" -> getBatteryLevel(call, result)
            "getSignalStrength" -> getSignalStrength(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initializeManagers() {
        context?.let { ctx ->
            wifiManager = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            connectivityManager = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            nsdManager = ctx.getSystemService(Context.NSD_SERVICE) as android.net.nsd.NsdManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                wifiAwareManager = ctx.getSystemService(Context.WIFI_AWARE_SERVICE) as? WifiAwareManager
            }
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            serviceType = args["serviceType"] as? String ?: "_attendance._tcp"
            preferWifiAware = args["preferAware"] as? Boolean ?: true
            val enableDebugLogs = args["enableDebugLogs"] as? Boolean ?: false

            // Check Wi-Fi Aware availability
            val awareSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    wifiAwareManager?.isAvailable == true

            isInitialized = true

            sendEvent(mapOf(
                "type" to "initialized",
                "message" to "Plugin initialized successfully",
                "data" to mapOf(
                    "wifiAwareSupported" to awareSupported,
                    "androidVersion" to Build.VERSION.SDK_INT,
                    "serviceType" to serviceType
                )
            ))

            result.success(mapOf(
                "success" to true,
                "wifiAwareSupported" to awareSupported
            ))

        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
        }
    }

    private fun createRoom(call: MethodCall, result: MethodChannel.Result) {
        if (!isInitialized) {
            result.error("NOT_INITIALIZED", "Plugin not initialized", null)
            return
        }

        pluginScope.launch {
            try {
                val args = call.arguments as Map<String, Any>
                val roomId = args["roomId"] as String
                val ssid = args["ssid"] as String
                val password = args["password"] as String
                val expectedSize = args["expectedSize"] as? Int ?: 50

                currentRoomId = roomId

                // Try Wi-Fi Aware first if supported and preferred
                if (preferWifiAware && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    wifiAwareManager?.isAvailable == true) {

                    val awareResult = createWifiAwareNetwork(roomId, ssid, expectedSize)
                    if (awareResult["success"] == true) {
                        result.success(awareResult)
                        return@launch
                    }
                }

                // Fallback to hotspot
                val hotspotResult = createHotspot(ssid, password)
                result.success(hotspotResult)

            } catch (e: Exception) {
                result.error("CREATE_ROOM_ERROR", "Failed to create room: ${e.message}", null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private suspend fun createHotspot(ssid: String, password: String): Map<String, Any> {
        return withContext(Dispatchers.Main) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Use LocalOnlyHotspot for Android 8+
                    createLocalOnlyHotspot(ssid, password)
                } else {
                    // Legacy hotspot creation for older Android versions
                    createLegacyHotspot(ssid, password)
                }
            } catch (e: Exception) {
                mapOf(
                    "success" to false,
                    "error" to "Hotspot creation failed: ${e.message}"
                )
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun createLocalOnlyHotspot(ssid: String, password: String): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return mapOf("success" to false, "error" to "LocalOnlyHotspot not supported")
        }

        return try {
            val callback = object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspot?) {
                    localOnlyHotspot = reservation

                    val config = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        reservation?.softApConfiguration
                    } else {
                        @Suppress("DEPRECATION")
                        reservation?.wifiConfiguration
                    }

                    sendEvent(mapOf(
                        "type" to "hotspotStarted",
                        "message" to "Hotspot started successfully",
                        "data" to mapOf(
                            "ssid" to (config?.let { getConfigSsid(it) } ?: ssid),
                            "password" to (config?.let { getConfigPassword(it) } ?: password)
                        )
                    ))
                }

                override fun onStopped() {
                    localOnlyHotspot = null
                    sendEvent(mapOf(
                        "type" to "hotspotStopped",
                        "message" to "Hotspot stopped"
                    ))
                }

                override fun onFailed(reason: Int) {
                    val errorMsg = when (reason) {
                        ERROR_INCOMPATIBLE_MODE -> "Incompatible mode"
                        ERROR_NO_CHANNEL -> "No channel available"
                        ERROR_TETHERING_DISALLOWED -> "Tethering disallowed"
                        else -> "Unknown error: $reason"
                    }
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Hotspot failed: $errorMsg"
                    ))
                }
            }

            wifiManager?.startLocalOnlyHotspot(callback, null)

            // Get local IP
            val localIp = getLocalIpAddress()

            mapOf(
                "success" to true,
                "brokerIp" to localIp,
                "brokerPort" to 1883,
                "networkInterface" to "LocalOnlyHotspot",
                "method" to "hotspot"
            )

        } catch (e: Exception) {
            mapOf(
                "success" to false,
                "error" to "LocalOnlyHotspot creation failed: ${e.message}"
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun createLegacyHotspot(ssid: String, password: String): Map<String, Any> {
        // Legacy hotspot creation for Android < 8
        return try {
            // This would require system-level permissions and is generally not recommended
            // Return guidance for manual setup instead
            mapOf(
                "success" to false,
                "error" to "Legacy hotspot not supported - manual setup required",
                "requiresManualSetup" to true,
                "ssid" to ssid,
                "password" to password
            )
        } catch (e: Exception) {
            mapOf(
                "success" to false,
                "error" to "Legacy hotspot failed: ${e.message}"
            )
        }
    }

    private fun createWifiAwareNetwork(roomId: String, ssid: String, expectedSize: Int): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || wifiAwareManager?.isAvailable != true) {
            return mapOf("success" to false, "error" to "Wi-Fi Aware not available")
        }

        return try {
            val attachCallback = object : AttachCallback() {
                override fun onAttached(session: WifiAwareSession) {
                    awareSession = session
                    startWifiAwarePublish(session, roomId, ssid)
                }

                override fun onAttachFailed() {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Wi-Fi Aware attach failed"
                    ))
                }
            }

            wifiAwareManager!!.attach(attachCallback, null)

            val localIp = getLocalIpAddress()

            mapOf(
                "success" to true,
                "brokerIp" to localIp,
                "brokerPort" to 1883,
                "networkInterface" to "WiFiAware",
                "method" to "aware"
            )

        } catch (e: Exception) {
            mapOf(
                "success" to false,
                "error" to "Wi-Fi Aware setup failed: ${e.message}"
            )
        }
    }

    private fun startWifiAwarePublish(session: WifiAwareSession, roomId: String, ssid: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        try {
            val publishConfig = PublishConfig.Builder()
                .setServiceName("AttendanceRoom_$roomId")
                .setServiceSpecificInfo(ssid.toByteArray())
                .build()

            val callback = object : DiscoverySessionCallback() {
                override fun onPublishStarted(session: PublishDiscoverySession) {
                    publishSession = session
                    sendEvent(mapOf(
                        "type" to "wifiAwarePublishStarted",
                        "message" to "Wi-Fi Aware publish started",
                        "data" to mapOf("roomId" to roomId, "ssid" to ssid)
                    ))
                }

                override fun onSessionConfigFailed() {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Wi-Fi Aware publish config failed"
                    ))
                }

                override fun onMessageSendSucceeded(messageId: Int) {
                    // Handle message send success
                }

                override fun onMessageSendFailed(messageId: Int) {
                    // Handle message send failure
                }
            }

            session.publish(publishConfig, callback, null)

        } catch (e: Exception) {
            sendEvent(mapOf(
                "type" to "error",
                "message" to "Wi-Fi Aware publish failed: ${e.message}"
            ))
        }
    }

    private fun joinNetwork(call: MethodCall, result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                val args = call.arguments as Map<String, Any>
                val ssid = args["ssid"] as String
                val password = args["password"] as? String
                val studentId = args["studentId"] as String

                val joinResult = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    joinNetworkModern(ssid, password)
                } else {
                    joinNetworkLegacy(ssid, password)
                }

                if (joinResult["success"] == true) {
                    sendEvent(mapOf(
                        "type" to "networkJoined",
                        "message" to "Successfully joined network: $ssid",
                        "data" to mapOf(
                            "ssid" to ssid,
                            "studentId" to studentId
                        )
                    ))
                }

                result.success(joinResult)

            } catch (e: Exception) {
                result.error("JOIN_ERROR", "Failed to join network: ${e.message}", null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private suspend fun joinNetworkModern(ssid: String, password: String?): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return joinNetworkLegacy(ssid, password)
        }

        return withContext(Dispatchers.Main) {
            try {
                val suggestion = WifiNetworkSuggestion.Builder()
                    .setSsid(ssid)
                    .apply {
                        if (!password.isNullOrEmpty()) {
                            setWpa2Passphrase(password)
                        }
                    }
                    .setIsAppInteractionRequired(false)
                    .build()

                val suggestionsList = listOf(suggestion)
                val status = wifiManager?.addNetworkSuggestions(suggestionsList)

                when (status) {
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS -> {
                        mapOf(
                            "success" to true,
                            "method" to "networkSuggestion",
                            "message" to "Network suggestion added successfully"
                        )
                    }
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE -> {
                        mapOf(
                            "success" to true,
                            "method" to "networkSuggestion",
                            "message" to "Network already suggested"
                        )
                    }
                    else -> {
                        mapOf(
                            "success" to false,
                            "error" to "Network suggestion failed with status: $status"
                        )
                    }
                }
            } catch (e: Exception) {
                mapOf(
                    "success" to false,
                    "error" to "Modern join failed: ${e.message}"
                )
            }
        }
    }

    @Suppress("DEPRECATION")
    private suspend fun joinNetworkLegacy(ssid: String, password: String?): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            try {
                val wifiConfig = WifiConfiguration().apply {
                    SSID = "\"$ssid\""
                    if (!password.isNullOrEmpty()) {
                        preSharedKey = "\"$password\""
                        allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                    } else {
                        allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                    }
                }

                val networkId = wifiManager?.addNetwork(wifiConfig)
                if (networkId != null && networkId != -1) {
                    val enabled = wifiManager?.enableNetwork(networkId, true) ?: false
                    if (enabled) {
                        // Wait for connection
                        delay(5000)
                        val connected = isConnectedToNetwork(ssid)
                        mapOf(
                            "success" to connected,
                            "method" to "legacy",
                            "networkId" to networkId,
                            "message" to if (connected) "Connected successfully" else "Connection timeout"
                        )
                    } else {
                        mapOf(
                            "success" to false,
                            "error" to "Failed to enable network"
                        )
                    }
                } else {
                    mapOf(
                        "success" to false,
                        "error" to "Failed to add network configuration"
                    )
                }
            } catch (e: Exception) {
                mapOf(
                    "success" to false,
                    "error" to "Legacy join failed: ${e.message}"
                )
            }
        }
    }

    private fun scanNetworks(call: MethodCall, result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                val networks = performWifiScan()
                result.success(mapOf(
                    "networks" to networks,
                    "count" to networks.size
                ))
            } catch (e: Exception) {
                result.error("SCAN_ERROR", "Failed to scan networks: ${e.message}", null)
            }
        }
    }

    private suspend fun performWifiScan(): List<Map<String, Any>> {
        return withContext(Dispatchers.IO) {
            try {
                val scanResults = wifiManager?.scanResults ?: emptyList()

                scanResults
                    .filter { it.SSID.isNotEmpty() }
                    .distinctBy { it.SSID }
                    .map { scanResult ->
                        mapOf(
                            "ssid" to scanResult.SSID,
                            "bssid" to scanResult.BSSID,
                            "signalStrength" to scanResult.level,
                            "frequency" to scanResult.frequency,
                            "capabilities" to scanResult.capabilities,
                            "isSecure" to !scanResult.capabilities.contains("NONE"),
                            "timestamp" to System.currentTimeMillis()
                        )
                    }
                    .sortedByDescending { it["signalStrength"] as Int }

            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    // Service Discovery Methods

    private fun startServiceBroadcast(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val serviceName = args["serviceName"] as String
            val serviceType = args["serviceType"] as String
            val port = args["port"] as Int
            val txtRecords = args["txtRecords"] as Map<String, String>

            val serviceInfo = android.net.nsd.NsdServiceInfo().apply {
                this.serviceName = serviceName
                this.serviceType = serviceType
                this.port = port

                // Add TXT records
                txtRecords.forEach { (key, value) ->
                    setAttribute(key, value)
                }
            }

            registrationListener = object : android.net.nsd.NsdManager.RegistrationListener {
                override fun onServiceRegistered(nsdServiceInfo: android.net.nsd.NsdServiceInfo) {
                    sendEvent(mapOf(
                        "type" to "serviceRegistered",
                        "message" to "Service registered: ${nsdServiceInfo.serviceName}",
                        "data" to mapOf(
                            "serviceName" to nsdServiceInfo.serviceName,
                            "serviceType" to nsdServiceInfo.serviceType
                        )
                    ))
                }

                override fun onRegistrationFailed(serviceInfo: android.net.nsd.NsdServiceInfo, errorCode: Int) {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Service registration failed: $errorCode"
                    ))
                }

                override fun onServiceUnregistered(arg0: android.net.nsd.NsdServiceInfo) {
                    sendEvent(mapOf(
                        "type" to "serviceUnregistered",
                        "message" to "Service unregistered"
                    ))
                }

                override fun onUnregistrationFailed(serviceInfo: android.net.nsd.NsdServiceInfo, errorCode: Int) {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Service unregistration failed: $errorCode"
                    ))
                }
            }

            nsdManager?.registerService(serviceInfo, android.net.nsd.NsdManager.PROTOCOL_DNS_SD, registrationListener)
            result.success(mapOf("success" to true))

        } catch (e: Exception) {
            result.error("BROADCAST_ERROR", "Failed to start broadcast: ${e.message}", null)
        }
    }

    private fun stopServiceBroadcast(call: MethodCall, result: MethodChannel.Result) {
        try {
            registrationListener?.let { listener ->
                nsdManager?.unregisterService(listener)
                registrationListener = null
            }
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            result.error("STOP_BROADCAST_ERROR", "Failed to stop broadcast: ${e.message}", null)
        }
    }

    private fun startServiceScan(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val serviceType = args["serviceType"] as String

            discoveryListener = object : android.net.nsd.NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(regType: String) {
                    sendEvent(mapOf(
                        "type" to "discoveryStarted",
                        "message" to "Discovery started for: $regType"
                    ))
                }

                override fun onServiceFound(service: android.net.nsd.NsdServiceInfo) {
                    sendEvent(mapOf(
                        "type" to "serviceFound",
                        "message" to "Service found: ${service.serviceName}",
                        "data" to mapOf(
                            "serviceName" to service.serviceName,
                            "serviceType" to service.serviceType
                        )
                    ))

                    // Resolve service for detailed info
                    nsdManager?.resolveService(service, createResolveListener())
                }

                override fun onServiceLost(service: android.net.nsd.NsdServiceInfo) {
                    sendEvent(mapOf(
                        "type" to "serviceLost",
                        "message" to "Service lost: ${service.serviceName}"
                    ))
                }

                override fun onDiscoveryStopped(serviceType: String) {
                    sendEvent(mapOf(
                        "type" to "discoveryStopped",
                        "message" to "Discovery stopped for: $serviceType"
                    ))
                }

                override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Discovery start failed: $errorCode"
                    ))
                }

                override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                    sendEvent(mapOf(
                        "type" to "error",
                        "message" to "Discovery stop failed: $errorCode"
                    ))
                }
            }

            nsdManager?.discoverServices(serviceType, android.net.nsd.NsdManager.PROTOCOL_DNS_SD, discoveryListener)
            result.success(mapOf("success" to true))

        } catch (e: Exception) {
            result.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
        }
    }

    private fun createResolveListener() = object : android.net.nsd.NsdManager.ResolveListener {
        override fun onResolveFailed(serviceInfo: android.net.nsd.NsdServiceInfo, errorCode: Int) {
            // Resolution failed
        }

        override fun onServiceResolved(serviceInfo: android.net.nsd.NsdServiceInfo) {
            val serviceData = mutableMapOf<String, Any>(
                "serviceId" to "${serviceInfo.serviceName}_${serviceInfo.serviceType}",
                "serviceName" to serviceInfo.serviceName,
                "serviceType" to serviceInfo.serviceType,
                "hostName" to (serviceInfo.host?.hostAddress ?: ""),
                "port" to serviceInfo.port
            )

            // Extract TXT records
            val txtRecords = mutableMapOf<String, String>()
            serviceInfo.attributes?.forEach { (key, value) ->
                txtRecords[key] = String(value)
            }
            serviceData["txtRecords"] = txtRecords

            sendEvent(mapOf(
                "type" to "serviceResolved",
                "message" to "Service resolved: ${serviceInfo.serviceName}",
                "data" to serviceData
            ))
        }
    }

    private fun stopServiceScan(call: MethodCall, result: MethodChannel.Result) {
        try {
            discoveryListener?.let { listener ->
                nsdManager?.stopServiceDiscovery(listener)
                discoveryListener = null
            }
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            result.error("STOP_SCAN_ERROR", "Failed to stop scan: ${e.message}", null)
        }
    }

    private fun performSingleScan(call: MethodCall, result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                val args = call.arguments as Map<String, Any>
                val serviceType = args["serviceType"] as String
                val timeout = args["timeout"] as? Int ?: 10000

                val services = mutableListOf<Map<String, Any>>()
                val discoveredServices = mutableSetOf<String>()

                val tempListener = object : android.net.nsd.NsdManager.DiscoveryListener {
                    override fun onDiscoveryStarted(regType: String) {}

                    override fun onServiceFound(service: android.net.nsd.NsdServiceInfo) {
                        val serviceKey = "${service.serviceName}_${service.serviceType}"
                        if (!discoveredServices.contains(serviceKey)) {
                            discoveredServices.add(serviceKey)

                            // Resolve immediately for single scan
                            nsdManager?.resolveService(service, object : android.net.nsd.NsdManager.ResolveListener {
                                override fun onResolveFailed(serviceInfo: android.net.nsd.NsdServiceInfo, errorCode: Int) {}

                                override fun onServiceResolved(serviceInfo: android.net.nsd.NsdServiceInfo) {
                                    val txtRecords = mutableMapOf<String, String>()
                                    serviceInfo.attributes?.forEach { (key, value) ->
                                        txtRecords[key] = String(value)
                                    }

                                    services.add(mapOf(
                                        "serviceId" to serviceKey,
                                        "serviceName" to serviceInfo.serviceName,
                                        "serviceType" to serviceInfo.serviceType,
                                        "hostName" to (serviceInfo.host?.hostAddress ?: ""),
                                        "port" to serviceInfo.port,
                                        "txtRecords" to txtRecords
                                    ))
                                }
                            })
                        }
                    }

                    override fun onServiceLost(service: android.net.nsd.NsdServiceInfo) {}
                    override fun onDiscoveryStopped(serviceType: String) {}
                    override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
                    override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
                }

                nsdManager?.discoverServices(serviceType, android.net.nsd.NsdManager.PROTOCOL_DNS_SD, tempListener)

                // Wait for timeout
                delay(timeout.toLong())

                nsdManager?.stopServiceDiscovery(tempListener)

                result.success(mapOf(
                    "services" to services,
                    "count" to services.size
                ))

            } catch (e: Exception) {
                result.error("SINGLE_SCAN_ERROR", "Single scan failed: ${e.message}", null)
            }
        }
    }

    private fun disconnect(call: MethodCall, result: MethodChannel.Result) {
        try {
            // Stop Wi-Fi Aware
            publishSession?.close()
            subscribeSession?.close()
            awareSession?.close()

            // Stop hotspot
            localOnlyHotspot?.close()
            localOnlyHotspot = null

            // Stop service discovery
            stopServiceBroadcast(MethodCall("stopBroadcast", null), object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })

            stopServiceScan(MethodCall("stopScan", null), object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })

            // Clear network callback
            currentNetworkCallback?.let { callback ->
                connectivityManager?.unregisterNetworkCallback(callback)
            }

            currentRoomId = null
            networkCache.clear()

            sendEvent(mapOf(
                "type" to "disconnected",
                "message" to "Disconnected from network"
            ))

            result.success(mapOf("success" to true))

        } catch (e: Exception) {
            result.error("DISCONNECT_ERROR", "Failed to disconnect: ${e.message}", null)
        }
    }

    private fun getBatteryLevel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val batteryIntent = context?.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1

            val batteryLevel = if (level >= 0 && scale > 0) {
                (level * 100 / scale)
            } else {
                -1
            }

            result.success(mapOf("batteryLevel" to batteryLevel))

        } catch (e: Exception) {
            result.error("BATTERY_ERROR", "Failed to get battery level: ${e.message}", null)
        }
    }

    private fun getSignalStrength(call: MethodCall, result: MethodChannel.Result) {
        try {
            val wifiInfo = wifiManager?.connectionInfo
            val rssi = wifiInfo?.rssi ?: Int.MIN_VALUE

            result.success(mapOf("signalStrength" to rssi))

        } catch (e: Exception) {
            result.error("SIGNAL_ERROR", "Failed to get signal strength: ${e.message}", null)
        }
    }

    // Helper methods

    private fun getLocalIpAddress(): String {
        return try {
            val wifiInfo = wifiManager?.connectionInfo
            val ip = wifiInfo?.ipAddress ?: 0

            if (ip != 0) {
                "${ip and 0xff}.${ip shr 8 and 0xff}.${ip shr 16 and 0xff}.${ip shr 24 and 0xff}"
            } else {
                // Fallback to get IP from NetworkInterface
                java.net.NetworkInterface.getNetworkInterfaces().toList()
                    .flatMap { it.inetAddresses.toList() }
                    .find { !it.isLoopbackAddress && it is java.net.Inet4Address }
                    ?.hostAddress ?: "192.168.1.1"
            }
        } catch (e: Exception) {
            "192.168.1.1"
        }
    }

    private fun isConnectedToNetwork(targetSsid: String): Boolean {
        return try {
            val wifiInfo = wifiManager?.connectionInfo
            val currentSsid = wifiInfo?.ssid?.replace("\"", "") ?: ""
            currentSsid == targetSsid
        } catch (e: Exception) {
            false
        }
    }

    private fun getConfigSsid(config: Any): String {
        return when (config) {
            is WifiConfiguration -> config.SSID?.replace("\"", "") ?: ""
            is SoftApConfiguration -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    config.ssid ?: ""
                } else {
                    ""
                }
            }
            else -> ""
        }
    }

    private fun getConfigPassword(config: Any): String {
        return when (config) {
            is WifiConfiguration -> config.preSharedKey?.replace("\"", "") ?: ""
            is SoftApConfiguration -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    config.passphrase ?: ""
                } else {
                    ""
                }
            }
            else -> ""
        }
    }

    private fun sendEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }

    private fun sendData(data: Map<String, Any>) {
        dataSink?.success(data)
    }

    private fun cleanup() {
        try {
            disconnect(MethodCall("disconnect", null), object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })

            publishSession = null
            subscribeSession = null
            awareSession = null
            registrationListener = null
            discoveryListener = null

        } catch (e: Exception) {
            // Ignore cleanup errors
        }
    }

    private fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        // Handle permission results if needed
        return false
    }

    // Event stream handlers
    inner class EventStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    inner class DataStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            dataSink = events
        }

        override fun onCancel(arguments: Any?) {
            dataSink = null
        }
    }
}