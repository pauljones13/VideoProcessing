//
//  VideoConverterViewController.swift
//  VideoProcessing
//
//  Created by Paul Jones on 02/08/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit
import Photos


class VideoConverterViewController: UIViewController {
    
    @IBOutlet var converterProgress: UIProgressView!
    @IBOutlet var converterStatus: UILabel!
    
    
    var videoAsset: PHAsset!
    
    var converter: BPCIVideoConverter?
    
    @IBAction func cancelPressed(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        
        self.converter = BPCIVideoConverter.process(self.videoAsset, u: 0.518508554, v: 0.508024156, minD: 0.440999985, maxD: 0.883499979)
        
        self.converter?.downloadProgress = {
            [weak self] progress in
            self?.converterStatus.text = "Downloading"
            self?.converterProgress.progress = Float(progress)
        }
        self.converter?.processProgress = {
            [weak self] progress in
            self?.converterStatus.text = "Processing"
            self?.converterProgress.progress = Float(progress)
        }
        self.converterStatus.text = "Waiting"
        
        self.converter?.convert{
            [weak self] urlObj, error in
            
            guard let url = urlObj else {
                // TODO:
                print("ERROR: ", error)
                return
            }
            
            
            dispatch_async(dispatch_get_main_queue()) {
                [weak self] in
                
                guard let _ = self else { return }

                self?.converterStatus.text = "Done"
                
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                share.completionWithItemsHandler = {
                    activityType, completed, returnedItems, activityError in
                    //(String?, Bool, [AnyObject]?, NSError?) -> Void
                    
                    print(activityType, completed, returnedItems, activityError)
                    
                    self?.dismissViewControllerAnimated(true, completion: nil)
                    _ = try? NSFileManager.defaultManager().removeItemAtURL(url)
                }
                self?.presentViewController(share, animated: true, completion: nil)
                
            }
            
            
//            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
//                PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(url)
//                }, completionHandler: {
//                    success, error in
//                    guard success else { return }
//                    _ = try? NSFileManager.defaultManager().removeItemAtURL(url)
//            })
            
        }
        
        
    }
}