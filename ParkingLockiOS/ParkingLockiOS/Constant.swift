//
//  Constant.swift
//  ParkingLockiOS
//
//  Created by Rilwanul Huda on 05/04/23.
//

import Foundation

public enum LockHandleResult: String {
    case unlocked = "019e"
    case locked = "01ae"
}

public enum LockHandleResult2: String {
    case unlocked = "140101"
    case locked = "140102"
}

public enum LockStatus {
    case down
    case up
}

public enum LockActionHex: Equatable {
    case checkStatus(secretKey: String)
    case turnLockDown(secretKey: String)
    case turnLockUp(secretKey: String)
    case reset
    
    var parkingLockType1: String {
        switch self {
        case .checkStatus:
            return "0103100C000480CA"
        case .turnLockDown:
            return "01106008000102000106DE"
        case .turnLockUp:
            return "0110600700010200010621"
        case .reset:
            return "01106005000102000107C3"
        }
    }
    
    var parkingLockType2: String {
        switch self {
        case .checkStatus(let key):
            return "4444544314FF140201" + key + "45B80A"
        case .turnLockDown(let key):
            return "4444544314FF140101" + key + "45B80A"
        case .turnLockUp(let key):
            return "4444544314FF140102" + key + "45B80A"
        default:
            return ""
        }
    }
}

public func TRACER(_ any: Any?) {
    #if DEBUG
    let trace = """
    Parking Lock Trace: \(any != nil ? any! : "nil")
    """
    print(trace)
    #endif
}
