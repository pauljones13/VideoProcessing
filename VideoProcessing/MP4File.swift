//
//  MP4File.swift
//  FileDataProcessing
//
//  Created by Paul Jones on 15/02/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation


// These classes break down an MP4 file created by iOS to inject 360° metadata
class MP4File {
    let fileURL:NSURL
    let openFile:NSFileHandle
    
    private (set) var rootAtom:Atom!
    private (set) var eof:UInt64 = 0
    
    init(fileURL url:NSURL) {
        self.fileURL = url
        self.openFile = try! NSFileHandle(forUpdatingURL: fileURL)
        
        self.reloadAtoms()
    }
    deinit {
        openFile.closeFile()
    }
    
    func reloadAtoms() {
        let ptr = self.openFile.offsetInFile
        defer { openFile.seekToFileOffset(ptr) }
        
        self.openFile.seekToEndOfFile()
        
        eof = self.openFile.offsetInFile
        self.rootAtom = Atom(fileSource: self)
        
    }
    
    func findAtomsOfType(type seekType:String, recursive: Bool) -> [Atom] {
        return self.rootAtom.findAtomsOfType(type: seekType, recursive: recursive)
    }
    
    
}

extension MP4File : CustomStringConvertible {
    var description:String { return "File: \(fileURL)\n\(rootAtom)" }
}

extension MP4File {
    func insertAtom(after: Atom, size:UInt64) {
        insertAtom(after, atomType: "free", data: NSMutableData(length: Int(size))!)
    }
    func insertAtom(after: Atom, atomType:String, data:NSData) {
        guard after.parent != nil else { return }
        
        let ptr = openFile.offsetInFile
        defer { openFile.seekToFileOffset(ptr) }
        
        let positionInFile = after.end
        let atomSize = UInt64(data.length + 8)
        
        
        openFile.seekToFileOffset(positionInFile)
        let buffer = openFile.readDataToEndOfFile()
        
        openFile.seekToFileOffset(positionInFile)
        
        if atomSize <= UInt64(UINT32_MAX) {
            openFile.writeUInt32(UInt32(atomSize))
            openFile.writeString4(atomType)
            
        }
        else {
            openFile.writeUInt32(1)
            openFile.writeString4(atomType)
            openFile.writeUInt64(atomSize)
        }
        
        openFile.writeData(data)
        
        openFile.writeData(buffer)
        
        after.parent?.increaseSize(by: atomSize)
        
        reloadAtoms()
        
    }
    
}
