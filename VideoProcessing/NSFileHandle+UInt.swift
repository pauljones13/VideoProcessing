//
//  NSFileHandle+UInt.swift
//  FileDataProcessing
//
//  Created by Paul Jones on 15/02/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation

// These classes break down an MP4 file created by iOS to inject 360° metadata
extension NSFileHandle {
    func readUInt32() -> UInt32? {
        let data = self.readDataOfLength(4)
        guard data.length == 4 else { return nil }
        return CFSwapInt32HostToBig(UnsafePointer<UInt32>(data.bytes).memory)
    }
    func readUInt64() -> UInt64? {
        let data = self.readDataOfLength(8)
        guard data.length == 8 else { return nil }
        return CFSwapInt64HostToBig(UnsafePointer<UInt64>(data.bytes).memory)
    }
    func readString4() -> String? {
        let data = self.readDataOfLength(4)
        guard data.length == 4 else { return nil }
        guard let type = String(data: data, encoding: NSASCIIStringEncoding) else { return nil }
        return type
    }
    
    func writeUInt32(value:UInt32) {
        guard let data = NSMutableData(length: 4) else { return }
        UnsafeMutablePointer<UInt32>(data.bytes).memory = CFSwapInt32BigToHost(UInt32(value))
        writeData(data)
    }
    func writeUInt64(value:UInt64) {
        guard let data = NSMutableData(length: 8) else { return }
        UnsafeMutablePointer<UInt64>(data.bytes).memory = CFSwapInt64BigToHost(UInt64(value))
        writeData(data)
    }
    func writeString4(type:String) {
        guard let data = type.dataUsingEncoding(NSASCIIStringEncoding) where data.length == 4 else { return }
        writeData(data)
    }
}

