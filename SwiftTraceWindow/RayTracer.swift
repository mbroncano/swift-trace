//
//  RayTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/23/15.
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
        let o: GeometryListId
        let t: Scalar
        
        (o, t) = scene.list.intersectWithRay(r)
        
        // if there is no intersection, return the background color (black)
        if !t.isNormal { return scene.backgroundColor }
        
        let obj: Geometry = scene.list[o]!
        let material: Material = obj.material
        
        if material.isLight() {
            return material.emission
        }
        
        // TODO: simulate specular, refractive
        let x = r.o + r.d * t           // hit point
        var n = obj.normalAtPoint(x)    // normal at hitpoint
        if (dot(r.d, n) > 0) {
            n = n * -1
        }

        // direct ilumination
        var c: Vec = scene.ambientLight
        for lid in scene.lights {
            // shadow ray to random light surface point
            let light: Geometry = scene.list[lid]!
            let lray = Ray(o: x, d: normalize(light.sampleSurface() - x))
            
            // check if the ray hits a surface
            let l: GeometryListId
            (l, _) = scene.list.intersectWithRay(lray)
            let sl = scene.list[l]!
            
            // if we hit our light or any other light
            if (l == lid) {
                c = c + light.material.emission.norm() * max(0, dot(lray.d, n))
            } else if sl.material.isLight() {
                c = c + sl.material.emission.norm() * max(0, dot(lray.d, n))
            }
            
        }
        
        return material.color * c
    }

    func render() {
        framebuffer.samples += 1

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
