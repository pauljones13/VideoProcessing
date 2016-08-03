//
//  UserVideosViewController.swift
//  VideoProcessing
//
//  Created by Paul Jones on 02/08/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import UIKit
import Photos

// A basic UICollectionViewController to display all the videos in the User's library
class UserVideosViewController: UICollectionViewController {
    
    var videos:PHFetchResult? = nil
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        videos = nil
        PHPhotoLibrary.requestAuthorization {
            status in
            
            guard status == .Authorized else {
                // TODO: Handle Access Denied
                return
            }
            
            guard let video = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumVideos, options: nil).firstObject as? PHAssetCollection else {
                // TODO: Handle No Videos Album
                return
            }
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            self.videos = PHAsset.fetchAssetsInAssetCollection(video, options: options)
            
            
            PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionView?.reloadData()
            }
            
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // When the user selects a video, open it in the VideoConverterViewController
        if segue.identifier == "openConverter",
            let videoCell = sender as? VideoCell,
            let asset = videoCell.phAsset,
            let videoConverterViewController = segue.destinationViewController as? VideoConverterViewController {
            
            videoConverterViewController.videoAsset = asset

        }
    }
    
}

extension UserVideosViewController {
    // Collection view manager
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.videos?.count ?? 0
    }
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCell", forIndexPath: indexPath) as! VideoCell
        
        if let asset = videos?.objectAtIndex(indexPath.row) as? PHAsset {
            
            cell.phAsset = asset
        }
        else {
            cell.phAsset = nil
        }
        
        return cell
    }
}

extension UserVideosViewController: PHPhotoLibraryChangeObserver {
    // Simple handing of photo library changes by refreshing the collection view
    // TODO: Do this properly so it looks nice
    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView?.reloadData()
        }
    }
}



