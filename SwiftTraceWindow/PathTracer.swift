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
            guard try scene.intersect(&ray) else { cl += cf * scene.background(ray); break }

            // this shouldn't happen
            guard ray.gid != IndexType.Invalid  else { throw RendererError.InvalidGeometry("geometry not found") }
            
            // retrieve the material
            let material = scene.material(ray)
            
            // FIXME: compute the differential geometry for the hit point

            // compute the BRDF
            let (probability, direction) = material.sample(ray)
            var f = material.color(ray)

            // if we hit a light, just return
            guard reduce_max(material.Ke) == 0 else { cl = cl + cf * material.Ke; break }
            
            // Russian roulette
            if depth > 5 {
                let p = simd.reduce_max(f)
                if (depth < 80 && Real(drand48()) < p) {
                    f = f * (1.0 / p)
                } else {
                    break
                }
            }

            // update the accumulated irradiance and weight
            cf = cf * f * probability
            cl = cl * cf
            
            // check the weight is still meaningful
            guard reduce_max(cf) > Real.Eps else { break }

            depth = depth + 1
            ray.reset(o:ray.x, d: direction)
        }

        return cl
    }
}



