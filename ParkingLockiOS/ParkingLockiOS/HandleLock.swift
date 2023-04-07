//
//  HandleLock.swift
//  ParkingLockiOS
//
//  Created by Rilwanul Huda on 05/04/23.
//

import Foundation

public protocol HandleLockDelegate: AnyObject {
    func lockDidTurnDown()
    func lockDidTurnUp()
    func didUpdateBluetoothState(isOn: Bool)
    func bluetoothIsUnauthorized()
    func didConnectParkingLock()
}

open class HandleLock {
    public static let sharedInstance = HandleLock()
    
    open weak var delegate: HandleLockDelegate?
    
    private var didFailCheckInOutRequest: Bool = false
    private var secretKey: String = ""
    private var bluetoothManager: BLEClassManager?
    private var lockAction: LockActionHex?
    private var advertiseData: String?
    private var parkingLockType: String = ""
    
    init() {}
    
    /// Indicates that your Parking Lock is connected with your device
    open var isLockConnected: Bool {
        bluetoothManager?.isConnected ?? false
    }
    
    func initBluetoothManger() {
        bluetoothManager = BLEClassManager()
        bluetoothManager?.delegate = self
    }
    
    /// Deinit BLE usage:
    /// Put this method in your viewDidDisappear
    /// And every time when you have done using Parking Lock
    open func deinitBluetoothManager() {
        bluetoothManager?.stopScanning()
        bluetoothManager?.cleanUp()
        bluetoothManager = nil
    }
    
    /// Use this function whenever your app is entering the background mode
    open func didEnterBackgroundMode() {
        bluetoothManager?.scanningDidEnterBackground()
        bluetoothManager?.shouldDelayScanning = true
    }
    
    
    /// This function will allows you to read the Parking Lock and connect to it
    ///  And if its connected you can tell the Parking Lock to *Turn Up* or *Turn Down*
    ///  
    /// - Parameters:
    ///   - deviceId: deviceId is your Parking Lock deviceId and deviceId is required params
    ///   deviceId value should be "AB:CD:EF:GH:IJ:KL"
    ///   - lockType: lockType means that your Parking Lock is type 1 or type 2
    ///   set this value as "V1" or "V2"
    ///   - secretKey: secretKey is your Parking Lock deviceKey
    ///   secretKey is only *required* for Parking Lock type 2 or you can set this value as *nil* or ""
    open func checkParkingLockType(deviceId: String?, lockType: String, secretKey: String?) {
        guard let macAddress = deviceId else {
            TRACER("Invalid Parking Lock Device ID")
            return
        }
        
        if macAddress.isValidMacAddress() {
            if lockType == "V2" {
                advertiseData = "DN\(macAddress.replacingOccurrences(of: ":", with: ""))"
            } else {
                advertiseData = macAddress.toAdvertiseData()
            }
            
            initBluetoothManger()
        } else {
            TRACER("Invalid Lock Device ID, please contact our attendants.")
        }
        
        parkingLockType = lockType
        self.secretKey = secretKey ?? ""
    }
    
    private func startScanning() {
        if bluetoothManager == nil {
            initBluetoothManger()
        }
        
        guard let data = advertiseData, data.count == 12 || data.count == 14 else {
            TRACER("Could Not Start Scanning Because Invalid Advertise Data")
            return
        }
        
        bluetoothManager?.startScanning(advertiseData: data)
    }
    
    /// This function will allows you to ask the Parking Lock to *Turn Up* or *Turn Down*
    /// - Parameter action: LockActionHex
    /// .turnLockDown(secretKey: String?) tell the Parking Lock to *Turn Down*
    /// .turnLockUp(secretKey: String?) tell the Parking Lock to *Turn Up*
    /// and for the secret key you can set its value as *nil* or "" if you are using Parking Lock type 1
    /// For Parking Lock type 2 secretKey is indispensable
    public func handleBluetoothParkingLock(action: LockActionHex) {
        if didFailCheckInOutRequest {
            didFailCheckInOutRequest = false
            
            switch action {
            case .turnLockDown:
                delegate?.lockDidTurnDown()
            case .turnLockUp:
                delegate?.lockDidTurnUp()
            default:
                break
            }
            
            TRACER("Resending Check In/Out request because previous one was failed.")
        } else {
            guard bluetoothManager?.isConnected == true else {
                TRACER("Lock Disconnected. Trying to handle lock, but lock is disconnected.\nRescanning Lock...")
                startScanning()
                return
            }
            
            lockAction = action
            bluetoothManager?.write(action: action, key: secretKey)
            
            TRACER("Bluetooth is Writing \(action)")
        }
    }
    
    private func TRACER(_ any: Any?) {
        #if DEBUG
        let trace = """
        Parking Lock Trace: \(any != nil ? any! : "nil")
        """
        print(trace)
        #endif
    }
}

extension HandleLock: BLEClassManagerDelegate {
    func didUpdateBluetoothState(isOn: Bool) {
        if isOn {
            startScanning()
        }
        
        delegate?.didUpdateBluetoothState(isOn: isOn)
    }
    
    func bluetoothIsUnauthorized() {
        TRACER("BLUETOOTH IS UNAUTHORIZED")
        delegate?.bluetoothIsUnauthorized()
    }
    
    func didConnectParkingLock() {
        TRACER("PARKING LOCK CONNECTED")
        delegate?.didConnectParkingLock()
    }
    
    func didDisconnectParkingLock(isBluetoothOn: Bool) {
        TRACER("BLUETOOTH DISCONNECTED")
        didUpdateBluetoothState(isOn: isBluetoothOn)
    }
    
    func didUpdateLockStatus(_ status: LockStatus) {
        switch status {
        case .down:
            guard lockAction == .turnLockDown(secretKey: secretKey) else { return }
            delegate?.lockDidTurnDown()
        case .up:
            guard lockAction == .turnLockUp(secretKey: secretKey) else { return }
            delegate?.lockDidTurnUp()
        }
        
        lockAction = nil
    }
    
    func didHandleLock(_ result: LockHandleResult?, _ result2: LockHandleResult2?) {
        let status = result2 == .unlocked ? "UNLOCKED" : "LOCKED"
        let secretKey = self.secretKey
        
        if parkingLockType == "V2" {
            switch result2 {
            case .unlocked:
                delegate?.lockDidTurnDown()
            case .locked:
                delegate?.lockDidTurnUp()
            default:
                TRACER("Unknown Lock Handle Result")
            }
        } else {
            switch result {
            case .unlocked:
                delegate?.lockDidTurnDown()
            case .locked:
                delegate?.lockDidTurnUp()
            default:
                TRACER("Unknown Lock Handle Result")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.TRACER("Verifying Lock Status")
            self.bluetoothManager?.write(action: .checkStatus(secretKey: secretKey),
                                         key: secretKey,
                                         lockStatus: status)
        }
    }
}
