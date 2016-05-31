//
//  Vector.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd
import Darwin

/// Double types have better performance
public typealias Vec = simd.double3
public typealias Scalar = Double
typealias Matrix = simd.double4x4
typealias Col = simd.double4
typealias Row = simd.double4
typealias byte = CUnsignedChar

/// Scalar is currently an alias for Double
extension Scalar {
    /// Assumed epsilon value
    static let epsilon = Scalar(DBL_EPSILON)
    /// Precomputed values for pi
    static let pi = Scalar(M_PI)
    static let pi2 = Scalar(2*M_PI)
    static let pi4 = Scalar(4*M_PI)
}
public func ~= (a:Scalar, b:Scalar) -> Bool  { return abs(a-b) < Scalar.epsilon }

/// Vec is currenly an alias for simd.double3
extension Vec: CustomStringConvertible {
    /// Zero Vector
    static let Zero: Vec = Vec()
    /// Unit Vector
    static let Unit: Vec = Vec(1.0)
    /// XY Vector
    static let XY: Vec = Vec(1.0, 1.0, 0.0)
    /// Infinity
    static let infinity: Vec = Vec(Scalar.infinity)
    
    /// Dot product
    func dot(b : Vec) -> Scalar { return simd.dot(self, b) }
    /// Normal vector
    func norm() -> Vec { return simd.normalize(self) }
    /// Lenght
    func len() -> Scalar { return simd.length(self) }
    /// Lenght sqaured
    func len2() -> Scalar { return simd.length_squared(self) }
    /// Hash
    var hashValue:Int { return x.hashValue &+ (15 &* y.hashValue) &+ (127 &* z.hashValue) }
    /// Finite
    var isFinite: Bool { get { return self.x.isFinite && self.y.isFinite && self.z.isFinite } }
    /// Local coordinate system
    var localCoordinate: (Vec, Vec) { get {
        let v1 = self
        let v2 = v1.x > v1.y ? Vec(-v1.z, 0.0, v1.x) : Vec(0.0, v1.z, -v1.y)
        let v3 = v2.norm() % v1
        return (v2, v3)
    }}
    
    public var description: String { return "<\(x),\(y),\(z)>" }
}

public func %  (a:Vec, b:Vec) -> Vec  { return simd.cross(a, b) }
public func == (a:Vec, b:Vec) -> Bool { return (a.x == b.x) && (a.y == b.y) && (a.z == b.z) }
public func != (a:Vec, b:Vec) -> Bool { return (a.x != b.x) && (a.y != b.y) && (a.z != b.z) }
public func ~= (a:Vec, b:Vec) -> Bool { return simd.reduce_max(simd.vector_abs(a-b)) < Scalar.epsilon }
public func /  (lhs:Vec, rhs:Scalar) -> Vec { return lhs * (1.0 / rhs) }
public func /  (lhs:Scalar, rhs:Vec) -> Vec { return lhs * recip(rhs) }


extension Vec {
    init(_ v: double4) { self.init(v[0], v[1], v[2]) }
}

/// Matrix class
extension Matrix {
    static let Identity = Matrix(diagonal: Row(1, 1, 1, 1))
    
    var submatrix: double3x3 { get {
        let v1 = Vec(self[0])
        let v2 = Vec(self[1])
        let v3 = Vec(self[2])
    
        return double3x3([v1, v2, v3])
        }}
}


