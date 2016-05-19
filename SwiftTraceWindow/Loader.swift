//
//  Loader.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/19/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

// http://www.martinreddy.net/gfx/3d/OBJ.spec


struct Vertex: CustomStringConvertible {
    let x, y, z, w: Scalar
    
    var description: String { get { return "(\(x), \(y), \(z), \(w))" } }
}

struct TextureVertex: CustomStringConvertible {
    let u, v, w: Scalar
    
    var description: String { get { return "(\(u), \(v), \(w))" } }
}

struct Normal: CustomStringConvertible {
    let i, j, k: Scalar
    
    var description: String { get { return "(\(i), \(j), \(k))" } }
}

struct FaceElement {
    let vi, ti, ni: Int32
}

struct Group {
    let name: String
    let faces: [[FaceElement]]
}

enum MaterialElementKey: String {
    case Illum, Ka, Kd, Ks, Ke, Ns, Ni, Map_Kd
}

struct MaterialElement {
    struct MaterialElementColor {
        let r, g, b: Scalar
    }

    enum MaterialElementIllum: Int {
        case Constant = 0, Lambertian, BlinnPhong
    }

    let name: String
    let properties: Dictionary<MaterialElementKey, AnyObject>
}


// https://people.cs.clemson.edu/~dhouse/courses/405/docs/brief-mtl-file-format.html
struct MaterialLibrary {
    var materials = [MaterialElement]()

    init?(name: String) {
        guard
            let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
            let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            else { return nil }
        
        for line in text.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) {
            let scanner = NSScanner(string: line)
            
            if scanner.scanString("#", intoString: nil) {
                if let comment = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    print("[\(name):comment]\t\(comment)")
                }
            }

            else if scanner.scanString("newmtl ", intoString: nil) {
                if let newmtl = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    materials.append(MaterialElement(name: newmtl, properties: Dictionary<MaterialElementKey, AnyObject>()))
                    print("[\(name):newmtl]\t\(newmtl)")
                }
            }
            
            else if scanner.scanString("illum ", intoString: nil) {
                if let illum = scanner.scanInt() {
                    if let m = materials.popLast() {
                        var d = m.properties
                        d[.Illum] = NSNumber(int: illum)
                        materials.append(MaterialElement(name: m.name, properties: d))
                    }
                    print("[\(name):illum]\t\(illum)")
                }
            }

            else if scanner.scanString("illum ", intoString: nil) {
                if let illum = scanner.scanInt() {
                    if let m = materials.popLast() {
                        var d = m.properties
                        d[.Illum] = NSNumber(int: illum)
                        materials.append(MaterialElement(name: m.name, properties: d))
                    }
                    print("[\(name):illum]\t\(illum)")
                }
            }

            else if scanner.scanString("Ns ", intoString: nil) {
                if let ns = scanner.scanDouble() {
                    if let m = materials.popLast() {
                        var d = m.properties
                        d[.Ns] = NSNumber(double: ns)
                        materials.append(MaterialElement(name: m.name, properties: d))
                    }
                    print("[\(name):ns]\t\(ns)")
                }
            }

            else if scanner.scanString("Ni ", intoString: nil) {
                if let ni = scanner.scanDouble() {
                    if let m = materials.popLast() {
                        var d = m.properties
                        d[.Ni] = NSNumber(double: ni)
                        materials.append(MaterialElement(name: m.name, properties: d))
                    }
                    print("[\(name):ni]\t\(ni)")
                }
            }
            
            else if scanner.scanString("map_Kd ", intoString: nil) {
                if let map_kd = scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) {
                    if let m = materials.popLast() {
                        var d = m.properties
                        d[.Map_Kd] = map_kd
                        materials.append(MaterialElement(name: m.name, properties: d))
                    }
                    print("[\(name):map_kd]\t\(map_kd)")
                }
            }
            
            // TODO: rest of the stuff

            else {
                print("[\(name):?]\t\(scanner.string)")
            }
            
        }
    }
}

struct ObjectLibrary {
    var vertices: [Vertex] = []
    var textvert: [TextureVertex] = []
    var normals: [Normal] = []
    var groups: [Group] = []
    var materials = [String: MaterialLibrary]()

    init?(name: String) {
        guard
            let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
            let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        else { return nil }
        
        // iterate over text file lines
        for line in text.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) {
            let scanner = NSScanner(string: line)
            
            if scanner.scanString("#", intoString: nil) {
                if let lib = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    print("[\(name):comment]\t\(lib)")
                }
            }

            else if scanner.scanString("mtllib ", intoString: nil) {
                if let lib = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    print("[\(name):mtllib]\t\(lib)")
                    materials[lib] = MaterialLibrary(name: lib)
                }
            }

            else if scanner.scanString("usemtl ", intoString: nil) {
                if let lib = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    // TODO
                    print("[\(name):usemtl]\t\(lib)")
                }
            }
            
            else if scanner.scanString("g ", intoString: nil) {
                if let gname = scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet()) {
                    groups.append(Group(name: gname, faces: []))
                
                    print("[\(name):grname]\t\(groups.last!.name)")
                }
            }

            else if scanner.scanString("f ", intoString: nil) {
                var face = [FaceElement]()
                while !scanner.atEnd {
                    if let vi = scanner.scanInt(), _ = scanner.scanString("/") {
                        if let _ = scanner.scanString("/"), let ni = scanner.scanInt() {
                            face.append(FaceElement(vi: vi, ti: 0, ni: ni))
                            
                        } else if let ti = scanner.scanInt(), let _ = scanner.scanString("/"), let ni = scanner.scanInt() {
                            face.append(FaceElement(vi: vi, ti: ti, ni: ni))
                        }
                    }
                }

                // I'd rather not mutate anything
                if let g = groups.popLast() {
                    groups.append(Group(name: g.name, faces: g.faces + [face]))
                }
                
                print("[\(name):face]\t<face>")
            }
                
            else if scanner.scanString("v ", intoString : nil) {
                if let x = scanner.scanDouble(), let y = scanner.scanDouble(), let z = scanner.scanDouble() {
                    if let w = scanner.scanDouble() {
                        vertices.append(Vertex(x: x, y: y, z: z, w: w))
                    } else {
                        vertices.append(Vertex(x: x, y: y, z: z, w: 1.0))
                    }
                    print("[\(name):vertex]\t\(vertices.last!)")
                }
            }
            
            else if scanner.scanString("vt ", intoString : nil) {
                if let u = scanner.scanDouble(), let v = scanner.scanDouble() {
                    if let w = scanner.scanDouble() {
                        textvert.append(TextureVertex(u: u, v: v, w: w))
                    } else {
                        textvert.append(TextureVertex(u: u, v: v, w: 1.0))
                    }
                    print("[\(name):texver]\t\(textvert.last!)")
                }
            }

            else if scanner.scanString("vn ", intoString : nil) {
                if let i = scanner.scanDouble(), let j = scanner.scanDouble(), let k = scanner.scanDouble() {
                    normals.append(Normal(i: i, j: j, k: k))
                    print("[\(name):normal]\t\(normals.last!)")
                }
            }
            
            else {
                print("[\(name):?]\t\(scanner.string)")
            }
            
        }
        
        print("\(vertices)")
    }
}