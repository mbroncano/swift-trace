//
//  Loader.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/19/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

// http://www.martinreddy.net/gfx/3d/OBJ.spec

extension Vec {
    init(_ v: Vertex)        { self.init(v.x, v.y, v.z) }
    init(_ v: TextureVertex) { self.init(v.u, v.v, v.w) }
    init(_ v: VertexNormal)  { self.init(v.i, v.j, v.k) }
}

enum ObjectLoaderError: ErrorType {
    case InvalidVertex(String)
    case InvalidFace(String)
    case InvalidFile(String)
}

typealias FaceVertexIndex = Int
extension FaceVertexIndex {
    var isValid: Bool { get { return self != 0 } }

    init(str: String) throws {
        guard str != "" else { self = 0; return } // empty string is a valid case
        
        guard let int = Int(str) where (int != 0)
        else { throw ObjectLoaderError.InvalidVertex("vertex index must not be zero") }
        
        self = int
    }
}

typealias VertexCoordinate = Double
extension VertexCoordinate {
    init(str: String) throws {
        guard str.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0
        else { throw ObjectLoaderError.InvalidVertex("vertex coordinate must not be empty") } // empty string is a *not* valid case
        
        guard let dbl = Double(str) where (dbl.isFinite)
        else { throw ObjectLoaderError.InvalidVertex("invalid vertex coordinate <\(str)>") }
        
        self = dbl
    }
}

protocol FaceVertex {
    init(_ array: [String]) throws
}

struct Vertex: FaceVertex, CustomStringConvertible {
    let x, y, z, w: Scalar
    var description: String { get { return "(\(x), \(y), \(z), \(w))" } }
    
    init(_ array: [String]) throws {
        guard 3...4 ~= array.count
        else { throw ObjectLoaderError.InvalidVertex("invalid vertex coordinate count") }
        
        self.x = try VertexCoordinate(str: array[0])
        self.y = try VertexCoordinate(str: array[1])
        self.z = try VertexCoordinate(str: array[2])
        self.w = array.count == 4 ? try VertexCoordinate(str: array[3]) : 1.0
    }
}

struct TextureVertex: FaceVertex, CustomStringConvertible {
    let u, v, w: Scalar
    var description: String { get { return "(\(u), \(v), \(w))" } }

    init(_ array: [String]) throws {
        guard 2...3 ~= array.count
        else { throw ObjectLoaderError.InvalidVertex("invalid texture vertex coordinate count") }
        
        self.u = try VertexCoordinate(str: array[0])
        self.v = try VertexCoordinate(str: array[1])
        self.w = array.count == 3 ? try VertexCoordinate(str: array[2]) : 0.0
    }
}

struct VertexNormal: FaceVertex, CustomStringConvertible {
    let i, j, k: Scalar
    var description: String { get { return "(\(i), \(j), \(k))" } }

    init(_ array: [String]) throws {
        guard 3 == array.count
        else { throw ObjectLoaderError.InvalidVertex("invalid vertex normal coordinate count") }
        
        self.i = try VertexCoordinate(str: array[0])
        self.j = try VertexCoordinate(str: array[1])
        self.k = try VertexCoordinate(str: array[2])
    }
}

struct FaceElement: CustomStringConvertible {
    enum FaceElementType: Int {
        case VertexOnly = 1
        case VertexAndTexture = 3
        case VertexAndNormal = 5
        case VertexAndTextureAndNormal = 7
    }
    
    var type: FaceElementType? { // it'd be a waste to store this
        get {
            let v = Int(vi != 0)
            let t = Int(ti != 0) * 2
            let n = Int(ni != 0) * 4
            
            return FaceElementType(rawValue: v+t+n)
        }
    }

    let vi, ti, ni: FaceVertexIndex
    var description: String { get { return "(\(vi), \(ti), \(ni))" } }

    private static let slash = NSCharacterSet(charactersInString: "/")
    
    init(str: String) throws {
        let indices = str.componentsSeparatedByCharactersInSet(FaceElement.slash)
        guard 1...3 ~= indices.count else { throw ObjectLoaderError.InvalidVertex("Invalid string") }
        
        self.vi = try FaceVertexIndex(str: indices[0])
        self.ti = indices.count > 1 ? try FaceVertexIndex(str: indices[1]) : 0
        self.ni = indices.count > 2 ? try FaceVertexIndex(str: indices[2]) : 0
    }
}

struct Face {
    let elements: [FaceElement]

    init(_ array: [String]) throws {
        guard array.count >= 3 else { throw ObjectLoaderError.InvalidFace("A face need at least three elements") }
    
        var temp = [FaceElement]()
    
        for str in array {
            let element = try FaceElement(str: str)
            
            if temp.count > 0 {
            guard let type = element.type where /*temp.count > 0 &&*/ type == temp[0].type!
            else { throw ObjectLoaderError.InvalidFace("Face element types must be the same within a single face")  }
            }
         
            temp.append(element)
         }
        
         self.elements = temp // we want for it to be a constant member
    }
}

extension _ArrayType where Generator.Element: FaceVertex {
    subscript(index index: FaceVertexIndex) -> Generator.Element? {
        guard index.isValid else { return nil }
        let ofs = index < 0 ? index.advancedBy(self.count) : index.advancedBy(-1)
        guard ofs < self.count else { return nil }
        
        return self[ofs]
    }
}

struct ObjectLibrary {
    var vertices = [Vertex]()
    var textvert = [TextureVertex]()
    var normals = [VertexNormal]()
    var faces = [Face]()

    func mesh(mid: MaterialId) throws -> [Primitive] {
        var ret = [Primitive]()
        
        try faces.forEach { face in
            guard let type = face.elements[0].type else { throw ObjectLoaderError.InvalidFace("Invalid type for face") }
        
            for index in 2..<face.elements.count {
                let slice = face.elements[(index-2)...index]
        
                var p = [Vec]()
                var t = [Vec]()
                var n = [Vec]()
                
                for element in slice {
                    guard let pi = vertices[index: element.vi]
                    else { throw ObjectLoaderError.InvalidFace("invalid vertex index") }
                    
                    p.append(Vec(pi))
                    
                    // FIXME: this won't detect whether the index is out of bouds or zero
                    if let ti = textvert[index: element.ti] { t.append(Vec(ti)) }
                    if let ni = normals[index: element.ni] { n.append(Vec(ni)) }
                }
                
                // FIXME: add normals for triangle primitive
                switch type {
                case .VertexAndNormal: fallthrough
                case .VertexOnly:
                    ret.append(Triangle(p1: p[0], p2: p[1], p3: p[2], material: mid))
                case .VertexAndTextureAndNormal: fallthrough
                case .VertexAndTexture:
                    ret.append(Triangle(p[0], p[1], p[2], mid, t[0], t[1], t[2]))
                }
            }
        }
        return ret
    }

    init(name: String) throws {
        guard
            let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
            let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        else { throw ObjectLoaderError.InvalidFile("object file not found") }
        
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
            
            guard var tokenArray = line?.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            else { throw ObjectLoaderError.InvalidFile("invalid file line") }
            
            tokenArray = tokenArray.filter({ s in s != "" })
            let token = tokenArray.removeFirst()

            switch token {
            case "f":
                faces.append(try Face(tokenArray))
//                print("[\(name):face]\t\(face)")

            case "v":
                vertices.append(try Vertex(tokenArray))
//                print("[\(name):vertex]\t{\(vertices.count)}\(vertices.last!)")
            
            case "vt":
                textvert.append(try TextureVertex(tokenArray))
//                print("[\(name):texver]\t{\(textvert.count)}\(textvert.last!)")

            case "vn":
                normals.append(try VertexNormal(tokenArray))
//                print("[\(name):normal]\t{\(normals.count)}\(normals.last!)")

            case "#":
                print("[\(name):comment]\t\(line)")

            case "mtllib":
                let lib = tokenArray[0]
                print("[\(name):mtllib]\t\(lib)")
            
            case "usemtl":
                let lib = tokenArray[0]
                print("[\(name):usemtl]\t\(lib)")
            
            case "g":
                let gname = tokenArray[0]
                print("[\(name):grname]\t\(gname)")

            default:
                print("[\(name):????]\t\(line)")
            }
        }
    }
}