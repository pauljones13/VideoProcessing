//
//  SphericalMetadataXML.swift
//  FileDataProcessing
//
//  Created by Paul Jones on 15/02/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation

// These classes break down an MP4 file created by iOS to inject 360° metadata


let headerData:[UInt8] = [0xff, 0xcc, 0x82, 0x63, 0xf8, 0x55, 0x4a, 0x93, 0x88, 0x14, 0x58, 0x7a, 0x02, 0x52, 0x1f, 0xdd] // 0x75, 0x75, 0x69, 0x64,

let xmlHeader = "<?xml version=\"1.0\"?><rdf:SphericalVideo\nxmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\nxmlns:GSpherical=\"http://ns.google.com/videos/1.0/spherical/\">"

let xmlContents = "<GSpherical:Spherical>true</GSpherical:Spherical>" +
    "<GSpherical:Stitched>false</GSpherical:Stitched>" +
    "<GSpherical:StitchingSoftware>BubblePix BubbleScope</GSpherical:StitchingSoftware>" +
"<GSpherical:ProjectionType>equirectangular</GSpherical:ProjectionType>"

let xmlContentsTopBottom = "<GSpherical:StereoMode>top-bottom</GSpherical:StereoMode>"

let xmlContentsLeftRight = "<GSpherical:StereoMode>left-right</GSpherical:StereoMode>"

let xmlFooter = "</rdf:SphericalVideo>"

func getXMLContentsCropFormat(cropped_width_pixels cropped_width_pixels:Int, cropped_height_pixels:Int, full_width_pixels:Int, full_height_pixels:Int, cropped_offset_left_pixels:Int, cropped_offset_top_pixels:Int) -> String {
    var rv = "<GSpherical:CroppedAreaImageWidthPixels>\(cropped_width_pixels)</GSpherical:CroppedAreaImageWidthPixels>"
    rv += "<GSpherical:CroppedAreaImageHeightPixels>\(cropped_height_pixels)</GSpherical:CroppedAreaImageHeightPixels>"
    rv += "<GSpherical:FullPanoWidthPixels>\(full_width_pixels)</GSpherical:FullPanoWidthPixels>"
    rv += "<GSpherical:FullPanoHeightPixels>\(full_height_pixels)</GSpherical:FullPanoHeightPixels>"
    rv += "<GSpherical:CroppedAreaLeftPixels>\(cropped_offset_left_pixels)</GSpherical:CroppedAreaLeftPixels>"
    rv += "<GSpherical:CroppedAreaTopPixels>\(cropped_offset_top_pixels)</GSpherical:CroppedAreaTopPixels>"
    
    return rv
}

func createMetaData() -> NSData {
    let xmlCrop = "" //getXMLContentsCropFormat(cropped_width_pixels: 0,cropped_height_pixels: 0,full_width_pixels: 0,full_height_pixels: 0,cropped_offset_left_pixels: 0,cropped_offset_top_pixels: 0)
    
    let xmlText = xmlHeader + xmlContents + xmlCrop + xmlFooter

    let xmlData = xmlText.dataUsingEncoding(NSUTF8StringEncoding)!
    
    let data = NSMutableData(bytes: UnsafePointer<Void>(headerData), length: headerData.count)
    data.appendData(xmlData)
    
    return data
    
}
