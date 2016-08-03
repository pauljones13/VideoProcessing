//
//  BPCIVideoConverter.swift
//  BubblePix
//
//  Created by Paul Jones on 09/06/2016.
//  Copyright © 2016 Fluid Pixel. All rights reserved.
//

// The video converter class. It should keep track of ongoing conversions and queue them.
// If a conversion is in progress when one is requested, it will return the existing conversion

// Original version used a modified version of Apple's AAPLAVReaderWriter code
// iOS 9 and higher version here uses AVMutableVideoComposition


import Foundation
import CoreImage
import AVFoundation
import AVKit
import CoreLocation
import Photos

let VIDEO_ALIGNMENT:CGFloat = 0.58

typealias ProgressBlock = (Double) -> Void

@objc
class BPCIVideoConverter: NSObject {
    
    
    // MARK: Statics
    static var conversionQueue: [BPCIVideoConverter] = []
    
    static let videoDownloadWiFiSession:NSURLSession = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.allowsCellularAccess = false
        return NSURLSession(configuration: configuration)
    }()
    
    // Factory method. Creates a new converter object for the given asset and adds it to the queue
    static func process(ph_asset: PHAsset, u: CGFloat, v: CGFloat, minD: CGFloat, maxD: CGFloat) -> BPCIVideoConverter? {
        for existingConversion in conversionQueue {
            if existingConversion.photoLibAsset.localIdentifier == ph_asset.localIdentifier {
                return existingConversion
            }
        }
        guard let newConversion = BPCIVideoConverter(ph_asset: ph_asset, u: u, v: v, minD: minD, maxD: maxD) else { return nil }
        
        conversionQueue.append(newConversion)
        
        return newConversion
        
    }
    
    
    // MARK: Instance
    
    var downloadProgress:ProgressBlock?
    var processProgress:ProgressBlock?
    
    
    let photoLibAsset: PHAsset
    
    let filter = CIFilter(name: "BPScopeFilter")!
    let context = CIContext(options: nil)
    
    let centralise: CGAffineTransform
    
    let targetURL: NSURL
    let exportPreset: String
    let outputSize: CGSize
    
    private var downloadTask: PHImageRequestID = PHInvalidImageRequestID
    
    private init?(ph_asset: PHAsset, u: CGFloat, v: CGFloat, minD: CGFloat, maxD: CGFloat) {
        
        guard ph_asset.mediaType == .Video else { return nil }
        
        self.photoLibAsset = ph_asset
        
        self.targetURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).URLByAppendingPathComponent(NSUUID().UUIDString).URLByAppendingPathExtension("MP4")
        
        // Use the best supported output session available
        if AVAssetExportSession.allExportPresets().contains(AVAssetExportPreset3840x2160)  {
            self.exportPreset = AVAssetExportPreset3840x2160
            self.outputSize = CGSize(width: 3840, height: 2160)
        }
        else if AVAssetExportSession.allExportPresets().contains(AVAssetExportPreset1920x1080) {
            self.exportPreset = AVAssetExportPreset1920x1080
            self.outputSize = CGSize(width: 1920, height: 1080)
            
        }
        else if AVAssetExportSession.allExportPresets().contains(AVAssetExportPreset1280x720) {
            self.exportPreset = AVAssetExportPreset1280x720
            self.outputSize = CGSize(width: 1280, height: 720)
        }
        else {
            return nil
        }
        
        filter.setDefaults()
        filter.setValue(outputSize.width,  forKey: "inputOutputWidth")
        filter.setValue(u, forKey: "inputScopeCalibrationU")
        filter.setValue(v, forKey: "inputScopeCalibrationV")
        filter.setValue(minD * 0.8, forKey: "inputMinDiameter")
        filter.setValue(maxD * 1.05, forKey: "inputMaxDiameter")
        filter.setValue(0.0,  forKey: "inputDiameterOffsetAdjustment")
        
        let vScale = CGFloat(1.312)                     // Scale to correct video aspect ratio
        let hScale = 0.5 * CGFloat(M_1_PI) * vScale
        
        self.centralise = CGAffineTransformTranslate(CGAffineTransformMakeScale(1.0, vScale), 0.0, 0.5 * (outputSize.height - outputSize.width * hScale))
        
    }

    @objc(convertWithCompletion:)
    func convert(completion: (NSURL?, NSError?) -> Void) {
        
        if NSFileManager.defaultManager().fileExistsAtPath(self.targetURL.path!) {
            dispatch_async(dispatch_get_main_queue()) { completion(self.targetURL, nil) }
            return
        }
        
        
        let options = PHVideoRequestOptions()
        options.networkAccessAllowed = true
        options.progressHandler = {
            (progress: Double, error: NSError?, stop: UnsafeMutablePointer<ObjCBool>, info: [NSObject : AnyObject]?) -> Void in
            self.downloadProgress?(progress)
        }
        
        PHImageManager.defaultManager().requestAVAssetForVideo(self.photoLibAsset, options: options) {
            assetObj, _, info in
            
            guard let sourceAsset = assetObj else {
                if let _ = info?[PHImageResultIsInCloudKey] {
                    self.downloadProgress?(0.0)
                    return
                }
                completion(nil, nil) // error in info
                return
            }
            
            
            
            let composition: AVMutableVideoComposition
            
            composition = AVMutableVideoComposition(asset: sourceAsset) {
                request in
                
                self.filter.setValue(request.sourceImage, forKey: kCIInputImageKey)
                
                guard let outputImage = self.filter.outputImage?.imageByApplyingTransform(self.centralise) else {
                    
                    let clearRect = CIImage(color: CIColor(color: UIColor.clearColor())).imageByCroppingToRect(CGRect(origin: CGPointZero, size: request.renderSize))
                    
                    request.finishWithImage(clearRect, context: self.context)
                    return
                }
                
                request.finishWithImage(outputImage, context: self.context)
                
            }
            
            
            
            
            let tempURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).URLByAppendingPathComponent("\(NSUUID().UUIDString).MP4")
            
            composition.renderSize = self.outputSize
            
            guard let exportSession = AVAssetExportSession(asset: sourceAsset, presetName: self.exportPreset ) else { //
                // TODO: Error
                completion(nil, nil)
                return
            }
            
            var timer = NSTimer()
            dispatch_async(dispatch_get_main_queue()) {
                timer = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: #selector(BPCIVideoConverter.timer(_:)), userInfo: exportSession, repeats: true)
            }
            
            exportSession.videoComposition = composition
            exportSession.outputURL = tempURL
            exportSession.outputFileType = AVFileTypeMPEG4
            
            exportSession.metadata = sourceAsset.metadata

            exportSession.exportAsynchronouslyWithCompletionHandler {
                timer.invalidate()
                
                if let error = exportSession.error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(nil, error)
                        if let index = BPCIVideoConverter.conversionQueue.indexOf(self) {
                            BPCIVideoConverter.conversionQueue.removeAtIndex(index)
                        }
                    }
                    return
                }
                
                MetadataInjector.injectMetadata(tempURL)
                
                do {
                    if NSFileManager.defaultManager().fileExistsAtPath(self.targetURL.path!) {
                        try NSFileManager.defaultManager().removeItemAtURL(self.targetURL)
                    }
                    try NSFileManager.defaultManager().moveItemAtURL(tempURL, toURL: self.targetURL)
                }
                catch let fileError as NSError {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(nil, fileError)
                        if let index = BPCIVideoConverter.conversionQueue.indexOf(self) {
                            BPCIVideoConverter.conversionQueue.removeAtIndex(index)
                        }
                    }
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    completion(self.targetURL, nil)
                    if let index = BPCIVideoConverter.conversionQueue.indexOf(self) {
                        BPCIVideoConverter.conversionQueue.removeAtIndex(index)
                    }
                }
                
            }
            
            
        }
        



    }
    

    @objc private func timer(timer: NSTimer) {
        if let exportSession = timer.userInfo as? AVAssetExportSession {
            dispatch_async(dispatch_get_main_queue()) {
                self.processProgress?(Double(exportSession.progress))
            }
        }
    }
}






