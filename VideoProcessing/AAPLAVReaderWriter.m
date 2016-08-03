/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 Sample code project: Sample Photo Editing Extension
 Version: 1.1
 
 IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 
 
 
 
 Abstract:
 
 Helper class to read and decode a movie frame by frame, adjust each frame, then encode and write to a new movie file.
 
 */


//  Modified by Paul on 13/04/2015.
//  Copyright (c) 2015 Fluid Pixel. All rights reserved.
//
//  Now allows the output size of the video to be specified
//  Fixed sound
//  add some metadata


/* NOT USED IN THIS PROJECT
 
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import "AAPLAVReaderWriter.h"
#import "BPDateManager.h"


@protocol AAPLRWSampleBufferChannelDelegate;

@interface AAPLRWSampleBufferChannel : NSObject
{
@private
    dispatch_block_t completionHandler;
    dispatch_queue_t serializationQueue;
}

@property BOOL useAdaptor;
@property BOOL finished;  // only accessed on serialization queue;
@property AVAssetWriterInput* assetWriterInput;
@property AVAssetReaderOutput* assetReaderOutput;
@property AVAssetWriterInputPixelBufferAdaptor* adaptor;

- (instancetype)initWithAssetReaderOutput:(AVAssetReaderOutput *)assetReaderOutput
                         assetWriterInput:(AVAssetWriterInput *)assetWriterInput
                               useAdaptor:(BOOL)useAdaptor
                               outputSize:(CGSize)outSize;


// delegate is retained until completion handler is called.
// Completion handler is guaranteed to be called exactly once, whether reading/writing finishes, fails, or is cancelled.
// Delegate may be nil.
//
- (void)startWithDelegate:(id <AAPLRWSampleBufferChannelDelegate>)delegate
        completionHandler:(dispatch_block_t)completionHandler;

- (void)cancel;

@end


@protocol AAPLRWSampleBufferChannelDelegate <NSObject>
@optional

- (void)sampleBufferChannel:(AAPLRWSampleBufferChannel *)sampleBufferChannel
        didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)sampleBufferChannel:(AAPLRWSampleBufferChannel *)sampleBufferChannel
        didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer
   andMadeWriteSampleBuffer:(CVPixelBufferRef)sampleBufferForWrite;

@end




@implementation AAPLRWSampleBufferChannel

- (instancetype)initWithAssetReaderOutput:(AVAssetReaderOutput *)localAssetReaderOutput
                         assetWriterInput:(AVAssetWriterInput *)localAssetWriterInput
                               useAdaptor:(BOOL)useAdaptor
                               outputSize:(CGSize)outSize

{
    self = [super init];
    
    if (self)
    {
        _assetReaderOutput = localAssetReaderOutput;
        _assetWriterInput = localAssetWriterInput;
        
        _finished = NO;
        
        // Pixel buffer attributes keys for the pixel buffer pool are defined in <CoreVideo/CVPixelBuffer.h>.
        // To specify the pixel format type, the pixelBufferAttributes dictionary should contain a value for kCVPixelBufferPixelFormatTypeKey.
        // For example, use [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] for 8-bit-per-channel BGRA.
        // See the discussion under appendPixelBuffer:withPresentationTime: for advice on choosing a pixel format.
        //
        _useAdaptor = useAdaptor;
        NSDictionary* adaptorAttrs;
        
        if (outSize.width == CGSizeZero.width  && outSize.height == CGSizeZero.height) {
            adaptorAttrs = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
        }
        else {
            adaptorAttrs = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                              (id)kCVPixelBufferWidthKey:@(outSize.width),
                              (id)kCVPixelBufferHeightKey:@(outSize.height)};
            
        }
        
        if (useAdaptor)
            _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:localAssetWriterInput
                                                                                        sourcePixelBufferAttributes:adaptorAttrs];
        
        serializationQueue = dispatch_queue_create("AAPLRWSampleBufferChannel queue", NULL);
    }
    
    return self;
}

// always called on the serialization queue
- (void)callCompletionHandlerIfNecessary
{
    // Set state to mark that we no longer need to call the completion handler, grab the completion handler, and clear out the ivar
    BOOL oldFinished = self.finished;
    self.finished = YES;
    
    if (oldFinished == NO)
    {
        [self.assetWriterInput markAsFinished];  // let the asset writer know that we will not be appending any more samples to this input
        
        dispatch_block_t localCompletionHandler = completionHandler;
        completionHandler = nil;
        
        if (localCompletionHandler)
            localCompletionHandler();
    }
}


- (void)startWithDelegate:(id <AAPLRWSampleBufferChannelDelegate>)delegate completionHandler:(dispatch_block_t)localCompletionHandler
{
    completionHandler = [localCompletionHandler copy];  // released in -callCompletionHandlerIfNecessary
    
    [self.assetWriterInput requestMediaDataWhenReadyOnQueue:serializationQueue usingBlock:^{
        
        if (self.finished)
            return;
        
        BOOL completedOrFailed = NO;
        
        // Read samples in a loop as long as the asset writer input is ready
        while ([self.assetWriterInput isReadyForMoreMediaData] && !completedOrFailed)
        {
            @autoreleasepool {
                
                CMSampleBufferRef sampleBuffer = [self.assetReaderOutput copyNextSampleBuffer];
                if (sampleBuffer != NULL)
                {
                    BOOL success = NO;
                    
                    if (self.adaptor && [delegate respondsToSelector:@selector(sampleBufferChannel:didReadSampleBuffer:andMadeWriteSampleBuffer:)])
                    {
                        CVPixelBufferRef writerBuffer = NULL;
                        CVPixelBufferPoolCreatePixelBuffer (NULL, self.adaptor.pixelBufferPool, &writerBuffer);
                        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                        
                        [delegate sampleBufferChannel:self didReadSampleBuffer:sampleBuffer andMadeWriteSampleBuffer:writerBuffer];
                        success = [self.adaptor appendPixelBuffer:writerBuffer withPresentationTime:presentationTime];
                        
                        CFRelease(writerBuffer);
                    }
                    else{
                        if (delegate && [delegate respondsToSelector:@selector(sampleBufferChannel:didReadSampleBuffer:)])
                            [delegate sampleBufferChannel:self didReadSampleBuffer:sampleBuffer];
                        
                        success = [self.assetWriterInput appendSampleBuffer:sampleBuffer];
                    }
                    
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                    
                    completedOrFailed = !success;
                }
                else
                    completedOrFailed = YES;
                
            }
        }
        
        if (completedOrFailed)
            [self callCompletionHandlerIfNecessary];
    }];
}

- (void)cancel
{
    dispatch_async(serializationQueue, ^{
        [self callCompletionHandlerIfNecessary];
    });
}

@end









#pragma mark -

static dispatch_queue_t shared_serializationQueue;
static dispatch_once_t shared_serializationQueue_initToken;

typedef void (^AVReaderWriterProgressProc)(float);
typedef void (^AVReaderWriterCompletionProc)(NSError*);


@interface AAPLAVReaderWriter() <AAPLRWSampleBufferChannelDelegate>

@property AVAsset*      asset;
@property CMTimeRange   timeRange;
@property NSURL*        outputURL;
@property CGSize        outputVideoSize;

@end

@implementation AAPLAVReaderWriter
{
    dispatch_queue_t			_serializationQueue;
    
    // All of these are createed, accessed, and torn down exclusively on the serializaton queue
    AVAssetReader*            assetReader;
    AVAssetWriter*            assetWriter;
    AAPLRWSampleBufferChannel*    audioSampleBufferChannel;
    AAPLRWSampleBufferChannel*    videoSampleBufferChannel;
    BOOL	                      cancelled;
    AVReaderWriterProgressProc    _progressProc;
    AVReaderWriterCompletionProc  _completionProc;
}

- (instancetype) initWithAsset: (AVAsset*) asset
{
    self = [super init];
    
    _asset = asset;
    
    dispatch_once(&shared_serializationQueue_initToken, ^{
        shared_serializationQueue = dispatch_queue_create("com.bubblepix.videoconverter",  DISPATCH_QUEUE_SERIAL);
    });
    
    _serializationQueue = shared_serializationQueue;
    _metadataDate = nil;
    _metadataLocation = nil;
    
    return self;
}

// convenience method
- (void)writeToURL:(NSURL *)localOutputURL
          progress:(void (^)(float)) progress
        completion:(void (^)(NSError *)) completion
{
    [self writeToURL:localOutputURL outputSize:CGSizeZero progress:progress completion:completion];
}


- (void)writeToURL:(NSURL *)localOutputURL
        outputSize:(CGSize)outSize
          progress:(void (^)(float)) progress
        completion:(void (^)(NSError *)) completion
{
    [self setOutputURL:localOutputURL];
    [self setOutputVideoSize:outSize];
    
    AVAsset *localAsset = [self asset];
    
    _completionProc = completion;
    _progressProc = progress;
    
    [localAsset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^{
        
        // Dispatch the setup work to the serialization queue, to ensure this work is serialized with potential cancellation
        dispatch_async(_serializationQueue, ^{
            
            // Since we are doing these things asynchronously, the user may have already cancelled on the main thread.  In that case, simply return from this block
            if (cancelled)
                return;
            
            BOOL success = YES;
            NSError *localError = nil;
            
            success = ([localAsset statusOfValueForKey:@"tracks" error:&localError] == AVKeyValueStatusLoaded);
            if (success)
                success = ([localAsset statusOfValueForKey:@"duration" error:&localError] == AVKeyValueStatusLoaded);
            
            if (success)
            {
                self.timeRange = CMTimeRangeMake(kCMTimeZero, [localAsset duration]);
                
                // AVAssetWriter does not overwrite files for us, so remove the destination file if it already exists
                NSFileManager *fm = [NSFileManager new];
                NSString *localOutputPath = [localOutputURL path];
                if ([fm fileExistsAtPath:localOutputPath])
                    success = [fm removeItemAtPath:localOutputPath error:&localError];
            }
            
            // Set up the AVAssetReader and AVAssetWriter, then begin writing samples or flag an error
            if (success)
                success = [self setUpReaderAndWriterReturningError:&localError];
        
            // If metadata has been set, add it to the output
            NSMutableArray * metadata = [NSMutableArray arrayWithCapacity:2];
            
            if (_metadataDate) {
                NSString * dateString = [[BPDateManager sharedDateManager] convertToUTCTimestamp:_metadataDate];
                
                AVMutableMetadataItem * createDate = [AVMutableMetadataItem metadataItem];
                [createDate setKey:AVMetadataQuickTimeMetadataKeyCreationDate];
                [createDate setKeySpace:AVMetadataKeySpaceQuickTimeMetadata];
                [createDate setValue:dateString];
                
                [metadata addObject:createDate];
            }
            
            if (_metadataLocation) {
                NSString * locationString = [NSString stringWithFormat:@"%+08.4lf%+09.4lf",
                                             _metadataLocation.coordinate.latitude,
                                             _metadataLocation.coordinate.longitude];
                
                AVMutableMetadataItem * location = [AVMutableMetadataItem metadataItem];
                [location setKey:AVMetadataQuickTimeMetadataKeyLocationISO6709];
                [location setKeySpace:AVMetadataKeySpaceQuickTimeMetadata];
                [location setValue:locationString];
                
                [metadata addObject:location];
            }
            
            [assetWriter setMetadata:metadata];
            
            if (success)
                success = [self startReadingAndWritingReturningError:&localError];
            
            if (!success)
            {
                [self readingAndWritingDidFinishSuccessfully:success withError:localError];
            }
        });
    }];
}

- (BOOL) setUpReaderAndWriterReturningError:(NSError **)outError
{
    NSError *localError = nil;
    AVAsset *localAsset = [self asset];
    NSURL *localOutputURL = [self outputURL];
    
    // Create asset reader and asset writer
    assetReader = [[AVAssetReader alloc] initWithAsset:localAsset error:&localError];
    if (!assetReader)
    {
        if (outError)
            *outError = localError;
        return NO;
    }
    
    assetWriter = [[AVAssetWriter alloc] initWithURL:localOutputURL fileType:AVFileTypeQuickTimeMovie error:&localError];
    if (!assetReader)
    {
        if (outError)
            *outError = localError;
        return NO;
    }
    
    // Create asset reader outputs and asset writer inputs for the first audio track and first video track of the asset
    
    // Grab first audio track and first video track, if the asset has them
    AVAssetTrack *audioTrack = nil;
    NSArray *audioTracks = [localAsset tracksWithMediaType:AVMediaTypeAudio];
    if ([audioTracks count] > 0)
        audioTrack = audioTracks[0];
    
    AVAssetTrack *videoTrack = nil;
    NSArray *videoTracks = [localAsset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] > 0)
        videoTrack = videoTracks[0];
    
    if (audioTrack)
    {
        // Decompress to Linear PCM with the asset reader
        AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
        [assetReader addOutput:output];
        
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:audioTrack.mediaType outputSettings:nil];
        [assetWriter addInput:input];
        
        // Create and save an instance of AAPLRWSampleBufferChannel, which will coordinate the work of reading and writing sample buffers
        audioSampleBufferChannel = [[AAPLRWSampleBufferChannel alloc] initWithAssetReaderOutput:output
                                                                               assetWriterInput:input
                                                                                     useAdaptor:NO
                                                                                     outputSize:CGSizeZero];
    }
    
    if (videoTrack)
    {
        // Decompress to ARGB with the asset reader
        NSDictionary *decompSettings = @{
                                         (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                         (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
                                         };
        AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                 outputSettings:decompSettings];
        [assetReader addOutput:output];
        
        // Get the format description of the track, to fill in attributes of the video stream that we don't want to change
        CMFormatDescriptionRef formatDescription = NULL;
        NSArray *formatDescriptions = [videoTrack formatDescriptions];
        if ([formatDescriptions count] > 0)
            formatDescription = (__bridge CMFormatDescriptionRef)formatDescriptions[0];
        
        
        
        CGSize trackDimensions = CGSizeZero;
        //if (CGSizeEqualToSize(self.outputVideoSize, CGSizeZero)) {
            
            // Grab track dimensions from format description
            if (formatDescription) {
                trackDimensions = CMVideoFormatDescriptionGetPresentationDimensions(formatDescription, false, false);
            }
            else {
                trackDimensions = [videoTrack naturalSize];
            }
        //}
        //else {
        //    trackDimensions = self.outputVideoSize;
        //}
        
        
        
        // Grab clean aperture, pixel aspect ratio from format description
        NSDictionary *compressionSettings = nil;
        if (formatDescription)
        {
            NSDictionary *cleanAperture = nil;
            CFDictionaryRef cleanApertureDescr = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_CleanAperture);
            if (cleanApertureDescr)
            {
                cleanAperture = @{
                                  AVVideoCleanApertureWidthKey :
                                      (id)CFDictionaryGetValue(cleanApertureDescr, kCMFormatDescriptionKey_CleanApertureWidth),
                                  AVVideoCleanApertureHeightKey :
                                      (id)CFDictionaryGetValue(cleanApertureDescr, kCMFormatDescriptionKey_CleanApertureHeight),
                                  AVVideoCleanApertureHorizontalOffsetKey :
                                      (id)CFDictionaryGetValue(cleanApertureDescr, kCMFormatDescriptionKey_CleanApertureHorizontalOffset),
                                  AVVideoCleanApertureVerticalOffsetKey :
                                      (id)CFDictionaryGetValue(cleanApertureDescr, kCMFormatDescriptionKey_CleanApertureVerticalOffset),
                                  };
            }
            
            NSDictionary *pixelAspectRatio = nil;
            CFDictionaryRef pixelAspectRatioDescr = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_PixelAspectRatio);
            if (pixelAspectRatioDescr)
            {
                pixelAspectRatio = @{
                                     AVVideoPixelAspectRatioHorizontalSpacingKey :
                                         (id)CFDictionaryGetValue(pixelAspectRatioDescr, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing),
                                     AVVideoPixelAspectRatioVerticalSpacingKey :
                                         (id)CFDictionaryGetValue(pixelAspectRatioDescr, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing),
                                     };
            }
            
            if (cleanAperture || pixelAspectRatio)
            {
                NSMutableDictionary *mutableCompressionSettings = [NSMutableDictionary dictionary];
                if (cleanAperture)
                    mutableCompressionSettings[AVVideoCleanApertureKey] = cleanAperture;
                if (pixelAspectRatio)
                    mutableCompressionSettings[AVVideoPixelAspectRatioKey] = pixelAspectRatio;
                compressionSettings = mutableCompressionSettings;
            }
        }
        
        // Compress to H.264 with the asset writer
        NSMutableDictionary *videoSettings;
        if (CGSizeEqualToSize(self.outputVideoSize, CGSizeZero)) {
            videoSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             AVVideoCodecH264, AVVideoCodecKey,
                             @(trackDimensions.width), AVVideoWidthKey,
                             @(trackDimensions.height), AVVideoHeightKey,
                             nil];
        }
        else {
            videoSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             AVVideoCodecH264, AVVideoCodecKey,
                             @(self.outputVideoSize.width), AVVideoWidthKey,
                             @(self.outputVideoSize.height), AVVideoHeightKey,
                             nil];
        }

        if (compressionSettings)
            videoSettings[AVVideoCompressionPropertiesKey] = compressionSettings;
        
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:videoTrack.mediaType
                                                                       outputSettings:videoSettings];
        input.transform = [videoTrack preferredTransform];
        [assetWriter addInput:input];
        
        // Create and save an instance of AAPLRWSampleBufferChannel, which will coordinate the work of reading and writing sample buffers
        videoSampleBufferChannel = [[AAPLRWSampleBufferChannel alloc] initWithAssetReaderOutput:output
                                                                               assetWriterInput:input
                                                                                     useAdaptor:YES
                                                                                     outputSize:self.outputVideoSize];
    }
    
    return YES;
}

- (BOOL)startReadingAndWritingReturningError:(NSError **)outError
{
    // Instruct the asset reader and asset writer to get ready to do work
    if ([assetReader startReading]==NO)
    {
        if (outError) *outError = [assetReader error];
        return NO;
    }
    
    if ([assetWriter startWriting] == NO)
    {
        if (outError) *outError = [assetWriter error];
        return NO;
    }
    
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    // Start a sample-writing session
    [assetWriter startSessionAtSourceTime:self.timeRange.start];
    
    // Start reading and writing samples
    if (audioSampleBufferChannel)
    {
        // Only set audio delegate for audio-only assets, else let the video channel drive progress
        id <AAPLRWSampleBufferChannelDelegate> delegate = nil;
        if (!videoSampleBufferChannel)
            delegate = self;
        
        dispatch_group_enter(dispatchGroup);
        [audioSampleBufferChannel startWithDelegate:delegate
                                  completionHandler:^{
                                      dispatch_group_leave(dispatchGroup);
                                  }];
    }
    if (videoSampleBufferChannel)
    {
        dispatch_group_enter(dispatchGroup);
        [videoSampleBufferChannel startWithDelegate:self
                                  completionHandler:^{
                                      dispatch_group_leave(dispatchGroup);
                                  }];
    }
    
    // Set up a callback for when the sample writing is finished
    dispatch_group_notify(dispatchGroup, _serializationQueue, ^{
        BOOL finalSuccess = YES;
        __block NSError *finalError = nil;
        
        if (cancelled)
        {
            [assetReader cancelReading];
            [assetWriter cancelWriting];
        }
        else
        {
            if ([assetReader status] == AVAssetReaderStatusFailed)
            {
                finalSuccess = NO;
                finalError = [assetReader error];
            }
            
            if (finalSuccess)
            {
                [assetWriter finishWritingWithCompletionHandler:^{
                    BOOL success = (assetWriter.status == AVAssetWriterStatusCompleted);
                    [self readingAndWritingDidFinishSuccessfully:success withError:[assetWriter error]];
                }];
            }
        }
        
    });
    
    return YES;
}

- (void)cancel:(id)sender
{
    // Dispatch cancellation tasks to the serialization queue to avoid races with setup and teardown
    dispatch_async(_serializationQueue, ^{
        [audioSampleBufferChannel cancel];
        [videoSampleBufferChannel cancel];
        cancelled = YES;
    });
}

- (void)readingAndWritingDidFinishSuccessfully:(BOOL)success withError:(NSError *)error
{
    if (!success)
    {
        [assetReader cancelReading];
        [assetWriter cancelWriting];
    }
    
    // Tear down ivars
    assetReader = nil;
    assetWriter = nil;
    audioSampleBufferChannel = nil;
    videoSampleBufferChannel = nil;
    cancelled = NO;
    
    _completionProc(error);
}

static double progressOfSampleBufferInTimeRange(CMSampleBufferRef sampleBuffer, CMTimeRange timeRange)
{
    CMTime progressTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    progressTime = CMTimeSubtract(progressTime, timeRange.start);
    CMTime sampleDuration = CMSampleBufferGetDuration(sampleBuffer);
    if (CMTIME_IS_NUMERIC(sampleDuration))
        progressTime= CMTimeAdd(progressTime, sampleDuration);
    return CMTimeGetSeconds(progressTime) / CMTimeGetSeconds(timeRange.duration);
}


- (void)sampleBufferChannel:(AAPLRWSampleBufferChannel *)sampleBufferChannel
        didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    // Calculate progress (scale of 0.0 to 1.0)
    double progress = progressOfSampleBufferInTimeRange(sampleBuffer, self.timeRange);
    
    _progressProc(progress * 100.0);
    
    // Grab the pixel buffer from the sample buffer, if possible
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (imageBuffer && (CFGetTypeID(imageBuffer) == CVPixelBufferGetTypeID()))
    {
        //pixelBuffer = (CVPixelBufferRef)imageBuffer;
        [self.delegate adjustPixelBuffer:imageBuffer];
    }
}

- (void)sampleBufferChannel:(AAPLRWSampleBufferChannel *)sampleBufferChannel
        didReadSampleBuffer:(CMSampleBufferRef)sampleBuffer
   andMadeWriteSampleBuffer:(CVPixelBufferRef)sampleBufferForWrite
{
    // Calculate progress (scale of 0.0 to 1.0)
    double progress = progressOfSampleBufferInTimeRange(sampleBuffer, self.timeRange);
    
    _progressProc(progress * 100.0);
    
    // Grab the pixel buffer from the sample buffer, if possible
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVImageBufferRef writerBuffer = (CVPixelBufferRef)sampleBufferForWrite;
    
    if (imageBuffer && (CFGetTypeID(imageBuffer) == CVPixelBufferGetTypeID()) &&
        writerBuffer )//&& (CFGetTypeID(writerBuffer) == CVPixelBufferGetTypeID()))
    {
        [self.delegate adjustPixelBuffer:imageBuffer toOutputBuffer:writerBuffer];
    }
}


@end


*/