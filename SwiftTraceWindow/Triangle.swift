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

    /// Material identifier
    let material: MaterialId

    // TODO: precompute center
    override var center: Vec { get { return (edge2 + edge1) * 0.5 } }
    // same as bbox
//    override var area: Scalar { get { return edge1.len() * edge2.len() * 2.0 } }

    init(_ p1:Vec, _ p2:Vec, _ p3: Vec, _ material: MaterialId, _ t1:Vec = Vec(0, 0, 0), _ t2:Vec = Vec(0, 1, 0), _ t3:Vec = Vec(1, 0, 0)) {
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
        
        self.material = material
    
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
        super.init(bbox: AABB(a: _min, b: _max))
    }

    convenience init(p1:Vec, p2:Vec, p3: Vec, material: MaterialId) {
        self.init(p1, p2, p3, material)
    }
    
    /// https://en.wikipedia.org/wiki/Möller–Trumbore_intersection_algorithm
    override func intersectWithRay(ray ray: RayPointer, hit: IntersectionPointer) -> Bool {
        let r = ray.memory
    
        // begin calculating determinant - also used to calculate u parameter
        let p = cross(r.d, edge2)
        
        // if determinant is near zero, ray lies in plane of triangle
        let det = dot(edge1, p)
        
        // NOT CULLING
        if (det > -Scalar.epsilon && det < Scalar.epsilon) { return false }

        let inv_det = 1.0 / det;

        //calculate distance from V1 to ray origin
        let t = r.o - p1
        //Calculate u parameter and test bound
        let u = dot(t, p) * inv_det

        //The intersection lies outside of the triangle
        if (u < 0.0 || u > 1.0) { return false }

        //Prepare to test v parameter
        let q = cross(t, edge1)

        //Calculate V parameter and test bound
        let v = dot(r.d, q) * inv_det;
        //The intersection lies outside of the triangle
        if (v < 0.0 || u + v  > 1.0) { return false }

        let d = dot(edge2, q) * inv_det;

        if (d > Scalar.epsilon) { //ray intersection
            if (d < hit.memory.d) {
                hit.memory.p = self
                hit.memory.d = d
                hit.memory.x = r.o + r.d * d
                hit.memory.m = material
                hit.memory.n = normal
                hit.memory.uv = tu * u + tv * v
            }
            return true
        }

        // No hit, no win
        return false
    }
    /*
    override func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {

        // find vectors for two edges sharing p1
        // let edge1 = p2 - p1
        // let edge2 = p3 - p1

        // compute some initial values
        let distance: Vec = r.o - p1
        let s: Vec = cross(r.d, edge2)
        let d: Scalar = simd.recip(dot(s, edge1))

        // calculate the first barycentric coordinate
        let u: Scalar = dot(distance, s) * d;

        // reject the intersection if the barycentric coordinate is out of range
        guard u <= -Scalar.epsilon || u >= (1 + Scalar.epsilon) else { return false }

        // calculate the second barycentric coordinate
        let t: Vec = cross(distance, edge1)
        let v: Scalar = dot(r.d, t) * d

        // reject the intersection if the barycentric coordinate is out of range
        guard v <= -Scalar.epsilon || (u + v) >= (1 + Scalar.epsilon) else { return false }

        // compute the final intersection point
        let dist: Scalar = dot(edge2, t) * d
        
        if (dist < hit.d) {
            hit.p = self
            hit.d = dist

            let x = r.o + r.d * dist
            
            hit.x = x
            hit.m = material
            hit.n = normal
            hit.uv = Vec(u, v, 0)
        }
        
        return true
    }
    */
    /*
    func normalAtPoint(x: Vec) -> Vec {
        return normal
    }
    
    func sampleSurface() -> Vec {
        let r1 = Random.random()
        let r2 = Random.random()
        
        let p = (1 - sqrt(r1)) * p1 + (sqrt(r1) * (1 - r2)) * p2 + (r2 * sqrt(r1)) * p3
        
        return p
    }

    // TODO
    func textureAtPoint(x: Vec) -> Vec {
        return Vec()
    }*/
}