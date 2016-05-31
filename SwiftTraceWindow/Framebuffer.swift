//
//  Framebuffer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

final class Framebuffer {
    var samples: Int = 0
    let width, height: Int
    let length: Int
    var flip: Bool = false
    let ptr: ColorPointer
    let ray: RayPointer
    let hit: IntersectionPointer

    
    init(width w: Int, height h:Int) {
        width = w
        height = h
        length = width * height
        ptr = ColorPointer.alloc(length)
        ray = RayPointer.alloc(length)
        hit = IntersectionPointer.alloc(length)
    }
    
    deinit {
        ptr.destroy()
        ray.destroy()
        hit.destroy()
    }

//    subscript(x:Int, y:Int) -> Color {
//        get { return ptr[(size.y - y - 1) * size.x + x] }
//        set { ptr[(size.y - y - 1) * size.x + x] = newValue }
//    }
    
    func cgImage() -> CGImage? {
        let ratio = 1.0 / Scalar(samples)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: length))
        let imageData = UnsafeMutablePointer<PixelRGBA>(pixels.map({ PixelRGBA(color: ($0 * ratio).gammaCorrected()) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        if flip {
            CGContextTranslateCTM(bitmapContext, 0, CGFloat(height))
            CGContextScaleCTM(bitmapContext, 1.0, -1.0)
        }
        return CGBitmapContextCreateImage(bitmapContext)
    }

    func hitImage() -> CGImage? {
        let hits = UnsafeMutableBufferPointer<Intersection>(start: hit, count: length)
//        let avgHits = hits.reduce(0) { $0 + $1.count } / length
        let maxHits = hits.reduce(0) { max($0, $1.count) }
        let pixels: [Color] = hits.map({ hit in
            // reverse logarithmic scale for the hit count
            let r = Scalar(maxHits - hit.count) / Scalar(maxHits)
            let h = Scalar.pi2 * r
            
            return Color(h: h, s: 0.6, v: 0.6) })
        let imageData = UnsafeMutablePointer<PixelRGBA>(pixels.map({ PixelRGBA(color: $0.gammaCorrected()) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        if flip {
            CGContextTranslateCTM(bitmapContext, 0, CGFloat(height))
            CGContextScaleCTM(bitmapContext, 1.0, -1.0)
        }
        return CGBitmapContextCreateImage(bitmapContext)
    }
    
    func savePNG(name: String) -> String {
        let texture_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, name, CFURLPathStyle.CFURLPOSIXPathStyle, false)
        let dest = CGImageDestinationCreateWithURL(texture_url, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(dest, self.cgImage()!, nil)
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

