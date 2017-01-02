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
    static func radiance(_ scene: _Scene, ray: inout _Ray) throws -> Vector {
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
        
        // radiance accumulator
        var cl: Vector = Vector()
        
        // radiance weight
        var cf: Vector = Vector(1)
        
        // iterations
        var depth = 0

        // light sample
        var sample = _Scene.LightSample()
        
        // shadow ray
        var sray = _Ray(o: Vector(), d: Vector())

        while true {
            // intersection with the world
            guard try scene.intersect(&ray) else { cl += cf * scene.background(ray); break }

            // this shouldn't happen
            guard ray.gid != IndexType.Invalid else { throw RendererError.invalidGeometry("geometry not found") }

            // retrieve the material for the primitive
            let material = scene.material(pid: ray.pid)
            
            // if we hit a light, just return
            guard material.isLight == false else { cl += cf * material.Ke; break }

            // compute direct lighting from area lights
            // FIXME: create a proper light class
            
            sample.hit = ray.x
            
            for lid in scene.buffer.light {
                // retrieve the geometry and choose a random point over the surface
                try scene.sampleLight(lid, sample: &sample)
                
                // check the sample pdf
                guard sample.pdf >= 0 else { continue }
                
                // setup the shadow ray
                sray.reset(o: sample.hit, d: sample.dir, tmin: Real.Eps, tmax: sample.dist)

                // check the occlusion of the shadow ray
                guard try scene.intersect(&sray) == false else { continue }
                
                // compute the resulting radiance
                let power = sample.weight * scene.material(pid: lid).Ke
                let color = power * material.eval(ray, n: ray.n, wi: sample.dir)
                cl += cf * color
            }
            
            // sample the material and compute the BRDF
            let (pdf, wi) = material.sample(ray)
            let c = material.eval(ray, n: ray.n, wi: wi) * recip(pdf)
            
            // update the accumulated weight
            cf = cf * c
            
            // russian roulette after a few iterations
            depth = depth + 1
            if depth > 3 {
                let p = reduce_max(cf)
                guard Real(drand48()) < p else { break }
                cf = cf * recip(p)
            }

            // max iterations termination (note: biased)
            guard depth < 10 else { break }
        
            // setup the new ray
            ray.reset(o: ray.x, d: wi, tmin: Real.Eps, tmax: Real.infinity)
        }

        return cl
    }
}



