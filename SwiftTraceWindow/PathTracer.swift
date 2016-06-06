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
        
        // radiance accumulator
        var cl: Vector = Vector()
        
        // radiance weight
        var cf: Vector = Vector(1)
        var depth = 0

        while true {
            // intersection with the world
            guard try scene.intersect(&ray) else { cl += cf * scene.background(ray); break }

            // this shouldn't happen
//            guard ray.gid != IndexType.Invalid  else { throw RendererError.InvalidGeometry("geometry not found") }
            
            // retrieve the material
            let material = scene.material(ray.mid)
            
            // if we hit a light, just return
            guard !material.isLight else { cl = cl + cf * material.Ke; break }

            // compute direct lighting from area lights
            // FIXME: refactor this, create a proper light class
            
            for lid in scene.buffer.light {
                // retrieve the geometry and choose a random point over the surface
                let (lpdf, lsample, lmid) = try scene.sampleLight(lid, ray: ray)
                
                // check the sample is pointing to us
                guard lpdf > 0 else { continue }
                
                // create the shadow ray
                let ldir = normalize(lsample - ray.x)
                let ldist = length(lsample - ray.x) 
                var sray = _Ray(o: ray.x, d: ldir, tmin: Real.Eps, tmax: ldist)

                // check the occlusion of the shadow ray
                if try scene.intersect(&sray) { continue }
                
                // compute the emitter radiance arriving per solid angle
                let lmaterial = scene.material(lmid)
                let radiance = lmaterial.Ke * (1 / lpdf)
                
                // compute the resulting radiance
                let color = radiance * material.eval(sray, n: ray.n, wi: sray.d)
                cl += cf * color
            }
            
            // compute the BRDF
            let (pdf, wi) = material.sample(ray)
            let c = material.eval(ray, n: ray.n, wi: wi) * (1/pdf)
            
            // update the accumulated weight
            cf = cf * c
            
            // check if the contribution is too low
            guard reduce_max(cf) > 0.01 else { break }

            // setup the new ray
            let d = wi
            let o = ray.x + d * Real.Eps
            ray.reset(o:o, d: d)
            
            depth = depth + 1
            guard depth < 10 else { break }
        }

        return cl
    }
}



