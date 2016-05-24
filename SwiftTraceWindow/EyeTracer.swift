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
class WhittedTracer: DistributedRayTracer {

    /// http://cs.brown.edu/courses/cs224/handouts/whitted.pdf
    override func radiance(ray: Ray) -> Color {
//        var hit = Intersection()
        var hit: Intersection?
        
        /// Performs the intersection and checks both the object and the distance
        guard scene.root.intersectWithRay(ray, hit: &hit), let obj = hit!.o
            else { return scene.skyColor(ray) }
        
        // if the surface is emissive (i.e. does not have measurable albedo), just return the emission
        let material: Material = obj.material
        if material.isLight() {
            return material.emission
        }
        
        // compute hitpoint, normal
        let x = ray.o + ray.d * hit!.d           // hit point
        var n = obj.normalAtPoint(x)    // normal at hitpoint
        if (dot(ray.d, n) > 0) {          // correct normal direction
            n = n * -1
        }

        // compute scatterred ray
//        let wo: Vec
//        (_, wo) = material.sample(ray.d, normal: n)
        
        return obj.colorAtPoint(x) 
    }
/*
    // direct light ray tracer, no material sampling
    override func radiance(r: Ray) -> Color {
  /*      let o: GeometryCollectionItemId
        let t: Scalar
        
        // performs the intersection with the scene
        (o, t) = scene.list.intersectWithRay(r)
*/            /// Performs the intersection and checks both the object and the distance
        guard let hit: Intersection = scene.list.intersectWithRay(r), let obj = hit.o
            else { return scene.skyColor(r) }
        
        // if there is no intersection, return the sky color
//        if !t.isNormal { return scene.skyColor(r) }
        
        // retrieves the object and the surface from the scene
//        let obj: Geometry = scene.list[o]!
        let material: Material = obj.material
        
        // if the surface is emissive (i.e. does not have measurable albedo), just return the emission
        if material.isLight() {
            return material.emission
        }
        
        // TODO: simulate specular, refractive
        let x = r.o + r.d * hit.d       // hit point
        var n = obj.normalAtPoint(x)    // normal at hitpoint
        if (dot(r.d, n) > 0) {          // correct normal direction
            n = n * -1
        }

        // direct ilumination
        let c: Vec = scene.ambientLight
        // FIXME: this doesn't work anymore
    /*    for lid in scene.lights {
            // shadow ray to random light surface point
            let light: Geometry = scene.list[lid]!
            let lray = Ray(o: x, d: normalize(light.sampleSurface() - x))
            
            // check if the ray hits a surface
            let l: GeometryCollectionItemId
            (l, _) = scene.list.intersectWithRay(lray)
            guard let sl = scene.list[l] else { continue }
            
            // if we hit our light or any other light
            if (l == lid) {
                c = c + light.material.emission.norm() * max(0, dot(lray.d, n))
            } else if sl.material.isLight() {
                c = c + sl.material.emission.norm() * max(0, dot(lray.d, n))
            }
 
        }
  */
        return obj.colorAtPoint(x) * c
    }*/
}
*/