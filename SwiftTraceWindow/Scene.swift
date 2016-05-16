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
    var camera: Camera { get }
    var lights: [GeometryCollectionItemId] { get }
    
    var ambientLight: Vec { get }
    var backgroundColor: Color { get }
}

struct CornellBox: Scene {
    let list: GeometryList
    let camera: Camera
    let lights: [GeometryCollectionItemId]
    
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
            Sphere(rad:3, p:Vec(x:50,y:8,z:81.6),material: materials["Lite2"]!)       // Lite
        ]
        list = GeometryList(items:objects)
        lights = [GeometryCollectionItemId](0..<objects.count).filter({ (id) -> Bool in objects[id].material.isLight() })
        
        camera = Camera(o: Vec(50, 52, 295.6), d: Vec(0, -0.042612, -1).norm())
    }
}