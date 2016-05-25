//
//  Vector.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd
import Darwin

/// Currently an alias to CUnsignedChar
typealias byte = CUnsignedChar

/// Scalar is currently an alias for Double
public typealias Scalar = Double
extension Scalar {
    /// Assumed epsilon value
    static let epsilon : Scalar = Scalar(DBL_EPSILON)
}
public func ~= (a:Scalar, b:Scalar) -> Bool  { return abs(a-b) < Scalar.epsilon }

/// Vec is currenly an alias for simd.double3
public typealias Vec2 = simd.double2
public typealias Vec = simd.double3
extension Vec: CustomStringConvertible {
    /// Zero Vector
    static let Zero: Vec = Vec()
    /// Unit Vector
    static let Unit: Vec = Vec(1, 1, 1)
    /// XY Vector
    static let XY: Vec = Vec(1, 1, 0)
    /// Dot product
    func dot(b : Vec) -> Scalar { return simd.dot(self, b) }
    /// Normal vector
    func norm() -> Vec { return simd.normalize(self) }
    /// Lenght
    func len() -> Scalar { return simd.length(self) }
    /// Hash
    var hashValue:Int { return x.hashValue &+ (15 &* y.hashValue) &+ (127 &* z.hashValue) }
    /// Finite
    var isFinite: Bool { get { return self.x.isFinite && self.y.isFinite && self.z.isFinite } }
    
    init(_ s: Scalar) { self.init(s, s, s) }
    
    public var description: String { return "<\(x),\(y),\(z)>" }
}
//public func %  (a:Vec, b:Vec) -> Vec    { return simd.cross(a, b) }
public func == (a:Vec, b:Vec) -> Bool   { return (a.x == b.x) && (a.y == b.y) && (a.z == b.z) }
public func != (a:Vec, b:Vec) -> Bool   { return (a.x != b.x) && (a.y != b.y) && (a.z != b.z) }
public func ~= (a:Vec, b:Vec) -> Bool   { let c = simd.vector_abs(a-b); return c.x < Scalar.epsilon && c.y < Scalar.epsilon && c.z < Scalar.epsilon }
public func /  (lhs:Vec, rhs:Scalar) -> Vec { return lhs * (1.0 / rhs) }
public func /  (lhs:Scalar, rhs:Vec) -> Vec { return lhs * recip(rhs) }


/// Matrix class
typealias Matrix = double4x4
extension Matrix {
    static let Identity = Matrix(diagonal: Row(1, 1, 1, 1))
}

typealias Row = double4
typealias Col = double4
extension Col {
    static let Zero = Col(0, 0, 0, 0)
    
    init(_ v: Vec) { self.init(v.x, v.y, v.z, 1.0) }
}

extension Vec {
    init(_ c: Col) { self.init(c.x, c.y, c.z) }
}


