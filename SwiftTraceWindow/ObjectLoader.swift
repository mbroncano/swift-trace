//
//  Loader.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/19/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

// http://www.martinreddy.net/gfx/3d/OBJ.spec

extension Vector {
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
        
        guard let number = Int(str) where number != 0 else { throw ObjectLoaderError.InvalidVertex("vertex index must not be zero") }
        
        self = number
    }
}

typealias VertexCoordinate = Real
extension VertexCoordinate {
    init(str: String) throws {
        guard str.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0
        else { throw ObjectLoaderError.InvalidVertex("vertex coordinate must not be empty") } // empty string is a *not* valid case
        
        guard let s = VertexCoordinate(str) where (s.isFinite)
        else { throw ObjectLoaderError.InvalidVertex("invalid vertex coordinate <\(str)>") }
        
        self = s
    }
}

protocol FaceVertex {
    init(_ array: [String]) throws
}

struct Vertex: FaceVertex, CustomStringConvertible {
    let x, y, z, w: VertexCoordinate
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
    let u, v, w: VertexCoordinate
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
    let i, j, k: VertexCoordinate
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
    let material: String?

    init(_ array: [String], material: String? = nil) throws {
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
         self.material = material
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
//    var mtllib = [String: MaterialTemplate]()

    init(name: String) throws {
        guard
            let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
            let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        else { throw ObjectLoaderError.InvalidFile("object file not found") }
        
        let scanner = NSScanner(string: text as String)
        
        var start = NSDate().timeIntervalSince1970

        var currentMaterial: String? = nil
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
                faces.append(try Face(tokenArray, material: currentMaterial))
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
/*
            case "mtllib":
                try tokenArray.forEach({ lib in
                    try MaterialLoader(name: lib).mtldict.forEach({ mtllib[$0] = $1 })
                    print("[\(name):mtllib]\t\(lib)")
                })
*/
            case "usemtl":
                currentMaterial = tokenArray[0]
                print("[\(name):usemtl]\t\(currentMaterial)")

            default:
                print("[\(name):????]\t\(line)")
            }
        }
    }
}

