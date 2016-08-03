//
//  BubblePixKernels.swift
//  BubblePix
//
//  Created by Paul Jones on 12/05/2016.
//  Copyright © 2016 Fluid Pixel. All rights reserved.
//

import Foundation
import CoreImage

// Singleton class to manage loading and compiling of Core Image Kernel Code

// TODO: Update to use metal and MPS where available (iPhone 6 or later for MPS)
// Note that there is no exception raised if the kernels do not compile

@objc
public class BubblePixKernels: NSObject {
    static let instance = BubblePixKernels()
    
    @objc class func scopeUnwrap() -> CIWarpKernel { return BubblePixKernels.instance.scopeUnwrapKernel }
    
    @objc class func planetCore() -> CIWarpKernel { return BubblePixKernels.instance.planetCoreKernel }
    @objc class func blurAmount() -> CIColorKernel { return BubblePixKernels.instance.blurAmountKernel }
    
    @objc class func clampYTileX() -> CIWarpKernel { return BubblePixKernels.instance.clampYTileXKernel }
    
    @objc class func blendToColour() -> CIColorKernel { return BubblePixKernels.instance.blendToColourKernel }
    @objc class func blendFromColour() -> CIColorKernel { return BubblePixKernels.instance.blendFromColourKernel }
    @objc class func blendToColourRadial() -> CIColorKernel { return BubblePixKernels.instance.blendToColourRadialKernel }

    
    
    let kernelsString: String
    let kernels: [CIKernel]
    
    let scopeUnwrapKernel: CIWarpKernel
    
    let planetCoreKernel: CIWarpKernel
    let blurAmountKernel: CIColorKernel
    
    let clampYTileXKernel: CIWarpKernel
    
    let blendToColourKernel: CIColorKernel
    let blendFromColourKernel: CIColorKernel
    let blendToColourRadialKernel: CIColorKernel
    
    private override init() {
        
        // !!!: When changing the kernels, make sure they compile correctly. There is no catch for when they do not compile.
        // iOS / CoreImage / OpenGL will continue and the image will not be processed properly
        
        self.kernelsString = try! String(contentsOfURL: NSBundle.mainBundle().URLForResource("BubblePixKernels", withExtension: "kernel")!)
        
        let compiledKernels = CIKernel.kernelsWithString(self.kernelsString)!
    
        self.kernels = compiledKernels

        self.scopeUnwrapKernel = kernels.filter { $0.name == "scopeUnwrap" }.first as! CIWarpKernel
        self.planetCoreKernel = kernels.filter { $0.name == "planetCore" }.first as! CIWarpKernel
        self.blurAmountKernel = kernels.filter { $0.name == "blurAmount" }.first as! CIColorKernel
        self.clampYTileXKernel = kernels.filter { $0.name == "clampYTileX" }.first as! CIWarpKernel
        
        self.blendToColourKernel = kernels.filter { $0.name == "blendToColour" }.first as! CIColorKernel
        self.blendFromColourKernel = kernels.filter { $0.name == "blendFromColour" }.first as! CIColorKernel
        self.blendToColourRadialKernel = kernels.filter { $0.name == "blendToColourRadial" }.first as! CIColorKernel
        
        super.init()
        
    }
    
    func kernelByName(searchName: String) -> CIKernel? {
        return kernels.filter { $0.name == searchName }.first
    }
}
