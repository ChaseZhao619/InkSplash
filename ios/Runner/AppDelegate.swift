import Flutter
import UIKit
import ESPProvision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, ESPDeviceConnectionDelegate {
  private let channelName = "com.inksplash.app/provisioning"
  private var devicesByName: [String: ESPDevice] = [:]
  private var currentDevice: ESPDevice?
  private var pendingProofOfPossession = ""

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "requestPermissions":
        result(true)
      case "searchBleDevices":
        self.searchBleDevices(call: call, result: result)
      case "searchSoftApDevices":
        self.searchSoftApDevices(call: call, result: result)
      case "connectBleDevice":
        self.connectBleDevice(call: call, result: result)
      case "connectSoftApDevice":
        self.connectSoftApDevice(call: call, result: result)
      case "scanWifiNetworks":
        self.scanWifiNetworks(result: result)
      case "provisionWifi":
        self.provisionWifi(call: call, result: result)
      case "disconnect":
        self.currentDevice = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
    completionHandler(pendingProofOfPossession)
  }

  func getUsername(forDevice: ESPDevice, completionHandler: @escaping (String?) -> Void) {
    completionHandler(nil)
  }

  private func searchBleDevices(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let prefix = args?["prefix"] as? String ?? "PROV_"
    devicesByName.removeAll()
    ESPProvisionManager.shared.searchESPDevices(
      devicePrefix: prefix,
      transport: .ble,
      security: .secure
    ) { [weak self] devices, error in
      if let error {
        result(FlutterError(code: "scan_failed", message: error.description, details: nil))
        return
      }
      let payload = (devices ?? []).map { device -> [String: Any] in
        let name = device.advertisementData?["kCBAdvDataLocalName"] as? String ?? "ESP Device"
        self?.devicesByName[name] = device
        return [
          "name": name,
          "serviceUuid": "",
          "rssi": 0
        ]
      }
      result(payload)
    }
  }

  private func connectBleDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let name = args?["name"] as? String, let device = devicesByName[name] else {
      result(FlutterError(code: "device_not_found", message: "Device was not found in the last BLE scan", details: nil))
      return
    }
    pendingProofOfPossession = args?["proofOfPossession"] as? String ?? ""
    currentDevice = device
    device.connect(delegate: self) { status in
      switch status {
      case .connected:
        result(nil)
      case .disconnected:
        result(FlutterError(code: "disconnected", message: "ESP device disconnected", details: nil))
      case .failedToConnect(let error):
        result(FlutterError(code: "connect_failed", message: error.description, details: nil))
      }
    }
  }

  private func searchSoftApDevices(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let prefix = args?["prefix"] as? String ?? "PROV_"
    let name = args?["name"] as? String ?? prefix
    result([[
      "name": name,
      "serviceUuid": "",
      "rssi": 0
    ]])
  }

  private func connectSoftApDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let name = args?["name"] as? String else {
      result(FlutterError(code: "device_not_found", message: "SoftAP device name is required", details: nil))
      return
    }
    pendingProofOfPossession = args?["proofOfPossession"] as? String ?? ""
    let password = args?["password"] as? String ?? ""
    let securityValue = args?["security"] as? Int ?? 1
    let security: ESPSecurity = securityValue == 0 ? .unsecure : .secure
    ESPProvisionManager.shared.createESPDevice(
      deviceName: name,
      transport: .softap,
      security: security,
      proofOfPossession: pendingProofOfPossession,
      softAPPassword: password
    ) { [weak self] device, error in
      if let error {
        result(FlutterError(code: "softap_create_failed", message: error.description, details: nil))
        return
      }
      guard let self, let device else {
        result(FlutterError(code: "softap_create_failed", message: "SoftAP device could not be created", details: nil))
        return
      }
      self.currentDevice = device
      device.connect(delegate: self) { status in
        switch status {
        case .connected:
          result(nil)
        case .disconnected:
          result(FlutterError(code: "disconnected", message: "ESP SoftAP device disconnected", details: nil))
        case .failedToConnect(let error):
          result(FlutterError(code: "connect_failed", message: error.description, details: nil))
        }
      }
    }
  }

  private func scanWifiNetworks(result: @escaping FlutterResult) {
    guard let currentDevice else {
      result(FlutterError(code: "not_connected", message: "Connect an ESP device first", details: nil))
      return
    }
    currentDevice.scanWifiList { networks, error in
      if let error {
        result(FlutterError(code: "wifi_scan_failed", message: error.description, details: nil))
        return
      }
      let payload = (networks ?? []).map { network -> [String: Any] in
        [
          "ssid": network.ssid,
          "rssi": Int(network.rssi),
          "channel": Int(network.channel),
          "security": network.auth.rawValue
        ]
      }
      result(payload)
    }
  }

  private func provisionWifi(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let currentDevice else {
      result(FlutterError(code: "not_connected", message: "Connect an ESP device first", details: nil))
      return
    }
    let args = call.arguments as? [String: Any]
    let ssid = args?["ssid"] as? String ?? ""
    let password = args?["password"] as? String ?? ""
    currentDevice.provision(ssid: ssid, passPhrase: password) { status in
      switch status {
      case .success:
        result(nil)
      case .configApplied:
        break
      case .failure(let error):
        result(FlutterError(code: "provision_failed", message: error.description, details: nil))
      }
    }
  }
}
