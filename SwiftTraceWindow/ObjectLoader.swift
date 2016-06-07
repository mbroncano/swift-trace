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

enum MaterialLoaderError: ErrorType {
    case InvalidIlluminationModel(String)
    case InvalidColor(String)
    case InvalidScalarParameter(String)
    case InvalidMaterial(String)
}

typealias FaceVertexIndex = Int
extension FaceVertexIndex {
    var isValid: Bool { get { return self != 0 } }

    init(str: String, count: Int) throws {
        guard str != "" else { self = 0; return } // empty string is a valid case
        
        guard let number = Int(str) where number != 0 else { throw ObjectLoaderError.InvalidVertex("vertex index must not be zero") }
        
        // correct negative indices
        self = number < 0 ? number + count + 1 : number
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
    
    init(str: String, count: [Int]) throws {
        let indices = str.componentsSeparatedByCharactersInSet(FaceElement.slash)
        guard 1...3 ~= indices.count else { throw ObjectLoaderError.InvalidVertex("Invalid string") }
        
        self.vi = try FaceVertexIndex(str: indices[0], count: count[0])
        self.ti = indices.count > 1 ? try FaceVertexIndex(str: indices[1], count: count[1]) : 0
        self.ni = indices.count > 2 ? try FaceVertexIndex(str: indices[2], count: count[2]) : 0
    }
}

struct Face {
    let elements: [FaceElement]
    let material: String?

    init(_ array: [String], count: [Int], material: String? = nil) throws {
        guard array.count >= 3 else { throw ObjectLoaderError.InvalidFace("A face need at least three elements") }
    
        var temp = [FaceElement]()
    
        for str in array {
            let element = try FaceElement(str: str, count: count)
            
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
    var mtllib = [String: MaterialTemplate]()
    let name: String
    let transform: Transform?

    init(name: String, transform: Transform? = nil) throws {
        self.name = name
        self.transform = transform
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
                faces.append(try Face(tokenArray, count: [vertices.count, normals.count, textvert.count], material: currentMaterial))
//                print("[\(name):face]\t\(faces.last!)")

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
                try tokenArray.forEach({ lib in
                    try MaterialLoader(name: lib).mtldict.forEach({ mtllib[$0] = $1 })
                    print("[\(name):mtllib]\t\(lib)")
                })

            case "usemtl":
                currentMaterial = tokenArray[0]
                print("[\(name):usemtl]\t\(currentMaterial)")

            default:
                print("[\(name):????]\t\(line)")
            }
        }
    }
}

struct MaterialLoader {
    var mtldict = [String: MaterialTemplate]()

    init(name: String) throws {
        guard
        let path = NSBundle.mainBundle().pathForResource(name, ofType: ""),
        let text = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        else { throw ObjectLoaderError.InvalidFile("material file not found") }
        
        let scanner = NSScanner(string: text as String)
        
        var current: String?
        var line: NSString?
        while scanner.scanUpToCharactersFromSet(NSCharacterSet.newlineCharacterSet(), intoString: &line) {
            
            guard var tokenArray = line?.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            else { throw ObjectLoaderError.InvalidFile("invalid file line") }
            
            tokenArray = tokenArray.filter({ s in s != "" })
            let token = tokenArray.removeFirst()

            // FIXME: implement parameters
            switch token {
                case "newmtl":
                    current = tokenArray[0]
                    mtldict[current!] = MaterialTemplate()
                case "Ka":
                    mtldict[current!]!.Ka = try MaterialTemplate.MaterialColor(tokenArray)
                case "Kd":
                    mtldict[current!]!.Kd = try MaterialTemplate.MaterialColor(tokenArray)
                case "Ks":
                    mtldict[current!]!.Ks = try MaterialTemplate.MaterialColor(tokenArray)
                case "Ke":
                    mtldict[current!]!.Ke = try MaterialTemplate.MaterialColor(tokenArray)
                case "illum":
                    mtldict[current!]!.illum = try MaterialTemplate.IlluminationModel(tokenArray[0])
                case "Ns":
                    mtldict[current!]!.Ns = try MaterialTemplate.parameter(safe: tokenArray[0])
                case "Ni":
                    mtldict[current!]!.Ni = try MaterialTemplate.parameter(safe: tokenArray[0])
                case "Tr":
                    mtldict[current!]!.d = 1.0 / (try MaterialTemplate.parameter(safe: tokenArray[0]))
                case "d":
                    mtldict[current!]!.d = try MaterialTemplate.parameter(safe: tokenArray[0])
                case "map_Kd":
                    mtldict[current!]!.map_Kd = try Texture(name: tokenArray[0])
                case "#":
                    print("[\(name):comment]\t\(line)")
                default:
                    print("[\(name):???????]\t\(line)")
                    continue
            }
        }
    }
}



/// Definition for an MTL item
struct MaterialTemplate {
    static func parameter(safe str: String) throws -> Real {
        guard let s = Real(str) where s.isFinite
        else { throw MaterialLoaderError.InvalidScalarParameter("invalid scalar parameter \(str)") }
        
        return s
    }

    struct MaterialColor: CustomStringConvertible {
        let color: Spectrum
        var description: String { get { return "(\(color.x), \(color.y), \(color.z)" } }
        
        static func RGBColorComponent(color: String) throws -> Real {
            guard color.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0
            else { throw MaterialLoaderError.InvalidColor("color component must not be empty") }
            
            guard let s = Real(color) where s.isFinite && s >= 0
            else { throw ObjectLoaderError.InvalidVertex("invalid color component <\(color)>") }
            
            return s
        }
        
        init() { self.init(color: Spectrum.Black) }
        init(color: Spectrum) { self.color = color }
        
        init(_ array: [String]) throws {
            guard array[0] != "xyz" else { throw MaterialLoaderError.InvalidColor("CIE XYZ colors not supported yet") }
            guard array[0] != "spectral" else { throw MaterialLoaderError.InvalidColor("spectral curves not supported yet") }
            
            switch array.count {
            case 1:
                self.color = Spectrum(try MaterialColor.RGBColorComponent(array[0]))
            case 3:
                self.color = Spectrum(try MaterialColor.RGBColorComponent(array[0]),
                                      try MaterialColor.RGBColorComponent(array[1]),
                                      try MaterialColor.RGBColorComponent(array[2]))
            default: throw MaterialLoaderError.InvalidColor("RGB color can have only 0 or 3 components")
            }
        }
    }

    enum IlluminationModel: Int {
        /// 0. Color on and Ambient off
        case ColorOnAndAmbientOff = 0
        /// 1. Color on and Ambient on
        case ColorOnAndAmbientOn
        /// 2. Highlight on
        case HighlightOn
        /// 3. Reflection on and Ray trace on
        case ReflectionOnAndRayTraceOn
        /// 4. Transparency: Glass on, Reflection: Ray trace on
        case Transparency4
        /// 5. Reflection: Fresnel on and Ray trace on
        case Reflection5
        /// 6. Transparency: Refraction on, Reflection: Fresnel off and Ray trace on
        case Transparency6
        /// 7. Transparency: Refraction on, Reflection: Fresnel on and Ray trace on
        case Transparency7
        /// 8. Reflection on and Ray trace off
        case Reflection8
        /// 9. Transparency: Glass on, Reflection: Ray trace off
        case Transparency9
        /// 10. Casts shadows onto invisible surfaces    
        case CastShadowsOntoInvisibleSurfaces
        
        init(_ str: String) throws {
            guard let i = Int(str), let illum = MaterialTemplate.IlluminationModel(rawValue: i)
            else { throw MaterialLoaderError.InvalidIlluminationModel("The illumination model \(str) is not supported") }
            
            self = illum
        }
    }

    /// Ambient Color
    var Ka: MaterialColor = MaterialColor()
    /// Diffuse Color
    var Kd: MaterialColor = MaterialColor()
    /// Specular Color
    var Ks: MaterialColor = MaterialColor()
    /// Emission Color
    var Ke: MaterialColor = MaterialColor()
    /// Specular Exponent
    /// Ranges between 0 and 1000
    var Ns: Real = 0.0
    /// Optical Density (refraction)
    /// Ranges from 0.001 to 10, at 1.0 light doesn't beng glass has 1.5
    var Ni: Real = 1.0
    /// Dissolve, some implementations use 'Tr' (inverted)
    /// Ranges from 1.0 (opaque) to 0.0 (completely dissolved)
    var d: Real = 1.0
    /// Illumination model
    var illum: IlluminationModel = .ColorOnAndAmbientOn
    /// The ambient texture map
    var map_Ka: Texture? = nil
    /// The diffuse texture map
    var map_Kd: Texture? = nil
    /// The specular color texture map
    var map_Ks: Texture? = nil
    /// The alpha texture map
    var map_Tr: Texture? = nil
}