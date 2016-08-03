//
//  AVAsset+Thumbnail.swift
//  BubbleWrap
//
//  Created by Paul Jones on 17/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation


// asynchronously returns the midpoint image from a video asset
extension AVAsset {
    
    func requestMidPointPreviewImage(maximumSize maxSize: CGSize = CGSize(width: 512.0, height: 512.0), completion: (UIImage?, NSError?)->Void) {
        
        let generator = AVAssetImageGenerator(asset: self)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.generateCGImagesAsynchronouslyForTimes([NSValue(CMTime: CMTimeMultiplyByRatio(self.duration, 1, 2))]) {
            _, imageObj, _, _, error in
            
            guard let imageCG = imageObj else {
                completion(nil, error)
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(UIImage(CGImage: imageCG), nil)
            }
        }
        
    }
    
}