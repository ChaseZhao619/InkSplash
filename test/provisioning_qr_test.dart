import 'package:flutter_test/flutter_test.dart';
import 'package:ink_splash/models.dart';

void main() {
  test('parses BLE provisioning QR JSON', () {
    final payload = ProvisioningQrPayload.fromRaw(
      '{"ver":"v1","name":"PROV_C36AD8","transport":"ble","security":1,"pop":"abcd1234","device_id":"esp32_001","claim_code":"f095c9b448d55c929615763b09f54fef"}',
    );

    expect(payload.isBle, isTrue);
    expect(payload.deviceId, 'esp32_001');
    expect(payload.claimCode, 'f095c9b448d55c929615763b09f54fef');
  });

  test('parses SoftAP provisioning QR with data prefix', () {
    final payload = ProvisioningQrPayload.fromRaw(
      'data={"ver":"v1","name":"PROV_C36AD8","transport":"softap","security":0,"pop":"abcd1234","device_id":"esp32_001","claim_code":"f095c9b448d55c929615763b09f54fef","softap_password":"12345678"}',
    );

    expect(payload.isSoftAp, isTrue);
    expect(payload.security, 0);
    expect(payload.name, 'PROV_C36AD8');
    expect(payload.softApPassword, '12345678');
  });

  test('rejects unsupported provisioning transport', () {
    expect(
      () => ProvisioningQrPayload.fromRaw(
        '{"ver":"v1","name":"PROV_C36AD8","transport":"wifi","security":1,"pop":"abcd1234","device_id":"esp32_001","claim_code":"f095c9b448d55c929615763b09f54fef"}',
      ),
      throwsFormatException,
    );
  });
}
