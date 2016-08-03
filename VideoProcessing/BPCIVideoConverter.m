//
//  BPCIVideoConverter.m
//  BubblePix
//
//  Created by Paul on 15/04/2015.
//  Copyright (c) 2015 Fluid Pixel. All rights reserved.
//


// This is the original BubblePix video converter for iOS8

/* NOT USED IN THIS PROJECT
 
 
#import "BPCIVideoConverter.h"

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

#import "MediaObjectInterface.h"
#import "AAPLAVReaderWriter.h"
#import "LocalMediaObject.h"
#import "RemoteMediaObject.h"
#import "Swift-Patch.h"

#define VIDEO_ALIGNMENT 0.58

static dispatch_group_t converter_sync;
static dispatch_once_t converter_sync_init_token;
static NSMutableSet<BPCIVideoConverter *> * activeConversions;

@implementation BPCIVideoConverter

@synthesize mediaObject;
@synthesize targetURL;

@synthesize filter;
@synthesize context;

@synthesize outputSize;
@synthesize exportPreset;
@synthesize centralise;

@synthesize downloadTask;
@synthesize downloadProgressTimer;

+(void)removeConverterObject:(BPCIVideoConverter*)obj;
{
    if (activeConversions) {
        [activeConversions removeObject:obj];
    }
    else {
        activeConversions = [NSMutableSet<BPCIVideoConverter *> set];
    }
}
+(void)addConverterObject:(BPCIVideoConverter*)obj;
{
    if (activeConversions) {
        [activeConversions addObject:obj];
    }
    else {
        activeConversions = [NSMutableSet<BPCIVideoConverter *> setWithObject:obj];
    }
}

+(BPCIVideoConverter*)converterForMediaObject:(id<MediaObjectInterface>)mediaObj;
{
    
    if ([mediaObj isKindOfClass:[PhotoLibraryMediaObject class]])  return NULL;
    if (![[mediaObj getFormat] isEqualToString:@"video"]) return NULL;
    
    if (activeConversions) {
        
        __block BPCIVideoConverter * rv = NULL;
        
        [activeConversions enumerateObjectsUsingBlock:^(BPCIVideoConverter * _Nonnull converter, BOOL * _Nonnull stop) {
            if ([converter isProcessingMediaObject:mediaObj]) {
                rv = converter;
                *stop = YES;
            }
        }];
        
        if (rv) return rv;

    }

    BPCIVideoConverter * rv = [[BPCIVideoConverter alloc] initWithMediaObject:mediaObj];
    
    [BPCIVideoConverter addConverterObject:rv];
    
    return rv;
    
}


- (instancetype)initWithMediaObject:(id<MediaObjectInterface>)mediaObj;
{
    self = [super init];
    if (self) {
        
        dispatch_once(&converter_sync_init_token, ^{
            converter_sync = dispatch_group_create();
        });
        
        mediaObject = mediaObj;
        if ([[mediaObject getFormat] isEqualToString:@"video"]) {
            
            downloadTask = NULL;
            downloadProgressTimer = NULL;
            
            NSString * unwrappedFilename = [[[[[mediaObject getResourceURL]
                                              lastPathComponent]
                                                    stringByDeletingPathExtension]
                                                        stringByAppendingString:@"_unwrapped"]
                                                            stringByAppendingPathExtension:@"MP4"];

            targetURL = [NSURL fileURLWithPath: [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,true) objectAtIndex:0]
                                                 stringByAppendingPathComponent:unwrappedFilename]];
            
            context = [CIContext contextWithOptions:NULL];
            
            // TODO: Find out if 3840×2160 (4K) is available and unwrap to that resolution
            // outputSize = CGSizeMake(1920.0 * 2.0, 1080.0 * 2.0);
            // 4K conversion works on the 5S for output to YouTube etc but is not
            //                  supported by the Photo Library although export is successful, the Photos app behaves strangely
            // 4K does NOT work on the 4S at all - creates an error
            // 4K conversion seems to work in the simulator (Photos App 4K not supported on 5S but supported on 6)
            
            if (SUPPORTS_4K_VIDEO) {
                outputSize = CGSizeMake(3840.0, 2160.0);
                exportPreset = AVAssetExportPreset3840x2160;
            }
            else {
                outputSize = CGSizeMake(1920.0, 1080.0);
                exportPreset = AVAssetExportPreset1920x1080;
            }

//            outputSize = CGSizeMake(1280.0, 720.0);
//            exportPreset = AVAssetExportPreset1280x720;

            
            // Setup CoreImage Filter
            filter = [CIFilter filterWithName:@"BPScopeFilter"];
            [filter setDefaults];
            [filter setValue:@(outputSize.width)                        forKey:@"inputOutputWidth"];
            [filter setValue:@([mediaObject getUProportioanalDistance]) forKey:@"inputScopeCalibrationU"];
            [filter setValue:@([mediaObject getVProportioanalDistance]) forKey:@"inputScopeCalibrationV"];
            [filter setValue:@([mediaObject getMinDiamater] * 0.8)      forKey:@"inputMinDiameter"];
            [filter setValue:@([mediaObject getMaxDiameter] * 1.05)     forKey:@"inputMaxDiameter"];
            [filter setValue:@(0.0)                                     forKey:@"inputDiameterOffsetAdjustment"];
            
            CGFloat panoHeight;
            panoHeight = outputSize.width * 0.5 * M_1_PI;
            if (1.05 * [mediaObject getMaxDiameter] > 2.0 * 0.8 * [mediaObject getMinDiamater]) {
                panoHeight *= ((1.05 * [mediaObject getMaxDiameter])/(0.8 * [mediaObject getMinDiamater]) - 1.0);
            }
            
            CGFloat vScale = 1.312;
            
            centralise = CGAffineTransformTranslate(CGAffineTransformMakeScale(1.0, vScale), 0.0, 0.5 * (outputSize.height - panoHeight * vScale));

        }
        else {
            NSLog(@"Attempt to unwrap image using video unwrapper");
            return NULL;
        }
    }
    return self;
}


-(void)convertWithProgress:(void(^)(float))progress andCompletion:(void (^)(NSString *, NSError *))completion;
{
    
    self.processProgress = progress;
    [self convertWithCompletion:completion];
    
    if (downloadTask && !downloadTask.originalRequest.URL.fileURL) {
        self.downloadProgress = ^(float dlProg){
            progress(dlProg * 10.0);
        
        };
        self.processProgress = ^(float procProgress) {
            progress(10.0 + procProgress * 90.0);
            
        };
    }
    else {
        self.downloadProgress = NULL;
        self.processProgress = ^(float procProgress){
            progress(procProgress * 100.0);
        };
    }
    progress(0.0);
}

-(void)convertWithCompletion:(void (^)(NSString *, NSError *))completion;
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[targetURL path]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([targetURL path], nil);
            [BPCIVideoConverter removeConverterObject:self];
        });
        return;
    }
    
    if ([mediaObject getResourceURL].isFileURL) {
        [self convertFileURL:[mediaObject getResourceURL] withCompletion:completion];
        return;
    }
    
    if ([mediaObject isKindOfClass:[RemoteMediaObject class]]) {
        RemoteMediaObject * rmo = (RemoteMediaObject*)mediaObject;
        if (rmo.localMediaObject && rmo.localMediaObject.getResourceURL.isFileURL) {
            [self convertFileURL:rmo.localMediaObject.getResourceURL withCompletion:completion];
            return;
        }
    }
    
    NSString *cachesFolder = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *cachedBubblePath = [cachesFolder stringByAppendingPathComponent:mediaObject.getResourceURL.absoluteString.lastPathComponent];
    NSURL * cachedBubbleURL = [NSURL fileURLWithPath:cachedBubblePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachedBubblePath]) {
        [self convertFileURL:[NSURL fileURLWithPath:cachedBubblePath] withCompletion:completion];
        return;
    }
    NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = NO;
    NSURLSession * wiFiSession = [NSURLSession sessionWithConfiguration:config];
    
    
    downloadTask = [wiFiSession downloadTaskWithURL:[mediaObject getResourceURL]
                                  completionHandler:^(NSURL * _Nullable tempFile, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                      
                                      [downloadProgressTimer invalidate];
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          [self updateDownloadProgress: 1.0];
                                      });
                                      
                                      if (tempFile) {
                                          NSError * fileError;
                                          [[NSFileManager defaultManager] removeItemAtPath:cachedBubblePath error:nil];
                                          
                                          if ([[NSFileManager defaultManager] moveItemAtURL:tempFile toURL:cachedBubbleURL error:&fileError]) {
                                              [self convertFileURL:cachedBubbleURL withCompletion:completion];
                                          }
                                          else {
                                              completion(nil, fileError);
                                              [BPCIVideoConverter removeConverterObject:self];
                                          }
                                      }
                                      else {
                                          completion(nil, error);
                                          [BPCIVideoConverter removeConverterObject:self];
                                      }
                                      
                                      downloadProgressTimer = NULL;
                                      
                                  }];
    
    [downloadTask resume];
    
    downloadProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(downloadTimer:) userInfo:NULL repeats:true];
    
    [self updateDownloadProgress: 0.0];
    
}

-(void)downloadTimer:(NSTimer*)timer;
{
    if (downloadTask.countOfBytesExpectedToReceive != 0) {
        [self updateDownloadProgress:(float)downloadTask.countOfBytesReceived / (float)downloadTask.countOfBytesExpectedToReceive];
    }
    else {
        [self updateDownloadProgress:0.0];
    }
}
-(void)updateDownloadProgress:(float)progress;
{
    if (self.downloadProgress) {
        self.downloadProgress(progress);
    }
}


-(void)convertFileURL:(NSURL*)fileURL withCompletion:(void (^)(NSString *, NSError *))completion;
{
    
    dispatch_group_notify(converter_sync, dispatch_get_main_queue(), ^{ // wait for conversion to complete
        
        dispatch_group_enter(converter_sync); // hold the next conversion

        
        AAPLAVReaderWriter * readerWriter = [[AAPLAVReaderWriter alloc] initWithAsset:[AVURLAsset assetWithURL:fileURL]];
        
        readerWriter.delegate = self;
        
        if ([mediaObject getDateTaken]) [readerWriter setMetadataDate:[mediaObject getDateTaken]];
        
        if ([mediaObject hasLocationCoordinate]) {
            CLLocationCoordinate2D coords = [mediaObject getLocationCoordinate];
            if (CLLocationCoordinate2DIsValid(coords)) {
                
                [readerWriter setMetadataLocation:[[CLLocation alloc] initWithLatitude:coords.latitude longitude:coords.longitude]];
            }
        }
        
        NSString * tempFile = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]] stringByAppendingPathExtension:@"MP4"];
        
        [readerWriter writeToURL:[NSURL fileURLWithPath:tempFile]
                      outputSize:outputSize progress:^(float p) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              self.processProgress(p * 0.01);
                          });
                      }
                      completion:^(NSError * error) {
                          
                          dispatch_group_leave(converter_sync); // Start the next conversion
                          
                          dispatch_async(dispatch_get_main_queue(), ^{
                              
                              // no need to delete downloaded file as this is used as the cahced version
                              
                              if (error) {
                                  NSLog(@"Conversion Failed");
                                  completion(NULL, error);
                                  [BPCIVideoConverter removeConverterObject:self];
                              }
                              else {
                                  NSLog(@"Conversion Complete");
                                  
                                  [MetadataInjector injectMetadata:[NSURL fileURLWithPath:tempFile]];
                                  
                                  // TODO: Pass panoHeight etc to MetadataInjector and calculate correct crops etc
                                  // [MetadataInjector injectMetadata:[NSURL fileURLWithPath:tempFile] videoSize:outputSize panoHeight:panoHeight];
                                  
                                  [[NSFileManager defaultManager] removeItemAtPath:[targetURL path] error:nil];
                                  NSError * fileError;
                                  if ([[NSFileManager defaultManager] moveItemAtPath:tempFile toPath:[targetURL path] error:&fileError]) {
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          self.processProgress(1.0);
                                      });
                                      
                                      completion([targetURL path], NULL);
                                      [BPCIVideoConverter removeConverterObject:self];
                                  }
                                  else {
                                      completion(NULL, fileError);
                                      [BPCIVideoConverter removeConverterObject:self];
                                  }
                              }
                          });
                          
                      }];
        
    });
    
}

-(BOOL) isProcessingMediaObject:(id<MediaObjectInterface>)mo {
    NSString * thisFilename = [[self targetURL] lastPathComponent];
    NSString * testFilename = [[[[[mo getResourceURL]
                                  lastPathComponent]
                                 stringByDeletingPathExtension]
                                stringByAppendingString:@"_unwrapped"]
                               stringByAppendingPathExtension:@"MP4"];
    
    NSLog(@"%@ ?= %@", thisFilename, testFilename);
    
    return [thisFilename isEqualToString:testFilename];
    
}

// MARK: AAPLAVReaderWriterAdjustDelegate
- (void) adjustPixelBuffer:(CVPixelBufferRef)inputBuffer
            toOutputBuffer:(CVPixelBufferRef)outputBuffer;
{
    CIImage * source = [CIImage imageWithCVPixelBuffer:inputBuffer];
    
    [filter setValue:source forKey:kCIInputImageKey];
    
    [context render:[[filter outputImage] imageByApplyingTransform:centralise] toCVPixelBuffer:outputBuffer];
    
}

@end


 
 */
