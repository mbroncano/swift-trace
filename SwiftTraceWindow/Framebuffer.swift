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

enum PixelException: Error {
    case invalidColor
}

/// Structure containing a RGBA pixel
public struct Pixel {
    /// Alpha, Red, Green, Blue
    fileprivate let a, r, g, b: Byte
    
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
    init(color: Vector, gamma: Real = 2.2) {
        var m = clamp(color, min: 0, max: 1)

        let invGamma = 1.0 / gamma
        m.x = pow(m.x, invGamma)
        m.y = pow(m.y, invGamma)
        m.z = pow(m.z, invGamma)
        
        let c = m * Real(Byte.Max)
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
        ptr = VectorPointer.allocate(capacity: length)
        ray = RayPointer.allocate(capacity: length)
    }
    
    func cgImage() -> CGImage? {
        let ratio = 1.0 / Real(samples)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: length))
        let imageData = UnsafeMutablePointer<Pixel>(mutating: pixels.map({ Pixel(color: ($0 * ratio)) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        let bitmapContext = CGContext(data: imageData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue)
        if flip {
            bitmapContext?.translateBy(x: 0, y: CGFloat(height))
            bitmapContext?.scaleBy(x: 1.0, y: -1.0)
        }
        return bitmapContext?.makeImage()
    }

    func hitImage() -> CGImage? {
        let hits = UnsafeMutableBufferPointer<_Ray>(start: ray, count: length)
        let maxHits = 1 + hits.reduce(0) { max($0, $1.count) }
        let pixels: [Pixel] = hits.map({ hit in
            // reverse logarithmic scale for the hit count
            let r = Real(maxHits - hit.count) / Real(maxHits)
            let h = Real(2*M_PI) * r
            
            return Pixel(h: h, s: 0.6, v: 0.6) })
        let imageData = UnsafeMutablePointer<Pixel>(mutating: pixels)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        let bitmapContext = CGContext(data: imageData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue)
        if flip {
            bitmapContext?.translateBy(x: 0, y: CGFloat(height))
            bitmapContext?.scaleBy(x: 1.0, y: -1.0)
        }
        return bitmapContext?.makeImage()
    }
    
    func savePNG(_ name: String) -> String {
        let texture_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, name as CFString!, CFURLPathStyle.cfurlposixPathStyle, false)
        let dest = CGImageDestinationCreateWithURL(texture_url!, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(dest, self.cgImage()!, nil)
        let ok = CGImageDestinationFinalize(dest)
        if ok {
            print("png image written to path \(texture_url)")
            return String(describing: texture_url)
        } else {
            print("something went wrong")
            return String()
        }
    }
}

