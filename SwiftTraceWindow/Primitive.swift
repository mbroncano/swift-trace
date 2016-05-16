//
//  Primitive.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

struct _Sphere {
    let rad: Scalar         // radius
    let p: Vec              // position
}

struct _Triangle {
    let p1, p2, p3: Vec     // vertices
    let normal: Vec         // normal
    
    init(p1: Vec, p2: Vec, p3: Vec) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        normal = normalize(cross(p2 - p1, p3 - p1))
    }
}

// Advantage over structs + protocol: Equatable, homogeneus
// Cons: can't find a way to store precomputed values e.g. normal, edges
// Best of both worlds (tm): passing a struct to the enum, it's cumbersome though
// Rational is, there is not really a base class required functionality
// but just a virtual base class (not really a swift thing) 
// I tried three options for modelling this
// a) struct + protocols: problems with comparing, copy overhead (solved with passing ids around)
// b) classes: dynamic dispatch overhead, mutability
// c) enums + struct: cumbersome to initialize
// d) enums: cannot store precomputed properties
enum Primitive {
    case Sphere(rad: Scalar, p: Vec)
    case Triangle(p1: Vec, p2:Vec, p3: Vec)
    
    func intersectWithRay(r: Ray) -> Scalar {
        switch(self) {
        case let .Sphere(rad, p): return intersectSphereWithRay(r, p: p, rad: rad)
        case let .Triangle(p1, p2, p3): return intersectTriangleWithRay(r, p1: p1, p2: p2, p3: p3)
        }
    }
    
    func normalAtPoint(x: Vec) -> Vec {
        switch (self) {
        case let .Sphere(_, p): return normalize(x - p)
        case let .Triangle(p1, p2, p3): return normalize(cross(p2 - p1, p3 - p1))
        }
    }
}

class Element {
    let p: Primitive
    let m: Material
    
    init(p: Primitive, m: Material) {
        self.p = p
        self.m = m
    }
}

typealias ElementId = Int
extension ElementId {
    static var Invalid = -1
    var IsInvalid: Bool { get { return self == .Invalid } }
    
    init() { self = .Invalid }
}

struct ElementList {
    let list: [Element]
    
    func intersectWithRay(r: Ray) -> (Scalar, ElementId) {
        var ret = (dist: Scalar.infinity, id: ElementId.Invalid)
        
        for id in 0..<list.count {
            let dist = list[id].p.intersectWithRay(r)
            if dist < ret.dist {
                ret = (dist, id)
            }
        }
        
        return ret
    }
    
    subscript(id: ElementId) -> Element? { return list[id] }
}

/// https://en.wikipedia.org/wiki/Line–sphere_intersection
func intersectSphereWithRay(r: Ray, p: Vec, rad: Scalar) -> Scalar {
    // solves the cuadratic equation
    let po = r.o - p
    let b = dot(r.d, po)
    let c = dot(po, po) - (rad * rad)
    let d = b*b - c
    
    // If the determinant is negative, there are not solutions
    if (d < 0) { return Scalar.infinity }
    
    // check the solutions
    let s = sqrt(d)
    let q = (b < 0) ? (-b-s) : (-b+s)
    let t = (q > Scalar.epsilon) ? q : 0
    
    if (t == 0) { return Scalar.infinity }
    
    return t
}

/// https://en.wikipedia.org/wiki/Möller–Trumbore_intersection_algorithm
func intersectTriangleWithRay(r: Ray, p1: Vec, p2: Vec, p3: Vec) -> Scalar {
    // tradeoff: compute or cache these
    let edge1 = p2 - p1
    let edge2 = p3 - p1

    //Begin calculating determinant - also used to calculate u parameter
    let p = cross(r.d, edge2)
    //if determinant is near zero, ray lies in plane of triangle
    let det = dot(edge1, p)
    // NOT CULLING
    if (det > -Scalar.epsilon && det < Scalar.epsilon) { return Scalar.infinity }
    
    let inv_det = 1.0 / det;
    
    //calculate distance from V1 to ray origin
    let d = r.o - p1
    //Calculate u parameter and test bound
    let u = dot(d, p) * inv_det
    
    //The intersection lies outside of the triangle
    if (u < 0.0 || u > 1.0) { return Scalar.infinity }
    
    //Prepare to test v parameter
    let q = cross(d, edge1)
    
    //Calculate V parameter and test bound
    let v = dot(r.d, q) * inv_det;
    //The intersection lies outside of the triangle
    if (v < 0.0 || u + v  > 1.0) { return Scalar.infinity }
    
    let d1 = dot(edge2, q) * inv_det;
    
    if (d1 > Scalar.epsilon) { //ray intersection
        return d1
    }
    
    // No hit, no win
    return Scalar.infinity
}



