//
//  PathTracer.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/17/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

// TODO: antialias (pixel subsampling)
// TODO: implement DOF
// TODO: non-axis aligned POV
struct Camera {
    let o, d: Vec
    let nx, ny: Scalar
    
    func generateRay(x: Int, _ y: Int) -> Ray {
        let ar = 0.5135
        let cx = Vec(nx * ar / ny, 0, 0)
        let cy = cross(cx, d).norm() * ar
    
        let part1 = Scalar(x) / nx - 0.5
        let part2 = Scalar(y) / ny - 0.5
        let dir = cx * part1 + cy * part2 + d
        
        return Ray(o:o+dir*140, d:dir.norm())
    }
}

class Scene {
    let list: GeometryList
    let camera: Camera
    let framebuffer: Framebuffer
    let materials: [String: Material]

    init(w:Int, h: Int) {
        materials = [
            "Red"   : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.25,z:0.25)), // Red diffuse
            "Blue"  : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.25,z:0.75)), // Blue diffuse
            "White" : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.75,z:0.75)), // White diffuse
            "Black" : Lambertian(emission: Vec(), color:Vec()),                     // Black
            "Mirror": Specular(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),      // Mirror
            "Glass" : Refractive(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),    // Glass
            "Lite"  : Lambertian(emission: Vec(x:12,y:12,z:12), color:Vec())        // Lite
        ]
    
        let objects: [Geometry] = [
            Sphere(rad:1e5, p:Vec(x: 1e5+1,y:40.8,z:81.6),  material: "Red"),       // Left
            Sphere(rad:1e5, p:Vec(x:-1e5+99,y:40.8,z:81.6), material: "Blue"),      // Right
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z: 1e5),      material: "White"),     // Back
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z:-1e5+170),  material: "Black"),     // Front
            Sphere(rad:1e5, p:Vec(x:50,y: 1e5,z: 81.6),     material: "White"),     // Botom
            Sphere(rad:1e5, p:Vec(x:50,y:-1e5+81.6,z:81.6), material: "White"),     // Top
            Sphere(rad:16.5,p:Vec(x:27,y:16.5,z:47),        material: "Mirror"),    // Mirror
            Sphere(rad:16.5,p:Vec(x:73,y:16.5,z:78),        material: "Glass"),     // Glass
            Sphere(rad:600, p:Vec(x:50,y:681.6-0.27,z:81.6),material: "Lite")       // Lite
        ]
        list = GeometryList(list:objects)

        camera = Camera(o: Vec(50, 52, 295.6), d: Vec(0, -0.042612, -1).norm(), nx: Scalar(w), ny: Scalar(h))
        framebuffer = Framebuffer(width: w, height: h)
    }

    // non-recursive path tracing
    func radiance(r: Ray) -> Vec {
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
            
            (o, t) = list.intersect(r)
            
            // if there is no intersection, return the background color (black)
            if !t.isNormal { return Vec.Zero }
            
            let obj = o!
            let material = materials[obj.material]!
            
            var f = material.color
            let p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z // max refl

            cl = cl + (cf * material.emission)

            depth++
            // Russian Roulette:
            if (depth>5) {
                // Limit depth to 150 to avoid stack overflow.
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

    func render() {
        framebuffer.samples++
        
        dispatch_apply(Int(camera.nx * camera.ny), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let x = $0 % Int(self.camera.nx)
            let y = Int(self.camera.ny) - ($0 / Int(self.camera.nx)) - 1
            let ray = self.camera.generateRay(x, y)
            let radiance = self.radiance(ray)
            self.framebuffer.pixels[$0] += radiance
        }
    }
}

