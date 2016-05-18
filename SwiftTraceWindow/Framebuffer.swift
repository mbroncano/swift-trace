//
//  Framebuffer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd



struct Texture {
    let pixels: UnsafeMutablePointer<PixelRGBA>
    let width, height, bytesPerRow, bitsPerPixel: Int
    
    init?(fileName: String) {
        guard
            let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, fileName, CFURLPathStyle.CFURLPOSIXPathStyle, false),
            let source = CGDataProviderCreateWithURL(url),
            let image = CGImageCreateWithJPEGDataProvider(source, nil, false, CGColorRenderingIntent.RenderingIntentDefault)
            else { return nil }
        
        width = CGImageGetWidth(image)
        height = CGImageGetHeight(image)
        bytesPerRow = CGImageGetBytesPerRow(image)
        bitsPerPixel = CGImageGetBitsPerPixel(image)
        pixels = UnsafeMutablePointer<PixelRGBA>.alloc(width*height)
        
        let space = CGImageGetColorSpace(image)
        let bitmapInfo = CGImageGetBitmapInfo(image)
        guard
            let context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, space, bitmapInfo.rawValue)
            else { return nil }
        
        CGContextDrawImage(context, CGRect(x: 0, y: 0, width: width, height: height), image)
        CGContextFlush(context)
    }

    subscript(textCoord: Vec) -> Color {
        get {
            let x = Int(textCoord.x*Scalar(width)) % width
            let y = Int(textCoord.y*Scalar(height)) % height
            let ofs = (x + y * width)
            let pixel = pixels[ofs] //PixelRGBA(a: pixels[ofs], r: pixels[ofs+1], g: pixels[ofs+2], b: pixels[ofs+3])

            return pixel.color()
        }
    }
}

class Framebuffer {
    let width:Int, height: Int
    //var pixels: [Color]
    var samples: Int = 0
    let ptr: UnsafeMutablePointer<Color>
    
    init(width: Int, height:Int) {
        self.width = width
        self.height = height
        
        //pixels = Array<Color>(count: width*height, repeatedValue: Color())
        ptr = UnsafeMutablePointer<Color>.alloc(width*height)
    }

    subscript(x:Int, y:Int) -> Color {
        get { return ptr[(height - y - 1) * width + x] }
        set { ptr[(height - y - 1) * width + x] = newValue }
    }
    
    func cgImage() -> CGImage {
        let ratio : Scalar = 1 / Scalar(samples)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: width*height))
        let imageData : UnsafeMutablePointer<PixelRGBA> = UnsafeMutablePointer(pixels.map({ (color) -> PixelRGBA in PixelRGBA(color: (color * ratio).gammaCorrected()) }))
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
        let bitmapContext = CGBitmapContextCreate(imageData, width, height, 8, width * 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)
        //CGContextTranslateCTM(bitmapContext, 0, CGFloat(height))
        //CGContextScaleCTM(bitmapContext, 1.0, -1.0)
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

