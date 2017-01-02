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

enum TextureError: Error {
    case invalidFile(String)
}

struct Texture {
    let pixels: UnsafeMutablePointer<Pixel>
    let width, height, bytesPerRow, bitsPerPixel: Int
    
    init(name: String) throws {
        guard
        let path = Bundle.main.path(forResource: name, ofType: ""),
        let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
        let source = CGDataProvider(data: data as CFData)
        else { throw TextureError.invalidFile("file <\(name)> not found or invalid") }

        let image: CGImage?
        let ext = NSString(string: path).pathExtension
        switch ext {
            case "jpg":
                image = CGImage(jpegDataProviderSource: source, decode: nil, shouldInterpolate: false, intent: CGColorRenderingIntent.defaultIntent)
            case "png":
                image = CGImage(pngDataProviderSource: source, decode: nil, shouldInterpolate: false, intent: CGColorRenderingIntent.defaultIntent)
            default:
                throw TextureError.invalidFile("extension <\(ext)> is not supported")
        }
        
        width = (image?.width)!
        height = (image?.height)!
        bytesPerRow = (image?.bytesPerRow)!
        bitsPerPixel = (image?.bitsPerPixel)!
        pixels = UnsafeMutablePointer<Pixel>.allocate(capacity: width*height)
        
        let space = image?.colorSpace
        let bitmapInfo = image?.bitmapInfo
        let alphaInfo = CGImageAlphaInfo.premultipliedLast //CGImageGetAlphaInfo(image)
        guard let context = CGContext(data: pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space!, bitmapInfo: (bitmapInfo?.rawValue)! | alphaInfo.rawValue)
        else { throw TextureError.invalidFile("unsupported file format") }
        
        context.draw(image!, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.flush()
    }

    subscript(textCoord: Vector) -> Pixel { get {
            let x = Int(textCoord.x*Real(width)) % width
            let y = Int(textCoord.y*Real(height)) % height
            let ofs = (x + y * width)
            return pixels[ofs]
        }
    }
}
