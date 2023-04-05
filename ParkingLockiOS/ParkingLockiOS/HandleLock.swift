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
    weak open var delegate: HandleLockDelegate?
    open var didFailCheckInOutRequest: Bool = false
    
    private var secretKey: String = ""
    private var bluetoothManager: BLEClassManager?
    private var lockAction: LockActionHex?
    private var advertiseData: String?
    private var parkingLockType: String = ""
    
    open class func sharedInstance() -> HandleLock {
        HandleLock()
    }
    
    open var isLockConnected: Bool {
        bluetoothManager?.isConnected ?? false
    }
    
    open func initBluetoothManger() {
        bluetoothManager = BLEClassManager()
        bluetoothManager?.delegate = self
    }
    
    open func deinitBluetoothManager() {
        bluetoothManager?.stopScanning()
        bluetoothManager?.cleanUp()
        bluetoothManager = nil
    }
    
    open func didEnterBackgroundMode() {
        bluetoothManager?.scanningDidEnterBackground()
    }
    
    open func shouldDelayingScanning(_ flag: Bool) {
        bluetoothManager?.shouldDelayScanning = flag
    }
    
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
            TRACER("Verifying Lock Status")
            self.bluetoothManager?.write(action: .checkStatus(secretKey: secretKey),
                                         key: secretKey,
                                         lockStatus: status)
        }
    }
}
