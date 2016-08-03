//
//  Atom.swift
//  FileDataProcessing
//
//  Created by Paul Jones on 15/02/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation

// These classes break down an MP4 file created by iOS to inject 360° metadata

let CONTAINERTYPES = ["moov", "trak", "mdia", "meta", "minf", "stbl",  "udta", "mp4a"]

class Atom  {
    unowned let fileSource:MP4File
    weak var parent:Atom?
    
    let offset:UInt64
    let size:UInt64
    let dataOffset:UInt64
    let type:String
    let last:Bool
    let end:UInt64
    
    var children:[Atom]
    
    init!(fileSource:MP4File) {
        self.fileSource = fileSource
        self.parent = nil
        
        self.offset = 0
        self.type = "ROOT"
        self.last = true
        self.size = fileSource.eof
        self.end = fileSource.eof
        self.dataOffset = 0
        
        self.children = []
        
        self.children = Atom.atomsFromFile(fileSource, start: 0, end: fileSource.eof, parent: self)
        
    }
    
    init!(fileSource:MP4File, parent pa:Atom?) {
        self.fileSource = fileSource
        self.parent = pa
        
        self.offset = fileSource.openFile.offsetInFile
        
        
        let size32 = fileSource.openFile.readUInt32()!
        let type = fileSource.openFile.readString4()!
        
        self.type = type
        
        if size32 == 0 {
            self.last = true
            self.size = 0
            self.dataOffset = 8
            
        }
        else if size32 == 1 {
            let size64 = fileSource.openFile.readUInt64()!
            self.last = false
            self.size = size64
            self.dataOffset = 16
        }
        else {
            self.last = false
            self.size = UInt64(size32)
            self.dataOffset = 8
            
        }
        
        
        self.children = []
        
        self.end = self.offset + self.size
        
        if CONTAINERTYPES.contains(type) {
            self.children = Atom.atomsFromFile(fileSource, start: self.offset + self.dataOffset, end: self.end, parent: self)
        }
        
    }
    
    class func atomsFromFile(fileSource:MP4File, start:UInt64, end:UInt64, parent:Atom?) -> [Atom] {
        
        var rv = [Atom]()
        
        fileSource.openFile.seekToFileOffset(start)
        
        while true {
            
            let ptr = fileSource.openFile.offsetInFile
            
            let atom = Atom(fileSource: fileSource, parent: parent)
            rv.append(atom)
            
            if atom.last {
                return rv
            }
            
            fileSource.openFile.seekToFileOffset(ptr + atom.size)
            
            if fileSource.openFile.offsetInFile >= end {
                return rv
            }
        }
    }
    
    func findAtomsOfType(type seekType:String, recursive: Bool) -> [Atom] {
        var rv = [Atom]()
        for atom in children {
            if atom.type == seekType {
                rv.append(atom)
            }
            if recursive {
                rv += atom.findAtomsOfType(type: seekType, recursive: true)
            }
        }
        return rv
    }
    
}

extension Atom {
    
    func increaseSize(by inc:UInt64) {
        guard type != "ROOT" else { return }
        
        let ptr = fileSource.openFile.offsetInFile
        defer { fileSource.openFile.seekToFileOffset(ptr) }
        
        if dataOffset == 8 {
            // !!!: this will behave unpredicatably (probably crash) if the size of the atom goes from below 4Gb to above 4Gb
            // i.e. where 64 bits are needed to represent the size. This is relatively unlikely
            fileSource.openFile.seekToFileOffset(offset)
            fileSource.openFile.writeUInt32(UInt32(size + inc))
        }
        else {
            fileSource.openFile.seekToFileOffset(offset + 8)
            fileSource.openFile.writeUInt64(size + inc)
        }
        
        parent?.increaseSize(by: inc)
        
    }
    
}



extension Atom : CustomStringConvertible {
    
    var description:String { return indentedDescription() }
    
    func indentedDescription(indent:String = "") -> String {
        var rv = "\(indent)\(type) \t@+(\(offset - ( (parent?.offset) ?? 0 ))) \t[\(size)]"
        if last {
            rv += " \t[LAST]"
        }
        rv += "\n"
        for child in children {
            rv += "\(child.indentedDescription("\(indent)    "))"
        }
        
        return rv
        
    }
    
}


