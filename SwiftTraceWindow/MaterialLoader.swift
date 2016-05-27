//
//  MaterialLoader.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/26/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

enum MaterialLoaderError: ErrorType {
    case InvalidIlluminationModel(String)
    case InvalidColor(String)
    case InvalidScalarParameter(String)
}

/// Definition for an MTL item
struct MaterialTemplate {
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
    }

    /// Ambient Color
    var Ka: Color = Vec.Zero
    /// Diffuse Color
    var Kd: Color = Vec.Zero
    /// Specular Color
    var Ks: Color = Vec.Zero
    /// Emission Color
    var Ke: Color = Vec.Zero
    /// Specular Exponent
    /// Ranges between 0 and 1000
    var Ns: Scalar = 0
    /// Optical Density (refraction)
    /// Ranges from 0.001 to 10, at 1.0 light doesn't beng glass has 1.5
    var Ni: Scalar = 1.0
    /// Dissolve, some implementations use 'Tr' (inverted)
    /// Ranges from 1.0 (opaque) to 0.0 (completely dissolved)
    var d: Scalar = 1.0
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

struct MaterialColor: CustomStringConvertible {
    let r, g, b: Scalar
    var description: String { get { return "(\(r), \(g), \(b))" } }

    init(_ array: [String]) throws {
        guard 3 == array.count
        else { throw ObjectLoaderError.InvalidVertex("invalid color component count") }
        
        self.r = try VertexCoordinate(str: array[0])
        self.g = try VertexCoordinate(str: array[1])
        self.b = try VertexCoordinate(str: array[2])
    }
}

extension Color {
    init(_ v: MaterialColor) { self.init(v.r, v.g, v.b) }
}

extension MaterialTemplate.IlluminationModel {
    init(_ str: String) throws {
        guard let i = Int(str), let illum = MaterialTemplate.IlluminationModel(rawValue: i)
        else { throw MaterialLoaderError.InvalidIlluminationModel("The illumination model \(str) is not supported") }
        
        self = illum
    }
}

extension Scalar {
    init(safe str: String) throws {
        guard let s = Scalar(str)
        else { throw MaterialLoaderError.InvalidScalarParameter("The scalar parameter \(str) is invalid") }
        
        self = s
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
                    mtldict[current!]!.Ka = Color(try MaterialColor(tokenArray))
                case "Kd":
                    mtldict[current!]!.Kd = Color(try MaterialColor(tokenArray))
                case "Ks":
                    mtldict[current!]!.Ks = Color(try MaterialColor(tokenArray))
                case "Ke":
                    mtldict[current!]!.Ke = Color(try MaterialColor(tokenArray))
                case "illum":
                    mtldict[current!]!.illum = try MaterialTemplate.IlluminationModel(tokenArray[0])
                case "Ns":
                    mtldict[current!]!.Ns = try Scalar(safe: tokenArray[0])
                case "Ni":
                    mtldict[current!]!.Ni = try Scalar(safe: tokenArray[0])
                case "Tr":
                    mtldict[current!]!.d = 1.0 / (try Scalar(safe: tokenArray[0]))
                case "d":
                    mtldict[current!]!.d = try Scalar(safe: tokenArray[0])
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
