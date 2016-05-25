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
        var tmin = -Scalar.infinity
        var tmax = Scalar.infinity
 
        for i in 0...2 {
            if r.d[i] != 0.0 {
                let t1 = (bmin[i] - r.o[i])/r.d[i];
                let t2 = (bmax[i] - r.o[i])/r.d[i];
                
                tmin = max(tmin, min(t1, t2));
                tmax = min(tmax, max(t1, t2));
            } else if (r.o[i] <= bmin[i] || r.o[i] >= bmax[i]) {
                return false
            }
        }
//        return tmax > tmin && tmax > 0.0
        return tmax >= tmin && tmax >= 0.0
    
        // FIXME: SIMD version
        // http://www.flipcode.com/archives/SSE_RayBox_Intersection_Test.shtml
//        let flt_plus_inf = -logf(0)
//        let plus_inf = float4(flt_plus_inf, flt_plus_inf, flt_plus_inf, flt_plus_inf)
//        let minus_inf = float4(-flt_plus_inf, -flt_plus_inf, -flt_plus_inf, -flt_plus_inf)
//        let box_min = float4(Float(min.x), Float(min.y), Float(min.z), 1)
//        let box_max = float4(Float(max.x), Float(max.y), Float(max.z), 1)
//        let pos = float4(Float(r.o.x), Float(r.o.y), Float(r.o.z), 1)
//        let inv_dir = simd.recip(float4(Float(r.d.x), Float(r.d.y), Float(r.d.z), 1))
//        let l1 = (box_min - pos) * inv_dir
//        let l2 = (box_max - pos) * inv_dir
//        let filtered_l1a = simd.min(l1, plus_inf)
//        let filtered_l2a = simd.min(l2, plus_inf)
//        let filtered_l1b = simd.max(l1, minus_inf)
//        let filtered_l2b = simd.max(l2, minus_inf)
//        let lmax = simd.max(filtered_l1a, filtered_l2a)
//        let lmin = simd.min(filtered_l1b, filtered_l2b)
        
    }
}

func < (lhs:AABB, rhs: AABB) -> Bool { return lhs.area < rhs.area } // FIXME: should this be volume?
func == (lhs:AABB, rhs:AABB) -> Bool { return lhs.bmin == rhs.bmin && lhs.bmax == rhs.bmax }
func + (lhs:AABB, rhs: AABB) -> AABB { return AABB(a: min(lhs.bmin, rhs.bmin), b: max(lhs.bmax, rhs.bmax)) }
