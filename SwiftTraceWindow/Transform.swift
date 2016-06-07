//
//  Transform.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

typealias Matrix = simd.double4x4
typealias Row = simd.double4

extension Vector {
    init(_ v: Row) { self.init(v[0], v[1], v[2]) }
}

extension Matrix {
    static let Identity = Matrix(diagonal: Row(1, 1, 1, 1))
    
    var submatrix: double3x3 { get {
        let v1 = Vector(self[0])
        let v2 = Vector(self[1])
        let v3 = Vector(self[2])
    
        return double3x3([v1, v2, v3])
        }}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Axis aligned bounding box

struct Transform {
    /// Matrix that contains the transform
    let transform: Matrix
    /// Matrix that contains the inverse of the transform
    let inverse: Matrix
    
    let isIdentity: Bool
    static let Identity = Transform(transform: Matrix.Identity, inverse: Matrix.Identity, isIdentity: true)

    /// Whether the transformation will change handeness
    var swapsHandeness: Bool { get {
        // FIXME: precompute this
        return simd.matrix_determinant(transform.submatrix.cmatrix) < 0
    }}
    
    /// Returns the reverse transform
    func reverse() -> Transform {
        return Transform(transform: self.inverse, inverse: self.transform)
    }
    
    init(transform: Matrix, inverse: Matrix, isIdentity: Bool = false) {
        self.transform = transform
        self.inverse = inverse
        // FIXME: check this is the case
        self.isIdentity = isIdentity
    }
    
    /// Translation transform
    init(translate t: Vector) {
        self.init(
            transform: Matrix([
                Row(1, 0, 0, t.x),
                Row(0, 1, 0, t.y),
                Row(0, 0, 1, t.z),
                Row(0, 0, 0, 1),
                ]),
            inverse: Matrix([
                Row(1, 0, 0, -t.x),
                Row(0, 1, 0, -t.y),
                Row(0, 0, 1, -t.z),
                Row(0, 0, 0, 1),
                ]))
    }

    /// Scaling transform
    init(scale s: Vector) {
        let t = Matrix([
                Row(s.x, 0, 0, 0),
                Row(0, s.y, 0, 0),
                Row(0, 0, s.z, 0),
                Row(0, 0, 0, 1)])
        let i = Matrix([
                Row(1.0/s.x, 0, 0, 0),
                Row(0, 1.0/s.y, 0, 0),
                Row(0, 0, 1.0/s.z, 0),
                Row(0, 0, 0, 1)])
    
        self.init(transform: t, inverse: i)
    }
    
    /// Rotation around X axis transform
    init(rotate_x a: Real) {
        let c: Real = cos(a)
        let s: Real = sin(a)
        let m = Matrix([
            Row(1, 0, 0, 0),
            Row(0, c,-s, 0),
            Row(0, s, c, 0),
            Row(0, 0, 0, 1)])
        
        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around Y axis transform
    init(rotate_y a: Real) {
        let c: Real = cos(a)
        let s: Real = sin(a)
        let m = Matrix([
            Row(c, 0, s, 0),
            Row(0, 1, 0, 0),
            Row(-s,0, c, 0),
            Row(0, 0, 0, 1)])

        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around Z axis transform
    init(rotate_z a: Real) {
        let c: Real = cos(a)
        let s: Real = sin(a)
        let m = Matrix([
            Row(c,-s, 0, 0),
            Row(s, c, 0, 0),
            Row(0, 0, 1, 0),
            Row(0, 0, 0, 1)])
        
        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around a general axis transform
    init(rotate_a a: Real, r: Vector) {
        let r = normalize(r)
        let s = sin(a)
        let c = cos(a)
        let m = Matrix([
            Row(r.x*r.x+(1-r.x*r.x)*c, r.x*r.y*(1-c)-r.z*s,   r.x*r.z*(1-c)*r.y*s,   0),
            Row(r.x*r.y*(1-c)-r.z*s,   r.y*r.y*(1-r.y*r.y)*c, r.y*r.z*(1-c)-r.x*s,   0),
            Row(r.x*r.z*(1-c)-r.y*s,   r.y*r.z*(1-c)+r.x*s,   r.z*r.z*(1-r.z*r.z)*c, 0),
            Row(0, 0, 0, 1)])
        
        self.init(transform: m, inverse: m.transpose)
    }

    /// Camera transform
    init(from: Vector, to: Vector, up: Vector) {
        let dir = normalize(to - from)
        let left = normalize(cross(dir, normalize(up))) // do we really have to normalize again?
        let up = cross(dir, left)
        let m = Matrix([
            Row(left.x, up.x, dir.x, from.x),
            Row(left.y, up.y, dir.y, from.y),
            Row(left.z, up.z, dir.z, from.z),
            Row(0, 0, 0, 1)])
            
        self.init(transform: m, inverse: m.transpose)
    }

    /// Apply the transform to a normal vector
    /// Please note that in order to maintain the orthogonatility
    /// to the tangent, we need to compute it in a different way
    func apply(normal n: Vector) -> Vector {
        let r = Row(n.x, n.y, n.z, 0.0) * inverse.transpose
        return Vector(r.x, r.y, r.z)
    }

    /// Apply the transform to a vector
    func apply(vector v: Vector) -> Vector {
        let r = Row(v.x, v.y, v.z, 0.0) * transform
        return Vector(r.x, r.y, r.z)
    }
    
    /// Apply the transform to a point
    /// Please note that we need to scale by the homogeneus component
    func apply(point p: Vector) -> Vector {
        let r = Row(p.x, p.y, p.z, 1.0) * transform
        return Vector(r.x, r.y, r.z) * (1/r.w)
    }
}

/// Compose operation
/// Please note inv(A*B) = inv(B) * inv(A)
func + (lhs:Transform, rhs: Transform) -> Transform {
    let mat = lhs.transform * rhs.transform
    let inv = rhs.inverse * lhs.inverse
    return Transform(transform: mat, inverse: inv)
}

func ==(lhs: Transform, rhs: Transform) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension Transform: Equatable {
    internal var hashValue: Int { get {
        let (c0, c1, c2, c3) = transform.cmatrix.columns
        
        return
            unsafeBitCast(c0.x, Int64.self).hashValue ^
            unsafeBitCast(c0.y, Int64.self).hashValue ^
            unsafeBitCast(c0.z, Int64.self).hashValue ^
            unsafeBitCast(c0.w, Int64.self).hashValue ^
            unsafeBitCast(c1.x, Int64.self).hashValue ^
            unsafeBitCast(c1.y, Int64.self).hashValue ^
            unsafeBitCast(c1.z, Int64.self).hashValue ^
            unsafeBitCast(c1.w, Int64.self).hashValue ^
            unsafeBitCast(c2.x, Int64.self).hashValue ^
            unsafeBitCast(c2.y, Int64.self).hashValue ^
            unsafeBitCast(c2.z, Int64.self).hashValue ^
            unsafeBitCast(c2.w, Int64.self).hashValue ^
            unsafeBitCast(c3.x, Int64.self).hashValue ^
            unsafeBitCast(c3.y, Int64.self).hashValue ^
            unsafeBitCast(c3.z, Int64.self).hashValue ^
            unsafeBitCast(c3.w, Int64.self).hashValue
    }}
}