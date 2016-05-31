//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

struct PathTracer: Integrator {

    // non-recursive path tracing
    func radiance(scene: ScenePointer, ray: RayPointer, hit: IntersectionPointer) -> Color {
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
        var direction: Vec
        var probability: Scalar
        var depth = 0

//        hit.memory.count = 0
        while true {
            hit.memory.reset()
            // intersection with world
            guard scene.memory.intersectWithRay(ray: ray, hit: hit)
            else { return cl + cf * scene.memory.skyColor(ray) }

            // This shouln't happen
//            guard hit.memory.m != nil
//            else { return cl + Color.Black }
            let material = scene.memory.materialWithId(hit.memory.m!)!

            (probability, direction) = material.sample(wo: ray.memory.d, normal: hit.memory.n)
            var f = material.colorAtTextCoord(hit.memory.uv)
//            (probability, direction) = material.importance_sample(hit: hit, wo: ray.memory.d)
//            var f = material.brdf(hit: hit, wo: ray.memory.d, wi: direction)
            
            if material.isLight {
                return cl + cf * material.emission
            }

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
            
            cf = cf * f * probability
            cl = cl * cf
            ray.memory = Ray(o:hit.memory.x, d: direction)
        }
    }
}



