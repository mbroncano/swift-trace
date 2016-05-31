//
//  EyeTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/17/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

/*
struct Whitted: Integrator {
    func radiance(scene: ScenePointer, ray: RayPointer, hit: IntersectionPointer) -> Color {
        
        hit.memory.reset()
        guard scene.memory.intersectWithRay(ray: ray, hit: hit)
        else { return scene.memory.skyColor(ray) }
        
        // This shouldn't happen
//        guard hit.memory.m != ""
//        else { return Color.Black }
        
        let material = scene.memory.materialWithId(hit.memory.m!)!
        var Lo = Color.Black
        
        // evaluate direct ligthing
        let shadowRay = RayPointer.alloc(1)
        for light in scene.memory.lights {
            let lightMaterial = scene.memory.materialWithId(light.material!)!

            let pdf: Scalar
            let lightSample: Vec
            
            (pdf, lightSample) = lightMaterial.sampleLight()
            
            
            shadowRay.initialize(Ray(o: hit.memory.x, d: lightSample))
            
            // check for visibility
            guard !scene.memory.intersectWithRay(ray: shadowRay) else { continue }
            
            let geometricTerm = max(0, dot(shadowRay.memory.d, hit.memory.n))
            
            Lo += geometricTerm * lightMaterial.emission * material.brdf(hit: hit, wo: ray.memory.d, wi: shadowRay.memory.d)
        }
        
        return Lo
    }
}
*/
/*
class WhittedTracer: DistributedTracer {

    // http://www.cse.chalmers.se/edu/year/2011/course/TDA361/2007/rend_eq.pdf
    // http://cs.brown.edu/courses/cs224/handouts/whitted.pdf
    override func radiance(ray: Ray) -> Color {
        var hit = Intersection()
        
        guard scene.intersectWithRay(ray, hit: &hit),
            let mid = hit.m,
            let material = scene.materialWithId(mid)
            
            else { return scene.skyColor(ray) }
        
        var Lo = material.emission + scene.ambientLight * material.colorAtTextCoord(hit.uv)
        
        // compute the shadow ray
        var lhit = Intersection()
        for lite in scene.lights {
            let p = lite.sample()
            let r = Ray(from: hit.x, to: p)
            
            // we need to check that the intersection is with 'lite'
            guard scene.intersectWithRay(r, hit: &lhit), let lmid = lhit.m, let lmat = scene.materials[lmid], let lprim = lhit.p
            where lprim == lite // && lmat.isLight()
            else { continue }

            // weakening factor wi * n
            let cos = dot(r.d, hit.n)
            guard cos > 0 else { continue }
            
            // incoming light
            let rad = lhit.d
            let area = lite.area // 1000
            let sangle = area / (rad*rad)
            let Li = sangle * lmat.emission
            
            // Lambertian BRDF
            // FIXME: add specular, dielectric
            let fr = material.colorAtTextCoord(hit.uv)
            
            Lo += fr * Li * cos
        }
        
        assert(Lo.isFinite)
 
        return Lo
    }
}
*/