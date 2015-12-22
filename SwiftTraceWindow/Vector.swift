//
//  Vector.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd
import Darwin

/// Scalar is currently an alias for Double
public typealias Scalar = Double
extension Scalar {
    /// Assumed epsilon value
    static let epsilon : Scalar = Scalar(FLT_EPSILON)
}
public func ~= (a:Scalar, b:Scalar) -> Bool  { return abs(a-b) < Scalar.epsilon }

/// Vec is currenly an alias for simd.double3
public typealias Vec2 = simd.double2
public typealias Vec = simd.double3
extension Vec {
    /// Zero Vector
    static let Zero: Vec = Vec()
    /// Unit Vector
    static let Unit: Vec = Vec(1, 1, 1)
    /// Dot product
    func dot(b : Vec) -> Scalar { return simd.dot(self, b) }
    /// Normal vector
    func norm() -> Vec { return simd.normalize(self) }
}
//public func %  (a:Vec, b:Vec) -> Vec    { return simd.cross(a, b) }
public func == (a:Vec, b:Vec) -> Bool   { return (a.x == b.x) && (a.y == b.y) && (a.z == b.z) }
public func != (a:Vec, b:Vec) -> Bool   { return (a.x != b.x) && (a.y != b.y) && (a.z != b.z) }
public func ~= (a:Vec, b:Vec) -> Bool   { let c = simd.vector_abs(a-b); return c.x < Scalar.epsilon && c.y < Scalar.epsilon && c.z < Scalar.epsilon }

/// Structure containing two vector, origin and destination
public struct Ray {
    /// The origin vector
    let o: Vec
    /// The destination vector
    let d: Vec
}
public func * (a:Ray, b:Scalar) -> Vec { return a.o + a.d * b }

/// Color is currently an alias for simd.double3
typealias Color = Vec
extension Color {
    /// The color red
    static let Red  =  Color(1, 0, 0)
    /// The color green
    static let Green = Color(0, 1, 0)
    /// The color blue
    static let Blue  = Color(0, 0, 1)
    /// The color white
    static let White = Color(1, 1, 1)
    /// The color black
    static let Black = Color(0, 0, 0)

    func gammaCorrected() -> Color {
        let gamma = 0.45
        return Color(pow(x, gamma), pow(y, gamma), pow(z, gamma))
    }
}

/// Currently an alias to CUnsignedChar
typealias byte = CUnsignedChar

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
        self.r = byte(min(color.x, 1.0) * Scalar(byte.max))
        self.g = byte(min(color.y, 1.0) * Scalar(byte.max))
        self.b = byte(min(color.z, 1.0) * Scalar(byte.max))
        self.a = 0
    }
}

public func == (a:PixelRGBA, b:PixelRGBA) -> Bool { return a.a == b.a && a.r == b.r && a.g == b.g && a.b == b.b }
