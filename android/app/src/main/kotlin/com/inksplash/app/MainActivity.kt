package com.inksplash.app

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.espressif.provisioning.DeviceConnectionEvent
import com.espressif.provisioning.ESPConstants
import com.espressif.provisioning.ESPProvisionManager
import com.espressif.provisioning.WiFiAccessPoint
import com.espressif.provisioning.listeners.BleScanListener
import com.espressif.provisioning.listeners.ProvisionListener
import com.espressif.provisioning.listeners.ResponseListener
import com.espressif.provisioning.listeners.WiFiScanListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

class MainActivity : FlutterActivity() {
    private val channelName = "com.inksplash.app/provisioning"
    private val permissionRequestCode = 8119
    private val handler = Handler(Looper.getMainLooper())
    private val scannedDevices = mutableMapOf<String, ScannedDevice>()
    private val scannedSoftApDevices = mutableMapOf<String, WiFiAccessPoint>()
    private val pendingPermissionResults = mutableListOf<MethodChannel.Result>()

    private lateinit var provisionManager: ESPProvisionManager
    private var pendingConnectResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        provisionManager = ESPProvisionManager.getInstance(applicationContext)
        EventBus.getDefault().register(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {
            call,
            result ->
            when (call.method) {
                "requestPermissions" -> requestProvisioningPermissions(result)
                "searchBleDevices" -> searchBleDevices(call, result)
                "searchSoftApDevices" -> searchSoftApDevices(call, result)
                "connectBleDevice" -> connectBleDevice(call, result)
                "connectSoftApDevice" -> connectSoftApDevice(call, result)
                "scanWifiNetworks" -> scanWifiNetworks(result)
                "provisionWifi" -> provisionWifi(call, result)
                "disconnect" -> {
                    provisionManager.espDevice?.disconnectDevice()
                    releaseProvisioningNetwork()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this)
        }
        super.onDestroy()
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onDeviceConnectionEvent(event: DeviceConnectionEvent) {
        val result = pendingConnectResult ?: return
        when (event.eventType) {
            ESPConstants.EVENT_DEVICE_CONNECTED -> {
                pendingConnectResult = null
                result.success(null)
            }
            ESPConstants.EVENT_DEVICE_CONNECTION_FAILED -> {
                pendingConnectResult = null
                result.error("connect_failed", connectionFailureMessage(event), null)
            }
            ESPConstants.EVENT_DEVICE_DISCONNECTED -> {
                if (pendingConnectResult != null) {
                    pendingConnectResult = null
                    result.error("disconnected", "ESP device disconnected", null)
                }
            }
        }
    }

    private fun requestProvisioningPermissions(result: MethodChannel.Result) {
        val permissions = requiredPermissions().filter {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            } else {
                false
            }
        }
        if (permissions.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermissionResults.add(result)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(permissions.toTypedArray(), permissionRequestCode)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) {
            return
        }
        val granted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResults.forEach { it.success(granted) }
        pendingPermissionResults.clear()
    }

    private fun searchBleDevices(call: MethodCall, result: MethodChannel.Result) {
        val prefix = call.argument<String>("prefix") ?: "PROV_"
        scannedDevices.clear()
        provisionManager.createESPDevice(
            ESPConstants.TransportType.TRANSPORT_BLE,
            ESPConstants.SecurityType.SECURITY_1
        )
        var completed = false
        val timeout = Runnable {
            if (!completed) {
                completed = true
                result.success(scannedBleDevicePayload())
            }
        }
        handler.postDelayed(timeout, 12000)
        fun completeSuccess() {
            if (completed) return
            completed = true
            handler.removeCallbacks(timeout)
            result.success(scannedBleDevicePayload())
        }
        fun completeError(code: String, message: String) {
            if (completed) return
            completed = true
            handler.removeCallbacks(timeout)
            result.error(code, message, null)
        }
        provisionManager.searchBleEspDevices(prefix, object : BleScanListener {
            override fun scanStartFailed() {
                completeError("scan_start_failed", "Bluetooth scan could not start")
            }

            override fun onPeripheralFound(device: BluetoothDevice, scanResult: ScanResult) {
                val scanRecord = scanResult.scanRecord
                val name = scanRecord?.deviceName ?: device.name ?: return
                val serviceUuid = scanRecord?.serviceUuids?.firstOrNull()?.toString().orEmpty()
                scannedDevices[name] = ScannedDevice(device, serviceUuid, scanResult.rssi)
            }

            override fun scanCompleted() {
                completeSuccess()
            }

            override fun onFailure(e: Exception) {
                completeError("scan_failed", e.message ?: "Bluetooth scan failed")
            }
        })
    }

    private fun scannedBleDevicePayload(): List<Map<String, Any?>> {
        return scannedDevices.map { (name, scanned) ->
            mapOf(
                "name" to name,
                "serviceUuid" to scanned.serviceUuid,
                "rssi" to scanned.rssi
            )
        }
    }

    private fun connectBleDevice(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val proofOfPossession = call.argument<String>("proofOfPossession") ?: ""
        val security = call.argument<Int>("security") ?: 1
        val scanned = scannedDevices[name]
        if (name == null || scanned == null) {
            result.error("device_not_found", "Device was not found in the last BLE scan", null)
            return
        }
        provisionManager.createESPDevice(
            ESPConstants.TransportType.TRANSPORT_BLE,
            if (security == 0) ESPConstants.SecurityType.SECURITY_0 else ESPConstants.SecurityType.SECURITY_1
        )
        provisionManager.espDevice.setProofOfPossession(proofOfPossession)
        pendingConnectResult = result
        provisionManager.espDevice.connectBLEDevice(scanned.bluetoothDevice, scanned.serviceUuid)
        handler.postDelayed({
            pendingConnectResult?.let {
                pendingConnectResult = null
                it.error("connect_timeout", "Timed out while connecting to ESP device", null)
            }
        }, 30000)
    }

    private fun searchSoftApDevices(call: MethodCall, result: MethodChannel.Result) {
        val prefix = call.argument<String>("prefix") ?: "PROV_"
        val expectedName = call.argument<String>("name") ?: prefix
        scannedSoftApDevices.clear()
        provisionManager.createESPDevice(
            ESPConstants.TransportType.TRANSPORT_SOFTAP,
            ESPConstants.SecurityType.SECURITY_1
        )
        var completed = false
        val timeout = Runnable {
            if (!completed) {
                completed = true
                result.success(scannedSoftApDevicePayload(expectedName))
            }
        }
        handler.postDelayed(timeout, 12000)
        fun completeSuccess() {
            if (completed) return
            completed = true
            handler.removeCallbacks(timeout)
            result.success(scannedSoftApDevicePayload(expectedName))
        }
        fun completeError(code: String, message: String) {
            if (completed) return
            completed = true
            handler.removeCallbacks(timeout)
            result.error(code, message, null)
        }
        provisionManager.searchWiFiEspDevices(prefix, object : WiFiScanListener {
            override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>) {
                wifiList.forEach { accessPoint ->
                    if (accessPoint.wifiName.startsWith(prefix)) {
                        scannedSoftApDevices[accessPoint.wifiName] = accessPoint
                    }
                }
                completeSuccess()
            }

            override fun onWiFiScanFailed(e: Exception) {
                completeError("softap_scan_failed", e.message ?: "SoftAP scan failed")
            }
        })
    }

    private fun scannedSoftApDevicePayload(expectedName: String): List<Map<String, Any?>> {
        if (scannedSoftApDevices.isEmpty() && expectedName.isNotBlank()) {
            return listOf(
                mapOf(
                    "name" to expectedName,
                    "serviceUuid" to "",
                    "rssi" to null,
                    "security" to null
                )
            )
        }
        return scannedSoftApDevices.map { (name, accessPoint) ->
            mapOf(
                "name" to name,
                "serviceUuid" to "",
                "rssi" to accessPoint.rssi,
                "security" to accessPoint.security
            )
        }
    }

    private fun connectSoftApDevice(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val proofOfPossession = call.argument<String>("proofOfPossession") ?: ""
        val password = call.argument<String>("password") ?: ""
        val security = call.argument<Int>("security") ?: 1
        val accessPoint = scannedSoftApDevices[name]
        if (name == null) {
            result.error("device_not_found", "SoftAP device name is required", null)
            return
        }
        provisionManager.createESPDevice(
            ESPConstants.TransportType.TRANSPORT_SOFTAP,
            if (security == 0) ESPConstants.SecurityType.SECURITY_0 else ESPConstants.SecurityType.SECURITY_1
        )
        provisionManager.espDevice.setProofOfPossession(proofOfPossession)
        provisionManager.espDevice.setDeviceName(name)
        if (accessPoint != null) {
            provisionManager.espDevice.setWifiDevice(accessPoint)
        }
        var completed = false
        fun completeSuccess() {
            if (completed) return
            completed = true
            result.success(null)
        }
        fun completeError(code: String, message: String) {
            if (completed) return
            completed = true
            result.error(code, message, null)
        }
        fun initSoftApSession() {
            provisionManager.espDevice.initSession(object : ResponseListener {
                override fun onSuccess(returnData: ByteArray?) {
                    completeSuccess()
                }

                override fun onFailure(e: Exception) {
                    completeError(
                        "session_failed",
                        e.message ?: "Could not open ESP SoftAP provisioning session"
                    )
                }
            })
        }
        if (password.isEmpty()) {
            // When the user has already joined the SoftAP in system Wi-Fi
            // settings, the SDK's Wi-Fi connection event may never fire.
            // Opening the provisioning session is the real readiness check.
            provisionManager.espDevice.connectWiFiDevice()
            handler.postDelayed({ initSoftApSession() }, 1000)
        } else {
            provisionManager.espDevice.connectWiFiDevice(name, password)
            handler.postDelayed({ initSoftApSession() }, 4000)
        }
        handler.postDelayed({
            if (!completed) {
                completeError(
                    "connect_timeout",
                    "Timed out while opening ESP SoftAP provisioning session"
                )
            }
        }, 30000)
    }

    private fun scanWifiNetworks(result: MethodChannel.Result) {
        provisionManager.espDevice.scanNetworks(object : WiFiScanListener {
            override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>) {
                result.success(wifiList.map {
                    mapOf(
                        "ssid" to it.wifiName,
                        "rssi" to it.rssi,
                        "security" to it.security
                    )
                })
            }

            override fun onWiFiScanFailed(e: Exception) {
                result.error("wifi_scan_failed", e.message ?: "Wi-Fi scan failed", null)
            }
        })
    }

    private fun provisionWifi(call: MethodCall, result: MethodChannel.Result) {
        val ssid = call.argument<String>("ssid") ?: ""
        val password = call.argument<String>("password") ?: ""
        provisionManager.espDevice.provision(ssid, password, object : ProvisionListener {
            override fun createSessionFailed(e: Exception) {
                result.error("session_failed", e.message ?: "Provisioning session failed", null)
            }

            override fun wifiConfigSent() = Unit

            override fun wifiConfigFailed(e: Exception) {
                result.error("wifi_config_failed", e.message ?: "Wi-Fi config failed", null)
            }

            override fun wifiConfigApplied() = Unit

            override fun wifiConfigApplyFailed(e: Exception) {
                result.error("wifi_apply_failed", e.message ?: "Wi-Fi apply failed", null)
            }

            override fun provisioningFailedFromDevice(failureReason: ESPConstants.ProvisionFailureReason) {
                result.error("provision_failed", failureReason.name, null)
            }

            override fun deviceProvisioningSuccess() {
                result.success(null)
            }

            override fun onProvisioningFailed(e: Exception) {
                result.error("provision_failed", e.message ?: "Provisioning failed", null)
            }
        })
    }

    private fun requiredPermissions(): List<String> {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.CAMERA,
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.CHANGE_WIFI_STATE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        return permissions
    }

    private fun connectionFailureMessage(event: DeviceConnectionEvent): String {
        val data = event.data ?: return "Failed to connect to ESP device. For SoftAP without a password, connect the phone to the device hotspot in system Wi-Fi settings first."
        val details = data.keySet().joinToString(", ") { key -> "$key=${data.get(key)}" }
        return if (details.isBlank()) {
            "Failed to connect to ESP device. For SoftAP without a password, connect the phone to the device hotspot in system Wi-Fi settings first."
        } else {
            "Failed to connect to ESP device: $details"
        }
    }

    private fun releaseProvisioningNetwork() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val connectivityManager = getSystemService(ConnectivityManager::class.java)
            connectivityManager.bindProcessToNetwork(null)
        }
    }

    private data class ScannedDevice(
        val bluetoothDevice: BluetoothDevice,
        val serviceUuid: String,
        val rssi: Int
    )
}
