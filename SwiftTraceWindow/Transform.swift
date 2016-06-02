//
//  Transform.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

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
    init(translate t: Vec) {
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
    init(scale s: Vec) {
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
    init(rotate_x a: Scalar) {
        let c: Scalar = cos(a)
        let s: Scalar = sin(a)
        let m = Matrix([
            Row(1, 0, 0, 0),
            Row(0, c,-s, 0),
            Row(0, s, c, 0),
            Row(0, 0, 0, 1)])
        
        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around Y axis transform
    init(rotate_y a: Scalar) {
        let c: Scalar = cos(a)
        let s: Scalar = sin(a)
        let m = Matrix([
            Row(c, 0, s, 0),
            Row(0, 1, 0, 0),
            Row(-s,0, c, 0),
            Row(0, 0, 0, 1)])

        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around Z axis transform
    init(rotate_z a: Scalar) {
        let c: Scalar = cos(a)
        let s: Scalar = sin(a)
        let m = Matrix([
            Row(c,-s, 0, 0),
            Row(s, c, 0, 0),
            Row(0, 0, 1, 0),
            Row(0, 0, 0, 1)])
        
        self.init(transform: m, inverse: m.transpose)
    }

    /// Rotation around a general axis transform
    init(rotate_a a: Scalar, r: Vec) {
        let r = r.norm()
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
    init(from: Vec, to: Vec, up: Vec) {
        let dir = (to - from).norm()
        let left = (dir % up.norm()).norm() // do we have to normalize again?
        let up = dir % left
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
    func apply(normal n: Vec) -> Vec {
        let r = Col(n.x, n.y, n.z, 0.0) * inverse.transpose
        return Vec(r.x, r.y, r.z)
    }

    /// Apply the transform to a vector
    func apply(vector v: Vec) -> Vec {
        let r = Col(v.x, v.y, v.z, 0.0) * transform
        return Vec(r.x, r.y, r.z)
    }
    
    /// Apply the transform to a point
    /// Please note that we need to scale by the homogeneus component
    func apply(point p: Vec) -> Vec {
        let r = Col(p.x, p.y, p.z, 1.0) * transform
        return Vec(r.x, r.y, r.z) / r.w
    }

    /// Apply the transform to a ray
    /// By default this is the *inverse* transform
    func apply(ray r: Ray) -> Ray {
        return Ray(o: apply(point: r.o), d: apply(vector: r.d), tmin: r.tmin, tmax: r.tmax)
    }
    
    func apply(array: [Triangle]) -> [Triangle] {
        return array.map({ t in self.apply(t) })
    }

    func apply(t: Triangle) -> Triangle {
        let p1 = self.apply(point: t.p1)
        let p2 = self.apply(point: t.p2)
        let p3 = self.apply(point: t.p3)
        
        return Triangle(p1, p2, p3, t.material!, t.t1, t.t2, t.t3)
    }

    func apply(s: Sphere) -> Sphere {
        let p = self.apply(point: s.p)
        let r = self.apply(vector: Vec(s.rad).norm()) // rad should be a vector
        
        return Sphere(rad: r.len(), p: p, material: s.material!)
    }
}

/// Compose operation
/// Please note inv(A*B) = inv(B) * inv(A)
func + (lhs:Transform, rhs: Transform) -> Transform {
    let mat = lhs.transform * rhs.transform
    let inv = rhs.inverse * lhs.inverse
    return Transform(transform: mat, inverse: inv)
}
