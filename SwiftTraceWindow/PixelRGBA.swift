//
//  PixelRGBA.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

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

public func == (a:Pixel, b:Pixel) -> Bool { return a.a == b.a && a.r == b.r && a.g == b.g && a.b == b.b }
