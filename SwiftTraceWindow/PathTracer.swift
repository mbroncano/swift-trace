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
    static func radiance(scene: _Scene, inout ray: _Ray) throws -> Vector {
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
        
        var cl: Vector = Vector()
        var cf: Vector = Vector(1)
        var depth = 0

        while true {
            // intersection with world
            guard try scene.intersect(&ray) else { cl = cl + cf * scene.background(ray); break }

            // This shouln't happen
            guard ray.gid != IndexType.Invalid  else { break }
            
            let material = try scene.material(ray.gid)

            let (probability, direction) = material.sample(ray)
            var f = material.color(ray)

            if reduce_max(material.Ke) > Real.Eps {
                return cl + cf * material.Ke
            }
            
            let p = simd.reduce_max(f)
            if p < Real.Eps {
                return cl
            }

            // Russian roulette
            if depth > 5 {
                if (depth < 80 && Real(drand48()) < p) {
                    f = f * (1.0 / p)
                } else {
                    break
                }
            }
            depth = depth + 1
            
            cf = cf * f * probability
            cl = cl * cf
            ray.reset(o:ray.x, d: direction)
        }

        return cl
    }
}



