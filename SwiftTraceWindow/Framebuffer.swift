//
//  Framebuffer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

class Framebuffer {
    let width:Int, height: Int
    var pixels: [Color]
    var samples: Int = 0
    
    init(width: Int, height:Int) {
        self.width = width
        self.height = height
        
        pixels = Array<Color>(count: width*height, repeatedValue: Color())
    }

    subscript(x:Int, y:Int) -> Color {
        get { return pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
    
    func cgImage() -> CGImage {
        let ratio : Double = 1 / Double(samples)
        let imageData : UnsafeMutablePointer<PixelRGBA> = UnsafeMutablePointer(pixels.map({ (color) -> PixelRGBA in PixelRGBA(color: color * ratio) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        return CGBitmapContextCreateImage(bitmapContext)!
    }
    
    func savePNG(name: String) -> String {
        let texture_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, name, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        let dest = CGImageDestinationCreateWithURL(texture_url, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(dest, self.cgImage(), nil)
        let ok = CGImageDestinationFinalize(dest)
        if ok {
            print("png image written to path \(texture_url)")
            return String(texture_url)
        } else {
            print("something went wrong")
            return String()
        }
    }
}

