//
//  Scene.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/21/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

protocol Scene {
    var list: GeometryList { get }
    var camera: CameraProtocol { get }
//    var lights: [GeometryCollectionItemId] { get }
    var root: IntersecableWithRay { get }
    
    var ambientLight: Vec { get }
    var backgroundColor: Color { get }
    
    func skyColor(r: Ray) -> Color
}

class ThreeBall: Scene {
    let list: GeometryList
    let camera: CameraProtocol
//    let lights: [GeometryCollectionItemId]
    var root: IntersecableWithRay
    
    let ambientLight = Vec(0.1, 0.1, 0.1)
    let backgroundColor = Color.Black

    let skydome: Texture
    
    init() {
        let materials: [String: Material] = [
            "Red"   : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.25,z:0.25)), // Red diffuse
            "Blue"  : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.25,z:0.75)), // Blue diffuse
            "Green" : Lambertian(emission: Vec(), color:Vec(x:0.25,y:0.75,z:0.25)), // Green diffuse
            "White" : Lambertian(emission: Vec(), color:Vec(x:0.75,y:0.75,z:0.75)), // White diffuse
            "Black" : Lambertian(emission: Vec(), color:Vec()),                     // Black
            "Mirror": Specular(emission: Vec(), color:Vec(0.3, 0.3, 0.3)),      // Mirror
            "Glass" : Refractive(emission: Vec(), color:Vec(x:1,y:1,z:1)*0.999),    // Glass
            "Lite"  : Lambertian(emission: Vec(x:8,y:8,z:8), color:Vec()),       // Lite
            "Lite2" : Lambertian(emission: Vec(x:12,y:8,z:8), color:Vec()),          // Lite
            "Chess" : Chessboard(emission: Vec(), color:Vec(0.05, 0.05, 0.05)),          // Lite
            "Earth" : Textured(emission: Vec(), color:Vec())          // Lite
        ]
    
        let objects: [Geometry] = [
            Sphere(rad:0.5, p:Vec(-2, 0, -6),         material: materials["Red"]!),
            Sphere(rad:0.5, p:Vec(-1, 0, -5),        material: materials["Chess"]!),
            Sphere(rad:0.5, p:Vec(0, 0, -4),            material: materials["Earth"]!),
            Sphere(rad:0.5, p:Vec(1, 0, -3),         material: materials["Green"]!),
            Sphere(rad:0.5, p:Vec(2, 0, -2),          material: materials["Glass"]!),
            Sphere(rad:-0.45, p:Vec(2, 0, -2),          material: materials["Glass"]!),
            Sphere(rad:0.15, p:Vec(2, 0, -2),          material: materials["Blue"]!),
            Sphere(rad:500, p:Vec(0, -500.5, -4),       material: materials["Mirror"]!),
            Sphere(rad:50, p:Vec(0, 110, -4),           material: materials["Lite"]!),       // Lite
        ]
        var spheres = Array<Geometry>()
        for _ in 0...25 {
            var s = sampleDisk(); s.z = s.y; s.y = 0
            let c = Vec(0, 0, -4) + s * 4
            let sphere = Sphere(rad: 0.2, p: c, material: materials["White"]!)
            spheres.append(sphere)
        }
//        spheres.append(Sphere(rad:500, p:Vec(0, -500.5, -4), material: materials["Mirror"]!))
//        spheres.append(Sphere(rad:50, p:Vec(0, 110, -4), material: materials["Lite"]!))
        
        
        list = GeometryList(items:spheres)
//        lights = [GeometryCollectionItemId](0..<objects.count).filter({ (id) -> Bool in objects[id].material.isLight() })
        
        root = BVHNode(nodes: objects + spheres)
        
        camera = ComplexCamera(lookFrom: Vec(0, 2, 2), lookAt: Vec(0.5, 1, -4), vecUp: Vec(0, 1, 0), fov: 60, aspect: 1.0+1.0/3.0, aperture: 0.1)
   
        let fileName = NSBundle.mainBundle().pathForResource("skydome", ofType: "jpg")!
        skydome = Texture(fileName: fileName)!
    }

    func skyColor(r: Ray) -> Color {
        var n = r.d.norm()
        let u = 0.5 + atan2(n.z, n.x) / (2.0 * M_PI)
        let v = 0.5 - asin(n.y) / M_PI
        
        return skydome[Vec(u, v * 2, 0)]
    /*
        let unitDirection = r.d.norm()
        let t = 0.5 * (unitDirection.y + 1.0)
        let c = (1 - t) * Vec(1, 1, 1) + t * Vec(0.5, 0.7, 1)
        
        return c
        */
    }
}

struct CornellBox: Scene {
    let list: GeometryList
    let camera: CameraProtocol
//    let lights: [GeometryCollectionItemId]
    var root: IntersecableWithRay
  
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
    
        let objects: [Geometry] = [
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
        list = GeometryList(items:objects)
        root = BVHNode(nodes: objects)
//        lights = [GeometryCollectionItemId](0..<objects.count).filter({ (id) -> Bool in objects[id].material.isLight() })
        
        camera = Camera(o: Vec(50, 52, 295.6), d: Vec(0, -0.042612, -1).norm())
    }
    
    func skyColor(r: Ray) -> Color { return self.backgroundColor }

}
