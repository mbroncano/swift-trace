//
//  Scene.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/21/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

struct Scene: IntersectWithRayIntersection {
    let camera: CameraProtocol
    let root: Primitive
    let objects: [Primitive]
    let lights: [Primitive]
    
    let ambientLight: Color = Color(0.1, 0.1, 0.1)
    let backgroundColor: Color = Color.Black
    
    let materials: [MaterialId: Material]
    var skydome: Texture? = nil

    func skyColor(r: Ray) -> Color {
        guard skydome != nil else { return backgroundColor }
    
        var n = r.d.norm()
        let u = 0.5 + atan2(n.z, n.x) / (2.0 * Scalar(M_PI))
        let v = 0.5 - asin(n.y) / Scalar(M_PI)
        
        return skydome![Vec(u, v * 2, 0)]
    }
    
    func intersectWithRay(r: Ray, inout hit: Intersection) -> Bool {
        return root.intersectWithRay(r, hit: &hit)
    }

    func materialWithId(mid: MaterialId) -> Material? {
        guard let material = materials[mid] else { return nil }
        return material
    }

    init() {

        self.materials = [
            "Red"   : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.25,z:0.25)), // Red diffuse
            "Blue"  : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.25,z:0.75)), // Blue diffuse
            "Green" : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.75,z:0.25)), // Green diffuse
            "White" : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.75,z:0.75)), // White diffuse
            "Black" : Lambertian(emission: Vec(), color:Vec()),                     // Black
            "Mirror": Specular(emission: Vec(), color:Vec(0.3, 0.3, 0.3)),      // Mirror
            "Glass" : Refractive(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),    // Glass
            "DarkGlass" : Refractive(emission: Vec(), color: Color.Blue * 0.8),    // Glass
            "Lite"  : Lambertian(emission: Vec(x:8,y:8,z:8), color:Vec()),       // Lite
            "Lite2" : Lambertian(emission: Vec(x:8,y:4,z:4), color:Vec()),          // Lite
            "Lite3" : Lambertian(emission: Vec(x:4,y:4,z:8), color:Vec()),          // Lite
            "Chess" : Chessboard(squares: 10, white: Color.White, black:Vec(0.05, 0.05, 0.05)),          // Lite
            "Chess20" : Chessboard(squares: 20, white: Color.White, black:Vec(0.05, 0.05, 0.05)),          // Lite
            "Earth" : Textured(emission: Vec(), color:Vec())          // Lite
        ]
    
        let spheres: [Primitive] = [
            Sphere(rad:0.5,   p:Vec(-3, 0.5, 2), material: "Red"),
            Sphere(rad:0.5,   p:Vec(-1.5, 0.5, 2), material: "Chess"),
            Sphere(rad:0.5,   p:Vec(0, 0.5, 2),  material: "Earth"),
            Sphere(rad:0.5,   p:Vec(1.5, 0.5, 2),  material: "Green"),
            Sphere(rad:0.5,   p:Vec(3, 0.5, 2),  material: "Glass"),
            Sphere(rad:-0.4,  p:Vec(3, 0.5, 2),  material: "Glass"),
            Sphere(rad:0.15,  p:Vec(3, 0.5, 2),  material:  "Blue"),
//            Sphere(rad:500, p:Vec(0, -500.5, -4),       material: "Mirror"),
//        ]
        
//        let floor: [Primitive] = [
            Triangle(p1: Vec(-10, 0, -10), p2: Vec(-10, 0, 10), p3: Vec(10, 0, -10), material: "Chess20"),
            Triangle(p1: Vec(10, 0, 10),   p2: Vec(10, 0, -10), p3: Vec(-10, 0, 10), material: "Chess20"),
//            ]
        /*
        for _ in 0...25 {
            var s = sampleDisk(); s.z = s.y; s.y = 0
            let c = Vec(0, 0, -4) + s * 4
            let sphere = Sphere(rad: 0.2, p: c, material: "White")
            spheres.append(sphere)
        }*/
        /*
        let start = NSDate().timeIntervalSince1970
        let lib = ObjectLibrary(name: "cube.obj")
        let meshes = lib?.mesh("DarkGlass")[0] as! [Triangle]
        let t = Transform(scale: Vec(10, 4, 0.5)) + Transform(rotate: Vec(0.0, 0.0, 0)) + Transform(translate: Vec(0, 0, -2))
        let cube = meshes.map { (triangle) -> Primitive in
            return t.apply(triangle)
        }
        
        let duration = NSDate().timeIntervalSince1970 - start
        print("Load object: completed in \(duration * 1000)ms")
 
        let tb = Transform(scale: Vec(15)) + Transform(rotate: Vec(0, 0.4, 0)) + Transform(translate: Vec(0, -2, 2))
        let ob = ObjectLibrary(name: "bunny.obj")
        let bunny = ob?.mesh("Mirror")[0] as! [Triangle]
        
        let bunny_ = bunny.map { (triangle) -> Primitive in
            return tb.apply(triangle)
        }*/

//        let lites: [Primitive] = [
//            Sphere(rad:1, p:Vec(-4, 10, -10),           material: "Lite3"),       // Lite
            Sphere(rad:1, p:Vec( 4, 10, -10),           material: "Lite2"),       // Lite
        ]
        
        self.objects =
            spheres  //+
//            floor +
//            lites
//            cube +
//            bunny_
        self.lights = [] //lites

        var id = 0; root = BVHNode(nodes: objects, id: &id); print("bvh contains \(id) nodes")
//        root = PrimitiveList(nodes: self.objects)
        
//        camera = ComplexCamera(lookFrom: Vec(3, 2, 2), lookAt: Vec(0.5, 1, -4), vecUp: Vec(0, 1, 0), fov: 60, aspect: 1.25, aperture: 0.1)
        camera = ComplexCamera(lookFrom: Vec(0, 2.8, 8), lookAt: Vec(0, 0.5, 2), vecUp: Vec(0, 1, 0), fov: 60, aspect: 1.25, aperture: 0.1)
   
        let fileName = NSBundle.mainBundle().pathForResource("skydome", ofType: "jpg")!
        skydome = Texture(fileName: fileName)
    }
}
/*
struct CornellBox: Scene {
//    let list: GeometryList
    let camera: CameraProtocol
//    let lights: [GeometryCollectionItemId]
    var root: Primitive
  
    let ambientLight = Vec(0.1, 0.1, 0.1)
    let backgroundColor = Color.Black

    init() {
        let materials: [String: Material] = [
            "Red"   : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.25,z:0.25)), // Red diffuse
            "Blue"  : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.25,z:0.75)), // Blue diffuse
            "Green" : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.75,z:0.25)), // Green diffuse
            "White" : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.75,z:0.75)), // White diffuse
            "Black" : Lambertian(emission: Vec(), color:Vec()),                     // Black
            "Mirror": Specular(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),      // Mirror
            "Glass" : Refractive(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),    // Glass
            "Lite"  : Lambertian(emission: Vec(x:12,y:12,z:12), color:Vec()),        // Lite
            "Lite2" : Lambertian(emission: Vec(x:12,y:8,z:8), color:Vec())        // Lite
        ]
    
        let objects: [Primitive] = [
            Sphere(rad:1e5, p:Vec(x: 1e5+1,y:40.8,z:81.6),  material: materials["Red"]!),       // Left
            Sphere(rad:1e5, p:Vec(x:-1e5+99,y:40.8,z:81.6), material: materials["Blue"]!),      // Right
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z: 1e5),      material: materials["White"]!),     // Back
            Sphere(rad:1e5, p:Vec(x:50,y:40.8,z:-1e5+170),  material: materials["Black"]!),     // Front
            Sphere(rad:1e5, p:Vec(x:50,y: 1e5,z: 81.6),     material: materials["White"]!),     // Botom
            Sphere(rad:1e5, p:Vec(x:50,y:-1e5+81.6,z:81.6), material: materials["White"]!),     // Top
            Sphere(rad:16.5,p:Vec(x:27,y:16.5,z:47),        material: materials["Mirror"]!),    // Mirror
            Sphere(rad:16.5,p:Vec(x:73,y:16.5,z:78),        material: materials["Glass"]!),     // Glass
//            Triangle(p1: Vec(x:27,y:16.5,z:47), p2: Vec(x:73,y:16.5,z:78), p3: Vec(x:30,y:11.6,z:111.6), material: materials["Green"]!),
//            Triangle(p1: Vec(30,10,120), p2: Vec(30,10,120), p3: Vec(60,10,120), material: materials["Green"]!),
            Sphere(rad:600, p:Vec(x:50,y:681.6-0.27,z:81.6),material: materials["Lite"]!),       // Lite
//            Sphere(rad:3, p:Vec(x:50,y:8,z:81.6),material: materials["Lite2"]!)       // Lite
        ]
//        list = GeometryList(items:objects)
        root = BVHNode(nodes: objects)
//        lights = [GeometryCollectionItemId](0..<objects.count).filter({ (id) -> Bool in objects[id].material.isLight() })
        
        camera = Camera(o: Vec(50, 52, 295.6), d: Vec(0, -0.042612, -1).norm())
    }
    
    func skyColor(r: Ray) -> Color { return self.backgroundColor }

}
*/