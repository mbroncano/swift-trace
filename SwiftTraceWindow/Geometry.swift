//
//  Geometry.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import simd

struct RayIntersection {
    var dist: Scalar = Scalar.infinity
    var object: Geometry?
}

protocol Geometry {
    var p: Vec { get }     // position
    var e: Vec { get }     // emission
    var c: Vec { get }     // color
    var refl: Refl_t { get }     // reflection type (DIFFuse, SPECular, REFRactive)
    
    func intersect(ray r: Ray, inout result res: RayIntersection) -> Bool
    func intersect(r: Ray) -> Scalar
}

struct GeometryList: Geometry {
    let list: [Geometry]
    let p, e, c: Vec      // position, emission, color
    let refl: Refl_t      // reflection type (DIFFuse, SPECular, REFRactive)
    
    func intersect(ray r: Ray, inout result res: RayIntersection) -> Bool {
        for object in list {
            let d:Scalar = object.intersect(r)
            if (d != 0.0 && d<res.dist){
                res.dist=d
                res.object=object
            }
        }
        return res.dist < Double.infinity
    }

    func intersect(r: Ray) -> Scalar { return 0 }
}

struct Sphere: Geometry {
    let rad: Scalar       // radius
    let p, e, c: Vec      // position, emission, color
    let refl: Refl_t      // reflection type (DIFFuse, SPECular, REFRactive)

    func intersect(ray r: Ray, inout result: RayIntersection) -> Bool {
        let d = intersect(r)
        
        if (d == 0 || d > result.dist) { return false }
        
        result.dist = d
        result.object = self
        return true
    }

    // Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0
    // returns distance, 0 if nohit
    func intersect(r: Ray) -> Scalar {
        let po = r.o - p
        let b = dot(r.d, po)
        let c = dot(po, po) - (rad * rad)
        let d = b*b - c

        if (d < 0) { return 0 }
        
        let s = sqrt(d)
        let q = (b < 0) ? (-b-s) : (-b+s)
        let r = (q > Scalar.epsilon) ? q : 0
        
        return r
    }
}
