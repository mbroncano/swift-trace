//
//  Scene.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 12/21/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import simd

enum SceneError: ErrorType {
    case InvalidMaterial(String)
}

public struct Scene: IntersectWithRayIntersection {
    let camera: GenerateRay
    let root: Primitive
    var objects: [Primitive] = []
    let lights: [Primitive] = []
    
    let ambientLight: Color = Color(0.1, 0.1, 0.1)
    let backgroundColor: Color = Color.Black
    
    var materials: [MaterialId: Material] = [:]
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
        guard let material = materials[mid]
        else { return nil }
        return material
    }
    
    mutating func defaultMaterials() throws  {
        let mats = try
    
        [
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
            "Earth" : Textured(name: "earth.jpg")          // Lite
        ]
        
        mats.forEach({ self.materials[$0] = $1 })
    }

   init(camera: ComplexCamera, objects: [Primitive], skydome: Texture?, materials: [MaterialId: Material]) throws {
        self.camera = camera //Camera(o: Vec(50, 52, 295.6), d: Vec(0, -0.042612, -1).norm())
        self.objects = objects
        
        var id = 0; self.root = BVHNode(nodes: self.objects, id: &id); print("bvh contains \(id) nodes")
//        root = PrimitiveList(nodes: self.objects)
        
//        camera = ComplexCamera(lookFrom: Vec(3, 2, 2), lookAt: Vec(0.5, 1, -4), vecUp: Vec(0, 1, 0), fov: 60, aspect: 1.25, aperture: 0.1)
//        self.camera = ComplexCamera(lookFrom: Vec(0, 2.8, 8), lookAt: Vec(0, 0.5, 2), vecUp: Vec(0, 1, 0), fov: 60, aspect: 1.25, aperture: 0.1)
   
        self.skydome = skydome
        self.materials = materials
    }
}