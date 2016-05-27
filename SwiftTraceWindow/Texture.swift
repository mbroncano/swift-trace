//
//  Texture.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/26/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

typealias TextureId = String

enum TextureError: ErrorType {
    case InvalidFile(String)
}

struct Texture {
    let pixels: UnsafeMutablePointer<PixelRGBA>
    let width, height, bytesPerRow, bitsPerPixel: Int
    
    init(name: String) throws {
        guard
        let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
        let data = NSData(contentsOfFile: path),
        let source = CGDataProviderCreateWithCFData(data)
        else { throw TextureError.InvalidFile("file <\(name)> not found or invalid") }

        let image: CGImage?
        let ext = NSString(string: path).pathExtension
        switch ext {
            case "jpg":
                image = CGImageCreateWithJPEGDataProvider(source, nil, false, CGColorRenderingIntent.RenderingIntentDefault)
            case "png":
                image = CGImageCreateWithPNGDataProvider(source, nil, false, CGColorRenderingIntent.RenderingIntentDefault)
            default:
                throw TextureError.InvalidFile("extension <\(ext)> is not supported")
        }
        
        width = CGImageGetWidth(image)
        height = CGImageGetHeight(image)
        bytesPerRow = CGImageGetBytesPerRow(image)
        bitsPerPixel = CGImageGetBitsPerPixel(image)
        pixels = UnsafeMutablePointer<PixelRGBA>.alloc(width*height)
        
        let space = CGImageGetColorSpace(image)
        let bitmapInfo = CGImageGetBitmapInfo(image)
        let alphaInfo = CGImageAlphaInfo.PremultipliedLast //CGImageGetAlphaInfo(image)
        guard let context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, space, bitmapInfo.rawValue | alphaInfo.rawValue)
        else { throw TextureError.InvalidFile("unsupported file format") }
        
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
