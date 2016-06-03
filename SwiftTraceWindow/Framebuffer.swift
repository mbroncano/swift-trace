//
//  Framebuffer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

typealias VectorPointer = UnsafeMutablePointer<Vector>
typealias RayPointer = UnsafeMutablePointer<_Ray>

typealias Byte = UInt8
extension Byte {
    static let Max = 255
}

enum PixelException: ErrorType {
    case InvalidColor
}

/// Structure containing a RGBA pixel
public struct Pixel {
    /// Alpha, Red, Green, Blue
    private let a, r, g, b: Byte
    
    /// Default initializer with all four members
    init(a: Byte, r: Byte, g: Byte, b: Byte) {
        self.a = a
        self.r = r
        self.g = g
        self.b = b
    }
    
    subscript(i: Int) -> Byte {
        switch i {
        case 0: return r
        case 1: return g
        case 2: return b
        case 3: return a
        default:
            // FIXME: throw error
            return 0
        }
    }
    
    /// Default initializer with Color type
    /// -Parameter color: Color type variable
    init(color: Vector) {
        let c = clamp(color, min: 0, max: 1) * Real(Byte.Max)
        
        (r, g, b, a) = (Byte(c[0]), Byte(c[1]), Byte(c[2]), 0)
    }
    
    init(h: Real, s: Real, v: Real) {
        let r=v*(1+s*(cos(h)-1))
        let g=v*(1+s*(cos(h-2.09439)-1))
        let b=v*(1+s*(cos(h+2.09439)-1))
        
        self.init(color: Vector(r, g, b))
    }
}

struct Framebuffer {
    var samples: Int = 0
    let width, height: Int
    let length: Int
    var flip: Bool = false
    let ptr: VectorPointer
    let ray: RayPointer
    
    init(width w: Int, height h:Int) {
        width = w
        height = h
        length = width * height
        ptr = VectorPointer.alloc(length)
        ray = RayPointer.alloc(length)
    }
    
    func cgImage() -> CGImage? {
        let ratio = 1.0 / Real(samples)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: length))
        let imageData = UnsafeMutablePointer<Pixel>(pixels.map({ Pixel(color: ($0 * ratio)) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        if flip {
            CGContextTranslateCTM(bitmapContext, 0, CGFloat(height))
            CGContextScaleCTM(bitmapContext, 1.0, -1.0)
        }
        return CGBitmapContextCreateImage(bitmapContext)
    }

    func hitImage() -> CGImage? {
        let hits = UnsafeMutableBufferPointer<_Ray>(start: ray, count: length)
        let maxHits = 1 + hits.reduce(0) { max($0, $1.count) }
        let pixels: [Pixel] = hits.map({ hit in
            // reverse logarithmic scale for the hit count
            let r = Real(maxHits - hit.count) / Real(maxHits)
            let h = Real(2*M_PI) * r
            
            return Pixel(h: h, s: 0.6, v: 0.6) })
        let imageData = UnsafeMutablePointer<Pixel>(pixels)
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

