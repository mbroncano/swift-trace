//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

class PathTracer: RayTracer {

    // non-recursive path tracing
    override func radiance(r: Ray) -> Color {
        // L0 = Le0 + f0*(L1)
        //    = Le0 + f0*(Le1 + f1*L2)
        //    = Le0 + f0*(Le1 + f1*(Le2 + f2*(L3))
        //    = Le0 + f0*(Le1 + f1*(Le2 + f2*(Le3 + f3*(L4)))
        //    = ...
        //    = Le0 + f0*Le1 + f0*f1*Le2 + f0*f1*f2*Le3 + f0*f1*f2*f3*Le4 + ...
        //
        // So:
        // F = 1
        // while (1){
        //   L += F*Lei
        //   F *= fi
        //
        var cl: Vec = Vec.Zero
        var cf: Vec = Vec.Unit
        var r = r
        var depth = 0
        
        while true {
            let o: GeometryCollectionItemId
            let t: Scalar
            
            (o, t) = scene.list.intersectWithRay(r)
            
            // if there is no intersection, return the background color (black)
            if !t.isNormal { return Vec.Zero }
            
            let obj:Geometry = scene.list[o]!
            let material = obj.material
            
            var f = material.color
            let p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z // max refl

            cl = cl + (cf * material.emission)

            // Russian Roulette:
            depth = depth + 1
            if depth > 5 {
                // Limit depth to 15 to avoid stack overflow.
                if (depth < 15 && Random.random()<p) {
                    f=f*(1/p)
                } else {
                    return cl
                }
            }
            
            let x = r.o + r.d * t           // hit point
            let n = obj.normalAtPoint(x)    // normal at hitpoint

            let direction: Vec
            var probability: Scalar

            (probability, direction) = material.sample(r.d, normal: n)
            cf = cf * f * probability
            r = Ray(o:x, d: direction)
        }
    }
}



