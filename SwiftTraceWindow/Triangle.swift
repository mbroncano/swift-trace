//
//  Triangle.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Geometric definition of a triangle
final class Triangle: Primitive {
    let p1, p2, p3: Vec
    let edge1, edge2: Vec
    let normal: Vec
    let t1, t2, t3: Vec
    let tu, tv: Vec
    // FIXME: add normals per vertex

    // TODO: precompute center
    override var center: Vec { get { return (edge2 + edge1) * 0.5 } }
    // same as bbox
//    override var area: Scalar { get { return edge1.len() * edge2.len() * 2.0 } }

    init(_ p1:Vec, _ p2:Vec, _ p3: Vec, _ material: MaterialId, _ t1:Vec = Vec(0, 0, 0), _ t2:Vec = Vec(0, 1, 0), _ t3:Vec = Vec(1, 0, 0)) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        
        // find vectors for two edges sharing V1
        edge1 = p2 - p1
        edge2 = p3 - p1
        normal = normalize(cross(edge1, edge2))
        
        self.t1 = t1
        self.t2 = t2
        self.t3 = t3
        // FIXME: maybe this is not ok
        self.tu = abs(t2 - t1)
        self.tv = abs(t3 - t1)
        
        // compute bounding box
        let _min = min(min(p1, p2), min(p2, p3))
        let _max = max(max(p1, p2), max(p2, p3))

        let aabb = AABB(a: _min, b: _max)
        super.init(bbox: aabb, material: material)
    }

    convenience init(p1:Vec, p2:Vec, p3: Vec, material: MaterialId) {
        self.init(p1, p2, p3, material)
    }

    /// https://en.wikipedia.org/wiki/Möller–Trumbore_intersection_algorithm
    func intersectWithRay(ray ray: RayPointer) -> (Scalar, Scalar, Scalar) {
        // begin calculating determinant - also used to calculate u parameter
        let p = cross(ray.memory.d, edge2)
        
        // compute the determinant
        let det = dot(edge1, p)
        
        // the triangle is degenerate (i.e. lies on the plane of triangle)
        if (det > -Scalar.epsilon && det < Scalar.epsilon) { return (Scalar.infinity, 0, 0) }

        // we will use the inverse from now on
        let inv_det = 1.0 / det;

        // calculate distance from the first vertex to ray origin
        let t = ray.memory.o - p1
        
        // calculate u parameter and test bound
        let u = dot(t, p) * inv_det

        //The intersection lies outside of the triangle
        if (u < 0.0 || u > 1.0) { return (Scalar.infinity, 0, 0) }

        // prepare to test v parameter
        let q = cross(t, edge1)

        // calculate v parameter and test bound
        let v = dot(ray.memory.d, q) * inv_det;
        
        // the intersection lies outside of the triangle
        if v < 0.0 || (u+v) > 1.0 { return (Scalar.infinity, 0, 0) }

        // compute distance
        let d = dot(edge2, q) * inv_det;

        // check that the distance fits the ray boundaries
        guard d > ray.memory.tmin && d < ray.memory.tmax else { return (Scalar.infinity, 0, 0) }

        // return the distance andthe u,v parameters
        return (d, u, v)
    }
    
    override func intersectWithRay(ray ray: RayPointer) -> Scalar {
        let d: Scalar
        (d, _, _) = intersectWithRay(ray: ray)
        
        return d
    }
    
    override func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool {
        let d, u, v: Scalar
        (d, u, v) = intersectWithRay(ray: ray)
        
        if (d < hit.memory.d) {
            hit.memory.p = self
            hit.memory.d = d
            hit.memory.x = ray.memory.o + ray.memory.d * d
            hit.memory.m = material!
            hit.memory.n = normal
            hit.memory.uv = tu * u + tv * v
        }
        
        return d != Scalar.infinity
    }
}