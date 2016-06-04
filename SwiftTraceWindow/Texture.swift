//
//  Texture.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/26/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

typealias TextureId = Int
extension TextureId {
    init(texture: String) { self = texture.hashValue }
}

enum TextureError: ErrorType {
    case InvalidFile(String)
}

struct Texture {
    let pixels: UnsafeMutablePointer<Pixel>
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
        pixels = UnsafeMutablePointer<Pixel>.alloc(width*height)
        
        let space = CGImageGetColorSpace(image)
        let bitmapInfo = CGImageGetBitmapInfo(image)
        let alphaInfo = CGImageAlphaInfo.PremultipliedLast //CGImageGetAlphaInfo(image)
        guard let context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, space, bitmapInfo.rawValue | alphaInfo.rawValue)
        else { throw TextureError.InvalidFile("unsupported file format") }
        
        CGContextDrawImage(context, CGRect(x: 0, y: 0, width: width, height: height), image)
        CGContextFlush(context)
    }

    subscript(textCoord: Vector) -> Pixel { get {
            let x = Int(textCoord.x*Real(width)) % width
            let y = Int(textCoord.y*Real(height)) % height
            let ofs = (x + y * width)
            return pixels[ofs]
        }
    }
}
