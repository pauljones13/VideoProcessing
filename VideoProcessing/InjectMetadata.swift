//
//  InjectMetadata.swift
//  FileDataProcessing
//
//  Created by Paul Jones on 15/02/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation


// These classes break down an MP4 file created by iOS to inject 360° metadata
@objc
public class MetadataInjector : NSObject {
    @objc
    public class func injectMetadata(fileURL: NSURL) {
        
        let fileObject:MP4File = MP4File(fileURL: fileURL)
        
        if fileObject.findAtomsOfType(type: "uuid", recursive: true).count == 0 {
            if let moov = fileObject.findAtomsOfType(type: "moov", recursive: false).last,
                let position = moov.findAtomsOfType(type: "trak", recursive: false).last?.children.last {
                    fileObject.insertAtom(position, atomType: "uuid", data: createMetaData())
            }
        }
        
    }
}


