//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

class PathTracer: DistributedRayTracer {

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
        var hit = Intersection()
        
        while true {
            // intersection with world
            guard scene.intersectWithRay(r, hit: &hit),
                  let mid = hit.m,
                  let material = scene.materialWithId(mid)
            
                else { return cl + cf * scene.skyColor(r) }
            
            var f = material.colorAtTextCoord(hit.uv)
            cl = cl + cf * material.emission

            // Russian roulette
            if depth > 5 {
                let p = simd.reduce_max(f);
                if (depth < 80 && Scalar.Random() < p) {
                    f = f * (1.0 / p)
                } else {
                    return cl
                }
            }
            depth = depth + 1
            
            // Sample a new ray
            let direction: Vec
            var probability: Scalar

            (probability, direction) = material.sample(r.d, normal: hit.n)
            cf = cf * f * probability
            r = Ray(o:hit.x, d: direction)
            hit.reset()
        }
    }
}



