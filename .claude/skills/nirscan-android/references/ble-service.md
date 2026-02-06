# NanoBLEService Patterns

BLE communication patterns from NanoBLEService.java.

## Broadcast Actions (Service → Activity)

### Scan Operations
```java
ACTION_SCAN_STARTED = "com.kstechnologies.NanoScan.ACTION_SCAN_STARTED"
ACTION_NEW_SCAN_DATA = "com.kstechnologies.NanoScan.ACTION_NEW_SCAN_DATA"
```

### Device Information
```java
ACTION_INFO = "com.kstechnologies.NanoScan.ACTION_INFO"
ACTION_STATUS = "com.kstechnologies.NanoScan.ACTION_STATUS"
ACTION_NOTIF_DONE = "com.kstechnologies.NanoScan.ACTION_NOTIF_DONE"
```

### Calibration
```java
ACTION_REF_CAL_DATA = "com.kstechnologies.NanoScan.ACTION_REF_CAL_DATA"
```

### Configuration
```java
ACTION_SCAN_CONF = "com.kstechnologies.NanoScan.ACTION_SCAN_CONF"
ACTION_ACTIVE_CONF_INDEX = "com.kstechnologies.NanoScan.ACTION_ACTIVE_CONF_INDEX"
ACTION_STORED_SCAN = "com.kstechnologies.NanoScan.ACTION_STORED_SCAN"
```

## Broadcast Receivers (Activity → Service)

### Command Pattern
```java
// Generic command send
SEND_COMMAND = "com.kstechnologies.NanoScan.SEND_COMMAND"
EXTRA_COMMAND = "com.kstechnologies.NanoScan.EXTRA_COMMAND"
EXTRA_CHARACTERISTIC_UUID = "com.kstechnologies.NanoScan.EXTRA_CHARACTERISTIC_UUID"
```

### Specific Commands
```java
SET_TIME = "com.kstechnologies.NanoScan.SET_TIME"
START_SCAN = "com.kstechnologies.NanoScan.START_SCAN"
REQUEST_CAL_COEFF = "com.kstechnologies.NanoScan.REQUEST_CAL_COEFF"
REQUEST_CAL_MATRIX = "com.kstechnologies.NanoScan.REQUEST_CAL_MATRIX"
REQUEST_SCAN_CONF = "com.kstechnologies.NanoScan.REQUEST_SCAN_CONF"
REQUEST_ACTIVE_CONF = "com.kstechnologies.NanoScan.REQUEST_ACTIVE_CONF"
REQUEST_STORED_SCANS = "com.kstechnologies.NanoScan.REQUEST_STORED_SCANS"
```

## Usage Patterns

### Sending a Command
```java
// From Activity
Intent intent = new Intent(KSTNanoSDK.START_SCAN);
LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
```

### Receiving Results
```java
// Register receiver in Activity
IntentFilter filter = new IntentFilter(KSTNanoSDK.ACTION_NEW_SCAN_DATA);
LocalBroadcastManager.getInstance(this).registerReceiver(dataReceiver, filter);

// Handle in receiver
private BroadcastReceiver dataReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
        byte[] data = intent.getByteArrayExtra(KSTNanoSDK.EXTRA_DATA);
        // Process data
    }
};
```

## Multi-Packet Assembly

Large data (calibration, scan results) arrives in multiple BLE packets:

```java
// NanoBLEService.java pattern
private byte[] refCoeffBuffer;
private int refCoeffSize;

void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
    byte[] data = characteristic.getValue();
    
    if (characteristic.getUuid().equals(RET_REF_CAL_COEFF)) {
        if (data[0] == 0x00) {
            // Header packet: [0x00, sizeLow, sizeHigh]
            refCoeffSize = (data[2] << 8) | (data[1] & 0xFF);
            refCoeffBuffer = new byte[refCoeffSize];
        } else {
            // Data packet: [packetIndex, ...payload]
            int packetIndex = data[0];
            int offset = (packetIndex - 1) * 19;  // 20-byte MTU, 1 byte for index
            System.arraycopy(data, 1, refCoeffBuffer, offset, data.length - 1);
            
            // Check if complete
            if (offset + data.length - 1 >= refCoeffSize) {
                // Broadcast complete data
                Intent intent = new Intent(ACTION_REF_CAL_DATA);
                intent.putExtra(EXTRA_REF_CAL_COEFF, refCoeffBuffer);
                LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
            }
        }
    }
}
```

## Characteristic Write Patterns

### Simple Write
```java
characteristic.setValue(new byte[]{0x00});
gatt.writeCharacteristic(characteristic);
```

### Write with Response Check
```java
// In onCharacteristicWrite callback
if (status == BluetoothGatt.GATT_SUCCESS) {
    // Write succeeded
} else {
    // Handle error
}
```

### Enable Notifications
```java
// Must set both local and remote (CCCD)
gatt.setCharacteristicNotification(characteristic, true);

BluetoothGattDescriptor descriptor = characteristic.getDescriptor(CCCD_UUID);
descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
gatt.writeDescriptor(descriptor);
```

## Scan Workflow

1. **Setup notifications** for scan result characteristics
2. **Request device info** via GGIS
3. **Request calibration** via GCIS (coefficients + matrix)
4. **Set/verify active config** via GSCIS
5. **Start scan** via GSDIS (write 0x00)
6. **Wait for scan status** (notify on START_SCAN characteristic)
7. **Receive scan data** (multi-packet on SCAN_DATA)
8. **Process results** using calibration data

## Error Handling

```java
// Scan status codes from START_SCAN notify
0xFF = SCAN_SUCCESS
0x00 = SCAN_IN_PROGRESS
0x01 = SCAN_LAMP_FAILURE
0x02 = SCAN_TIMEOUT
0x03 = SCAN_CONFIG_ERROR

// Device error flags from ERROR_STATUS
0x80 = TMP006_ERROR (temperature sensor)
0x08 = EEPROM_ERROR
0x04 = SPEC_LIB_ERROR
```
