//
//  VideoCell.swift
//  VideoProcessing
//
//  Created by Paul Jones on 02/08/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit
import Photos
import AVFoundation
import AVKit


// A UICollectionViewCell to display a video thumbnail for a given PHAsset
class VideoCell: UICollectionViewCell {
    
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var imageRequest:PHImageRequestID = PHInvalidImageRequestID {
        willSet {
            if self.imageRequest != PHInvalidImageRequestID {
                // Cancel the existing request before updating a new one
                PHImageManager.defaultManager().cancelImageRequest(self.imageRequest)
            }
        }
    }
    
    override func prepareForReuse() {
        self.activityIndicator.startAnimating()
        self.thumbnailImageView.image = nil
        self.phAsset = nil
        imageRequest = PHInvalidImageRequestID  // willSet will cancel the existing request
        
        self.tag = self.tag + 1
    }
    
    var phAsset:PHAsset? {
        didSet {
            // when this value is set, retrieve a thumbnail image from the photo library
            guard let asset = self.phAsset else {
                self.thumbnailImageView.image = nil
                return
            }
            
            let id = self.tag
            
            
            let options = PHVideoRequestOptions()
            options.networkAccessAllowed = true
            self.activityIndicator.stopAnimating()
            
            self.imageRequest = PHImageManager.defaultManager().requestAVAssetForVideo(asset, options: options) {
                assetObj, _, info in
                
                guard info?[PHImageCancelledKey] == nil else { return } // Make sure the request has not been cancelled
                

                
                guard let av_asset = assetObj else {
                    
                    if let _ = info?[PHImageResultIsInCloudKey] {
                        self.activityIndicator.startAnimating()         // show the activityIndicator if we have to download from the cloud
                        return
                    }
                    self.thumbnailImageView.image = nil
                    print("Request failed: \(info)")
                    return
                }
                
                av_asset.requestMidPointPreviewImage(maximumSize: self.thumbnailImageView.frame.size) {
                    image, error in
                    
                    if let error = error {
                        print(error)
                    }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        guard id == self.tag else { // This makes sure the cell has not been reused since the image was requested
                            if let key = info?[PHImageResultRequestIDKey]?.intValue {
                                PHImageManager.defaultManager().cancelImageRequest(key)
                            }
                            return
                        }
                        
                        // Animate the cell contents when the thumbnail become available - faster if there is no image already
                        UIView.transitionWithView(self.thumbnailImageView,
                                                  duration: (self.thumbnailImageView.image == nil) ? 0.10 : 0.50,
                                                  options: .TransitionCrossDissolve,
                                                  animations: { self.thumbnailImageView.image = image },
                                                  completion: nil)
                        
                        self.activityIndicator.stopAnimating()
                    }
                    
                }
                
            }

        }
        
    }
    
    
}



