//
//  Serializable.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation
import Decodable
import simd

enum SceneLoaderError: ErrorType {
    case InvalidVector(String)
    case InvalidFace(String)
    case InvalidFile(String)
    case InvalidType(String)
}
/*
extension Float: Castable {}

extension Vec: Decodable {
    init(v: [Scalar]) throws {
        if v.count == 0 {
            self.init(0, 0, 0)
        } else if v.count == 1 {
            self.init(v[0], v[0], v[0])
        } else if v.count == 3 {
            self.init(v[0], v[1], v[2])
        } else {
            throw SceneLoaderError.InvalidVector("Vector can only have 0, 1 or 3 elements")
        }
    }
    
    public static func decode(json: AnyObject) throws -> Vec {
        return try Vec(v: json as! [Scalar])
    }
}

extension ComplexCamera: Decodable {
    public static func decode(json: AnyObject) throws -> ComplexCamera {
        return try ComplexCamera(
            lookFrom: json => "look_from",
            lookAt: json => "look_at",
            vecUp: json => "vec_up",
            fov: json => "fov",
            aspect: json => "aspect",
            aperture: json => "aperture"
        )}
}

extension Sphere: Decodable {
    internal static func decode(json: AnyObject) throws -> Sphere {
        return try Sphere(
            rad: json => "r",
            p: json => "p",
            material: json => "m"
        )}
}

extension Triangle: Decodable {
    internal static func decode(json: AnyObject) throws -> Triangle {
        return try Triangle(
            p1: json => "p1",
            p2: json => "p2",
            p3: json => "p3",
            material: json => "m"
        )}
}
*/
extension Transform: Decodable {
    internal static func decode(json: AnyObject) throws -> Transform {
    
        let scale: Vec = try json => "scale"
        let rotate: Vec = try json => "rotate"
        let translate: Vec = try json => "translate"
        
        return Transform(scale: scale) +
               Transform(rotate_x: rotate.x) +
               Transform(rotate_y: rotate.y) +
               Transform(rotate_z: rotate.z) +
               Transform(translate: translate)
        }
}
/*
struct ObjectAndTransform: Decodable {
    let object: ObjectLibrary
    let transform: Transform
    let material: MaterialId

    internal static func decode(json: AnyObject) throws -> ObjectAndTransform {
        let transform = try Transform.decode(json => "transform")
        let object = try ObjectLibrary(name: json => "file")
        let material = try MaterialId((json => "m" as String).hashValue)
        
        return ObjectAndTransform(object: object, transform: transform, material: material)
    }
    
    func mesh() throws -> [Triangle] {
        return transform.apply(try object.mesh(material) as! [Triangle])
    }
}
*/
extension Shape: Decodable {
    internal static func decode(json: AnyObject) throws -> Shape {
        switch try json => "type" as String {
            case "s":
                return Shape.Sphere(
                    pos: try json => "p",
                    rad: try json => "r")
            case "t":
                return Shape(
                    v1: try json => "p1",
                    v2: try json => "p2",
                    v3: try json => "p3")
            case "g":
                return Shape.List(shapes: try json => "l")
            case "o":
                // FIXME: please note this ignores the material in the file
                let obj = try ObjectAndTransform.decode(json)
                return Shape.List(shapes: try obj.object.mesh() as [Shape])
            default:
                throw SceneLoaderError.InvalidType("invalid shape type: \(json)")
        }
    }
 }
/*
extension Primi: Decodable {
    internal static func decode(json: AnyObject) throws -> Primi {
        let m = try json => "m" as String
    
        let t: Transform? = try json =>? "transform"
        if t != nil {
            return try Primi(
                shape: Shape.decode(json),
                material: m.hashValue,
                transform: t!)
        } else {
            return try Primi(
                shape: Shape.decode(json),
                material: m.hashValue)
        }
    }
}
*/
extension Scene: Decodable {
    public static func decode(json: AnyObject) throws -> Scene {
    
        let world: World = try World(try json => "primi" as [Primi])
        
    
        // WTF!! H@XX0R!!
//        let spheres: [Sphere] = try json => "primitives" => "spheres"
//        let triangles: [Triangle] = try json => "primitives" => "triangles"
//        let object_transform: [ObjectAndTransform] = try json => "primitives" => "objects"
        let skydome = try Texture(name: try json => "skydome" => "file")
//        var materials = [MaterialId: MaterialProtocol]()
//        object_transform.forEach({ $0.object.mtllib.forEach({ materials[$0.hashValue] = $1 }) })
    
        let objects = [Primitive]()
//        triangles.forEach { (t) in objects.append(t) }
//        spheres.forEach { (s) in objects.append(s) }
//        try object_transform.forEach { (o) in let mesh = try o.mesh(); mesh.forEach({ t in objects.append(t) }) }
    
        return try Scene(
            camera: json => "camera",
            objects: objects,
            world: world,
            skydome: skydome,
            materials: [MaterialId:Material]()
        )}
}