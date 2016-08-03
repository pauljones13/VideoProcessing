//
//  BPCIVideoConverter.h
//  BubblePix
//
//  Created by Paul on 15/04/2015.
//  Copyright (c) 2015 Fluid Pixel. All rights reserved.
//

// This is the original BubblePix video converter for iOS8

/* NOT USED IN THIS PROJECT
 
#import <Foundation/Foundation.h>
#import "MediaObjectInterface.h"
#import "AAPLAVReaderWriter.h"
#import <CoreImage/CoreImage.h>

typedef void(^ProgressBlock)(float);

@interface BPCIVideoConverter : NSObject<AAPLAVReaderWriterAdjustDelegate>

@property (nonatomic, strong) ProgressBlock processProgress;
@property (nonatomic, strong) ProgressBlock downloadProgress;

@property (nonatomic, strong, readonly) id<MediaObjectInterface> mediaObject;
@property (nonatomic, strong, readonly) NSURL* targetURL;

+(BPCIVideoConverter*)converterForMediaObject:(id<MediaObjectInterface>)mediaObj;

-(void)convertWithCompletion:(void (^)(NSString *, NSError *))completion;

-(void)convertWithProgress:(void(^)(float))progress andCompletion:(void (^)(NSString *, NSError *))completion; //__deprecated



// Exposed to Swift
@property (nonatomic, strong, readonly) CIFilter * filter;
@property (nonatomic, strong, readonly) CIContext * context;
    
@property (nonatomic, readonly) CGSize outputSize;
@property (nonatomic, readonly) CGAffineTransform centralise;
    
@property (nonatomic, strong, readonly) NSURLSessionDownloadTask * downloadTask;
@property (nonatomic, strong, readonly) NSTimer * downloadProgressTimer;
@property (nonatomic, strong, readonly) NSString * exportPreset;

+(void)removeConverterObject:(BPCIVideoConverter*)obj;
+(void)addConverterObject:(BPCIVideoConverter*)obj;

@end

 */


