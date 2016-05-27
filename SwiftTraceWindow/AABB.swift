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
    private let preArea: Scalar
    private let preCenter: Vec
    
    init(a: Vec, b: Vec) {
        self.bmin = a
        self.bmax = b
        let d = bmax - bmin
        self.preCenter = bmin + d * 0.5
        self.preArea = 2.0 * (d.x * d.y + d.x * d.z + d.y + d.z)
    }

    init() { self.init(a: Vec.Zero, b: Vec.Zero) }

    var center: Vec { get { return preCenter } }
    var area: Scalar { get { return preArea } }

    // TODO
    func sample() -> Vec { return self.center }

    func intersectWithRay(r: Ray) -> Bool {

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
        let t1 = (bmin - r.o) * r.inv
        let t2 = (bmax - r.o) * r.inv
        
        let tmin = simd.reduce_max(simd.min(t1, t2))
        let tmax = simd.reduce_min(simd.max(t1, t2))
 
        return tmax >= tmin    
    }
}

func < (lhs:AABB, rhs: AABB) -> Bool { return lhs.area < rhs.area } // FIXME: should this be volume?
func == (lhs:AABB, rhs:AABB) -> Bool { return lhs.bmin == rhs.bmin && lhs.bmax == rhs.bmax }
func + (lhs:AABB, rhs: AABB) -> AABB { return AABB(a: min(lhs.bmin, rhs.bmin), b: max(lhs.bmax, rhs.bmax)) }
