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
            // intersection with world
            let hit: Intersection = scene.list.intersectWithRay(r)
            guard let obj = hit.o else { return cl + cf * scene.skyColor(r) }
            
            let t = hit.d
            let material = obj.material

            let x = r.o + r.d * t           // hit point
            
            var f = material.color(obj.textureAtPoint(x))
            let p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z // max refl

            cl = cl + (cf * material.emission)

            // Russian roulette
            depth = depth + 1
            if depth > 5 {
                if (depth < 80 && Random.random()<p) {
                    f=f*(1/p)
                } else {
                    return cl
                }
            }
            
            // Sample a new ray
            let direction: Vec
            var probability: Scalar

            (probability, direction) = material.sample(r.d, normal: obj.normalAtPoint(x))
            cf = cf * f * probability
            r = Ray(o:x, d: direction)
        }
    }
}



