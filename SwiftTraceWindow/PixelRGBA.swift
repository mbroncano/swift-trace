//
//  PixelRGBA.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/// Structure containing a RGBA pixel
public struct PixelRGBA: Equatable {
    /// Alpha, Red, Green, Blue
    private let a, r, g, b: byte
    
    /// Default initializer with all four members
    init(a: byte, r: byte, g: byte, b: byte) {
        self.a = a
        self.r = r
        self.g = g
        self.b = b
    }
    
    /// Default initializer with Color type
    /// -Parameter color: Color type variable
    init(color: Color) {
        let c = min(color, 1.0) * Scalar(byte.max)
        (r, g, b, a) = (byte(c.x), byte(c.y), byte(c.z), 0)
    }
    
    /// Return Color vector
    func color() -> Color {
        return Color(Scalar(self.r), Scalar(self.g), Scalar(self.b)) * (1.0 / Scalar(byte.max))
    }
}

public func == (a:PixelRGBA, b:PixelRGBA) -> Bool { return a.a == b.a && a.r == b.r && a.g == b.g && a.b == b.b }
