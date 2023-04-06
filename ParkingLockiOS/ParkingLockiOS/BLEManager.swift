//
//  BLEManager.swift
//  ParkingLockiOS
//
//  Created by Rilwanul Huda on 05/04/23.
//

import CoreBluetooth

protocol BLEClassManagerDelegate: AnyObject {
    func didUpdateBluetoothState(isOn: Bool)
    func bluetoothIsUnauthorized()
    func didConnectParkingLock()
    func didDisconnectParkingLock(isBluetoothOn: Bool)
    func didUpdateLockStatus(_ status: LockStatus)
    func didHandleLock(_ result: LockHandleResult?, _ result2: LockHandleResult2?)
}

class BLEClassManager: NSObject {
    static let sharedInstance = BLEClassManager()
    
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var advertiseData: String?
    
    var shouldDelayScanning: Bool = false
    var isConnected: Bool = false
    
    private var lockAction: LockActionHex?
    private var secretKey: String = ""
    private var lockStatus: String = ""
    private var reWriteData: Data = Data()
    private var reWriteChar: CBCharacteristic?
    private var isLockHandled: Bool = false
    private var parkingLockType2: Bool = false
    private var isBluetoothActive: Bool = false
    private var processIsNotCompleted: Bool = true
    weak var delegate: BLEClassManagerDelegate?
    
    override init() {
        super.init()
        let options = [CBCentralManagerOptionShowPowerAlertKey: false]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
    
    deinit {
        //
        TRACER("BLEManager has been deinitialized")
    }
    
    func startScanning(advertiseData: String) {
        guard isBluetoothActive else {
            TRACER("PLEASE TURN ON YOUR BLUETOOTH")
            return
        }
        
        if isConnected {
            delegate?.didConnectParkingLock()
        } else {
            self.advertiseData = advertiseData
            scanForPeripherals()
        }
    }
    
    private func scanForPeripherals() {
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        
        if shouldDelayScanning {
            shouldDelayScanning = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                self.centralManager?.scanForPeripherals(withServices: nil, options: options)
            }
        } else {
            centralManager?.scanForPeripherals(withServices: nil, options: options)
        }
    }
    
    func scanningDidEnterBackground() {
        TRACER("BLE ENTER BACKGROUND MODE")
        
        if processIsNotCompleted, parkingLockType2 {
            guard let char = reWriteChar else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.peripheral?.writeValue(self.reWriteData, for: char, type: .withResponse)
            }
            return
        }
        
        shouldDelayScanning = true
        print("BLEManager Logging: BLE will delaying scanning because in iOS 14 or above, if the app enter background mode and then enter the foreground mode, centralManager?.scanForPeripherals couldn't start its job immediately. It will need some delay. In this case we added 1.4 seconds")
    }
    
    func stopScanning() {
        guard isBluetoothActive else { return }
        centralManager?.stopScan()
    }
    
    func write(action: LockActionHex, key: String, lockStatus: String = "") {
        guard let data = !parkingLockType2 ? action.parkingLockType1.hexadecimal : action.parkingLockType2.hexadecimal else {
            TRACER("Could not send command. Description: hexadecimal not found, Lock Action: \(action)")
            return
        }

        guard let characteristic = characteristic else {
            TRACER("Could not send command. Description: characteristic not found, Lock Action: \(action)")
            return
        }

        lockAction = action
        secretKey = key
        self.lockStatus = lockStatus
        reWriteData = data
        reWriteChar = characteristic
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func cleanUp() {
        guard let peripheral = peripheral, let characteristic = characteristic else { return }
        peripheral.setNotifyValue(false, for: characteristic)
        centralManager?.cancelPeripheralConnection(peripheral)
        isConnected = false
    }
}

extension BLEClassManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothActive = central.state == .poweredOn
        
        if central.state == .unauthorized {
            delegate?.bluetoothIsUnauthorized()
        }
        
        delegate?.didUpdateBluetoothState(isOn: isBluetoothActive)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        TRACER("Description: Scanning Started.\nTask: Did Discover Peripheral")
        
        let manufactureData = advertisementData["kCBAdvDataManufacturerData"]
        let macAddressName = advertisementData["kCBAdvDataLocalName"] as? String
        var manufactureDataRaw = String(describing: manufactureData.debugDescription)

        if manufactureDataRaw != "nil" {
            manufactureDataRaw = String(manufactureDataRaw.split(separator: "<")[1])
        }

        manufactureDataRaw.removeAll { (char) -> Bool in
            if char == " " || char == ">" || char == "(" || char == ")" {
                return true
            }
            return false
        }

        if let advertiseId = advertiseData, advertiseId == manufactureDataRaw || advertiseId == macAddressName {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            central.connect(peripheral, options: nil)
            TRACER("PARKING LOCK FOUND\nDescription: User device found the parking lock.\nAdvertise Data: \(advertiseId)\nRSSI: \(RSSI)\nNext Step: Connecting to parking lock")
        } else {
            TRACER("Scanning lock with advertiseData: \(advertiseData ?? "")")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        stopScanning()
        self.peripheral?.discoverServices(nil)
        delegate?.didConnectParkingLock()
        TRACER("didConnect peripheral with peripheral: \(peripheral)")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            TRACER("Lock Disconnected with Error:\nError: \(error.localizedDescription)\nPeripheral: \(peripheral.description)\nTask: didDisconnectPeripheral")
        }
        
        TRACER("Lock Disconnected: \nDescription: Peripheral Disconnected\nPeripheral: \(peripheral.description)\nTask: didDisconnectPeripheral")
        
        cleanUp()
        if !isLockHandled {
            delegate?.didDisconnectParkingLock(isBluetoothOn: isBluetoothActive)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        TRACER("FAILED TO CONNECTING PARKING LOCK\nDescription: \(error?.localizedDescription ?? "null error")\nPeripheral: \(peripheral.description)\nTask: didFailToConnect")
    }
}

extension BLEClassManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            TRACER("Characteristic Update Error\nError: \(error.localizedDescription)\nPeripheral: \(peripheral.description)\nCharacteristic: \(characteristic.description)\nTask: didUpdateValueFor characteristic")
        }
        
        let resultHex = characteristic.value?.hexEncodedString() ?? ""
        var start = resultHex.index(resultHex.startIndex, offsetBy: 10)
        var end = resultHex.index(resultHex.startIndex, offsetBy: 14)

        if parkingLockType2 {
            start = resultHex.index(resultHex.startIndex, offsetBy: 12)
            end = resultHex.index(resultHex.startIndex, offsetBy: resultHex.count - 22)
        }

        let range = start ..< end
        let status = resultHex[range]

        let trace = """
        ~ \(peripheral) didUpdateValueFor ~
        characteristic: \(characteristic)
        resultHex: \(resultHex)
        status: \(status)
        """
        TRACER(trace)

        guard let action = lockAction else {
            TRACER("BLE TRACE:\nDescription: Tracing Unknown Lock Hex\nLock Action: \(String(describing: lockAction))\nResult Hex: \(resultHex)\nStatus Code: \(String(status))")
            return
        }

        if action == .checkStatus(secretKey: secretKey) {
            if parkingLockType2 {
                if isLockHandled, let statusHex = Int(status) {
                    isLockHandled = false

                    var status: LockStatus

                    if !parkingLockType2 {
                        status = statusHex % 2 == 0 ? .down : .up
                    } else {
                        status = lockStatus == "UNLOCKED" ? .down : .up
                    }

                    delegate?.didUpdateLockStatus(status)
                    processIsNotCompleted = false
                } else if isLockHandled, LockHandleResult2(rawValue: String(status)) != nil {
                    TRACER("BLE Unexpected Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                } else {
                    TRACER("BLE Unknown Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                }
            } else {
                if isLockHandled, let statusHex = Int(status) {
                    isLockHandled = false

                    let status: LockStatus = statusHex % 2 == 0 ? .down : .up
                    delegate?.didUpdateLockStatus(status)
                    processIsNotCompleted = false
                } else if isLockHandled, LockHandleResult(rawValue: String(status)) != nil {
                    TRACER("BLE Unexpected Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                } else {
                    TRACER("BLE Unknown Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                }
            }
        }

        if action == .turnLockDown(secretKey: secretKey) || action == .turnLockUp(secretKey: secretKey) {
            isLockHandled = true

            if parkingLockType2 {
                if let result2 = LockHandleResult2(rawValue: String(status)) {
                    delegate?.didHandleLock(nil, result2)
                    processIsNotCompleted = false
                } else if Int(status) != nil {
                    TRACER("BLE Unexpected Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                } else {
                    TRACER("BLE Unknown Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                }
            } else {
                if let result = LockHandleResult(rawValue: String(status)) {
                    delegate?.didHandleLock(result, nil)
                    processIsNotCompleted = false
                } else if Int(status) != nil {
                    TRACER("BLE Unexpected Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                } else {
                    TRACER("BLE Unknown Lock Hex\nLock Action: \(action)\nResult Hex: \(resultHex)\nStatus Code: \(status)")
                    processIsNotCompleted = false
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            TRACER("Discover Characteristics Error\nError: \(error.localizedDescription)\nPeripheral: \(peripheral.description)\nTask: didDiscoverCharacteristicsFor service")
        }
        
        TRACER("Discover Peripheral Characteristics\nError: \(error?.localizedDescription ?? "null")\nPeripheral: \(peripheral.description)\nTask: didDiscoverCharacteristicsFor service")
        
        guard let services = peripheral.services else {
            TRACER("didDiscoverCharacteristicsFor service could not find any services. line 283")
            return
        }
        
        for service in services {
            if service.uuid.uuidString == "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" {
                parkingLockType2 = true
            }
        }
        
        guard let serviceCharacteristics = service.characteristics, serviceCharacteristics.count > 0 else {
            TRACER("Error when getting service.characteristics line 294")
            return
        }
        
        for characteristic in serviceCharacteristics {
            if parkingLockType2 {
                if characteristic.uuid.description == "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                
                if characteristic.uuid.description == "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" {
                    self.characteristic = characteristic
                }
            } else {
                if characteristic.uuid.description == "FFF1" {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                
                if characteristic.uuid.description == "FFF2" {
                    self.characteristic = characteristic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            TRACER("Discover Services Error\nError: \(error.localizedDescription)\nPeripheral: \(peripheral.description)\nTask: didDiscoverServices")
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            TRACER("Error Write Value for Characteristic\nError: \(error.localizedDescription)\nPeripheral: \(peripheral.description)\nCharacteristic: \(characteristic.description)\nTask: didWriteValueFor characteristic")
        }
        
        if let action = lockAction {
            TRACER("Success Write Value for Characteristic\nCharacteristic: \(characteristic.description)\nPeripheral: \(peripheral.description)\nLock Action: \(action)\nTask: didWriteValueFor characteristic")
        }
    }
}

