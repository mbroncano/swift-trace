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

struct FaceElement: CustomStringConvertible {
    let vi, ti, ni: Int?

    var description: String { get { return "(\(vi), \(ti), \(ni))" } }
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


struct BaseLoader {
    let scanner: NSScanner

    init?(name: String) {
        guard
            let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
            let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            else { print("Error reading file: \(name)"); return nil }
    
        scanner = NSScanner(string: text as String)
    }
    
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
        
        let scanner = NSScanner(string: text as String)
        
        var start = NSDate().timeIntervalSince1970

        // iterate over text file lines
        var line: NSString?
        while scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet(), intoString: &line) {
            
            if (NSDate().timeIntervalSince1970 - start) > 1 {
                start = NSDate().timeIntervalSince1970
                let percentage = 100 * scanner.scanLocation / text.length
                print("[\(name):loading]\t\(percentage)%")
            }
            
            guard var tokenArray = line?.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) else { return nil }
            tokenArray = tokenArray.filter({ (s: String) -> Bool in
                s.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0
            })
            let token = tokenArray.removeFirst()

            if token == "#" {
                print("[\(name):comment]\t\(line)")
            }

            else if token == "mtllib" {
                let lib = tokenArray[0]
                materials[lib] = MaterialLibrary(name: lib)
                print("[\(name):mtllib]\t\(lib)")
            }

            else if token == "usemtl" {
                let lib = tokenArray[0]
                print("[\(name):usemtl]\t\(lib)")
            }
            
            else if token == "g" {
                let gname = tokenArray[0]
                groups.append(Group(name: gname, faces: []))
                print("[\(name):grname]\t\(groups.last!.name)")
            }

            else if token == "f" {
                var face = [FaceElement]()
                
                let separator = NSCharacterSet.init(charactersInString: "/")
                for item in tokenArray {
                    let elems = item.componentsSeparatedByCharactersInSet(separator)
                
                    let vi = (elems.count > 0) ? Int(elems[0]) : nil
                    let ni = (elems.count > 1) ? Int(elems[1]) : nil
                    let ti = (elems.count > 2) ? Int(elems[2]) : nil

                    face.append(FaceElement(vi: vi, ti: ti, ni: ni))
                }

                // I'd rather not mutate anything
                if let g = groups.popLast() {
                    groups.append(Group(name: g.name, faces: g.faces + [face]))
                }
                
                print("[\(name):face]\t\(face)")
            }

            else if token == "v" {
                guard 3...4 ~= tokenArray.count,
                      let x = Double(tokenArray[0]),
                      let y = Double(tokenArray[1]),
                      let z = Double(tokenArray[2])
                else {
                    print("[\(name):vertex]\t error parsing <\(line)>")
                    continue;
                    }
            
                if tokenArray.count == 4 {
                    guard let w = Double(tokenArray[3]) else { continue }
                    vertices.append(Vertex(x: x, y: y, z: z, w: w))
                } else {
                    vertices.append(Vertex(x: x, y: y, z: z, w: 1.0))
                }
                    print("[\(name):vertex]\t\(vertices.last!)")
            }
            
            else if token == "vt" {
                guard 2...3 ~= tokenArray.count,
                      let u = Double(tokenArray[0]),
                      let v = Double(tokenArray[1])
                else {
                    print("[\(name):vtext]\t error parsing <\(line)>")
                    continue;
                    }

                if tokenArray.count == 3 {
                    guard let w = Double(tokenArray[2]) else { continue }
                    textvert.append(TextureVertex(u: u, v: v, w: w))
                } else {
                    textvert.append(TextureVertex(u: u, v: v, w: 0.0))
                }

                print("[\(name):texver]\t\(textvert.last!)")
            }

            else if token == "vn" {
                guard 3 ~= tokenArray.count,
                      let i = Double(tokenArray[0]),
                      let j = Double(tokenArray[1]),
                      let k = Double(tokenArray[2])
                else {
                    print("[\(name):vnorm]\t error parsing <\(line)>")
                    continue;
                    }

                normals.append(Normal(i: i, j: j, k: k))
                print("[\(name):normal]\t\(normals.last!)")
            }
            
            else {
                print("[\(name):?]\t\(line)")
            }
            
        }
        
//        print("\(vertices)")
    }
}