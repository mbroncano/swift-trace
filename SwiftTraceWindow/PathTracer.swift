//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

class RayTracer {
    let scene: Scene
    let framebuffer: Framebuffer

    init(scene:Scene, w: Int, h: Int) {
        self.scene = scene
        framebuffer = Framebuffer(width: w, height: h)
    }
    
    func radiance(r: Ray) -> Color {
        let o: Geometry?
        let t: Scalar
        
        (o, t) = scene.list.intersect(r)
        
        // if there is no intersection, return the background color (black)
        if !t.isNormal { return Vec.Zero }
        
        let obj = o!
        let material = obj.material
        
        if material.isLight() {
            return material.emission
        }
        
        let x = r.o + r.d * t           // hit point
        let n = obj.normalAtPoint(x)    // normal at hitpoint

        // choose a light
        let light = scene.lights[0]
        let lray = normalize(light.sampleSurface() - x)
        
        let c = max(0, dot(lray, n))
        
        return material.color * (c + 0.1)
    }

    func render() {
        framebuffer.samples++

        let nx = framebuffer.width
        let ny = framebuffer.height
        
        // process each ray in parallel
        dispatch_apply(nx * ny, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // generate new ray
            let x = $0 % nx
            let y = ny - ($0 / nx) - 1
            let ray = self.scene.camera.generateRay(x: x, y: y, nx: nx, ny: ny)
            
            // compute and accumulate radiance for the ray
            let radiance = self.radiance(ray)
            self.framebuffer.pixels[$0] += radiance
        }
    }
}

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
            let o: Geometry?
            let t: Scalar
            
            (o, t) = scene.list.intersect(r)
            
            // if there is no intersection, return the background color (black)
            if !t.isNormal { return Vec.Zero }
            
            let obj = o!
            let material = obj.material
            
            var f = material.color
            let p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z // max refl

            cl = cl + (cf * material.emission)

            // Russian Roulette:
            if (++depth > 5) {
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
            let probability: Scalar

            (probability, direction) = material.sample(r.d, normal: n)
            cf = cf * f * probability
            r = Ray(o:x, d: direction)
        }
    }
}



