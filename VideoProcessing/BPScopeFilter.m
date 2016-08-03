//
//  BPScopeFilter.m
//  BubblePix
//
//  Created by Paul on 25/02/2015.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

#import "VideoProcessing-Swift.h"

// The original BubbleScope unwrpping filter
// does not need a .h file as CoreImage looks for the @implementation at runtime

@interface BPScopeFilter : CIFilter

@property (retain, nonatomic) CIImage  * inputImage;

// output panorama desired width - value < 1.0 width is calculated from donut max diameter
@property (retain, nonatomic) NSNumber * inputOutputWidth;

// output panorama offset angle
@property (retain, nonatomic) NSNumber * inputOffsetAngle;

// inputDiameterOffset - used when creating unwrap/equi to hide miss-calibrations
@property (retain, nonatomic) NSNumber * inputDiameterOffsetAdjustment;

// The calibrated centre of the scope donut
@property (retain, nonatomic) NSNumber * inputScopeCalibrationU;
@property (retain, nonatomic) NSNumber * inputScopeCalibrationV;

// The minimum and maximum diameters of the donut
@property (retain, nonatomic) NSNumber * inputMinDiameter;
@property (retain, nonatomic) NSNumber * inputMaxDiameter;

// extend edges to repeat image - should help apply smooth/seemless blurring etc.
@property (retain, nonatomic) NSNumber * inputOutputWidthExtensions;

@end

@implementation BPScopeFilter

@synthesize inputImage;
@synthesize inputOutputWidth;
@synthesize inputOffsetAngle;
@synthesize inputDiameterOffsetAdjustment;
@synthesize inputScopeCalibrationU;
@synthesize inputScopeCalibrationV;
@synthesize inputMinDiameter;
@synthesize inputMaxDiameter;
@synthesize inputOutputWidthExtensions;

+ (NSDictionary *)customAttributes
{
    return @{
             kCIAttributeFilterDisplayName : @"BubblePix BubbleScope CIFilter",
             kCIAttributeFilterCategories :  @[kCICategoryDistortionEffect,
                                               kCICategoryVideo,
                                               kCICategoryInterlaced,
                                               kCICategoryStillImage],
             @"inputOutputWidth": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @(32767.0),
                     kCIAttributeDefault : @2200.0,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputOffsetAngle": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @(2.0 * M_PI),
                     kCIAttributeDefault : @(M_PI_4),
                     kCIAttributeType : kCIAttributeTypeAngle
                     },
             @"inputDiameterOffsetAdjustment": @{
                     kCIAttributeSliderMin : @(-0.2),
                     kCIAttributeSliderMax : @(0.2),
                     kCIAttributeDefault : @(0.05),
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputScopeCalibrationU": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @1.0,
                     kCIAttributeDefault : @0.5,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputScopeCalibrationV": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @1.0,
                     kCIAttributeDefault : @0.5,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputMinDiameter": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @1.0,
                     kCIAttributeDefault : @0.42,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputMaxDiameter": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeSliderMax : @1.0,
                     kCIAttributeDefault : @0.93,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             @"inputOutputWidthExtensions": @{
                     kCIAttributeSliderMin : @0.0,
                     kCIAttributeDefault : @0.0,
                     kCIAttributeType : kCIAttributeTypeScalar
                     },
             };
}


- (CIImage *)outputImage
{
    if (!inputImage) return nil;
    CGRect inputExtent = inputImage.extent;
    if (CGRectIsInfinite(inputExtent)) return nil;
    
    CGFloat minRadius = self.inputMinDiameter.doubleValue * 0.5 * (1 + self.inputDiameterOffsetAdjustment.doubleValue) * inputExtent.size.height;
    CGFloat maxRadius = self.inputMaxDiameter.doubleValue * 0.5 * (1 - self.inputDiameterOffsetAdjustment.doubleValue) * inputExtent.size.height;
    
    CIVector *uvCentre = [CIVector vectorWithX: ( inputExtent.origin.x + self.inputScopeCalibrationU.doubleValue * inputExtent.size.width )
                                             Y: ( inputExtent.origin.y + (1.0 - self.inputScopeCalibrationV.doubleValue) * inputExtent.size.height )];
    
    CGFloat destWidth = self.inputOutputWidth.doubleValue;
    if (destWidth < 1.0) {
        destWidth = 2.0 * maxRadius * M_PI;
    }
    
    CGFloat dXMult = 2.0 * M_PI / destWidth;
    CGFloat dYMult = 2.0 * M_PI * (maxRadius - minRadius) / destWidth;
    
    CGFloat offset = M_PI - inputOffsetAngle.doubleValue;
    
    CGFloat extension = inputOutputWidthExtensions.doubleValue;
    
    // while it is possible to translate from one ROI to another, there is not a straightforward relation.
    // the ROI callback therefore returns the scope region of the output image
    CGRect constROI = CGRectMake([uvCentre X] - maxRadius, [uvCentre Y] - maxRadius, maxRadius * 2.0, maxRadius * 2.0);
    
    // output image extent
    CGFloat outHeight = 0.5 * destWidth * M_1_PI;
    if (maxRadius > 2.0 * minRadius) {
        outHeight *= (maxRadius/minRadius - 1.0);
    }
    
    CGRect destExtent = CGRectMake(-extension, 0.0, destWidth + extension * 2.0, outHeight);
    
    return [[BubblePixKernels scopeUnwrap] applyWithExtent:destExtent
                                               roiCallback:^CGRect(int index, CGRect destRect) { return constROI; }
                                                inputImage:self.inputImage
                                                 arguments:@[@(dXMult), @(dYMult), @(offset), @(minRadius), uvCentre]];
}

@end



