//
//  AABB.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Axis aligned bounding box

struct AABB: IntersectWithRayBoolean, Surface, Equatable, Comparable {
    let bmin, bmax: Vec
    
    let area: Scalar
    let center: Vec
    let volume: Scalar
    
    init(a: Vec, b: Vec) {
        self.bmin = a
        self.bmax = b
        
        let d = bmax - bmin
        self.center = bmin + d * 0.5
        self.area = 2.0 * d.len2()
        self.volume = d.x * d.y * d.z
    }

    init() { self.init(a: Vec.infinity, b: -Vec.infinity) }

    // TODO
    func sample() -> Vec { return self.center }

    func intersectWithRay(ray ray: RayPointer) -> Scalar {
        let t1 = (bmin - ray.memory.o) * ray.memory.inv
        let t2 = (bmax - ray.memory.o) * ray.memory.inv
        
        let tmin = simd.reduce_max(simd.min(t1, t2))
        let tmax = simd.reduce_min(simd.max(t1, t2))
 
        return tmax >= tmin ? tmin : Scalar.infinity
    }

    func intersectWithRay(ray ray: RayPointer) -> Bool {

        // This works (tested!)
//        var tmin = -Scalar.infinity
//        var tmax = Scalar.infinity
// 
//        for i in 0...2 {
//            if r.d[i] != 0.0 {
//                let t1 = (bmin[i] - r.o[i])/r.d[i];
//                let t2 = (bmax[i] - r.o[i])/r.d[i];
//                
//                tmin = max(tmin, min(t1, t2));
//                tmax = min(tmax, max(t1, t2));
//            } else if (r.o[i] <= bmin[i] || r.o[i] >= bmax[i]) {
//                return false
//            }
//        }
//        return tmax >= tmin && tmax >= 0.0
        
        // This works faster (SIMD)
        let t1 = (bmin - ray.memory.o) * ray.memory.inv
        let t2 = (bmax - ray.memory.o) * ray.memory.inv
        
        let tmin = simd.reduce_max(simd.min(t1, t2))
        let tmax = simd.reduce_min(simd.max(t1, t2))
 
        return tmax >= tmin    
    }
    
    /// Overlap function
    func overlap (b: AABB) -> Bool {
        // FIXME: SIMD version
        let a = self
        return (a.bmin.x <= b.bmax.x && a.bmax.x >= b.bmin.x) &&
            (a.bmin.y <= b.bmax.y && a.bmax.y >= b.bmin.y) &&
            (a.bmin.z <= b.bmax.z && a.bmax.z >= b.bmin.z)
    }
}

func < (lhs:AABB, rhs: AABB) -> Bool { return lhs.area < rhs.area } // FIXME: should this be volume?
func == (lhs:AABB, rhs:AABB) -> Bool { return lhs.bmin == rhs.bmin && lhs.bmax == rhs.bmax }
func ~= (lhs:AABB, rhs:AABB) -> Bool { return lhs.bmin ~= rhs.bmin && lhs.bmax ~= rhs.bmax }

/// Union operator
func + (lhs: AABB, rhs: AABB) -> AABB { return AABB(a: min(lhs.bmin, rhs.bmin), b: max(lhs.bmax, rhs.bmax)) }
/// Expand operator
func * (lhs: AABB, rhs: Scalar) -> AABB { return AABB(a: lhs.bmin - Vec(rhs), b: lhs.bmax + Vec(rhs)) }

