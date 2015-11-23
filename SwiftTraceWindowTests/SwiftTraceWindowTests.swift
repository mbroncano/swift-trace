//
//  SwiftTraceWindowTests.swift
//  SwiftTraceWindowTests
//
//  Created by Manuel Broncano Rodriguez on 11/19/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import XCTest
import simd

class SwiftTraceWindowTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testScalar() {
        let a = Scalar(2.1)
        let b = Scalar(5.3)
        
        XCTAssert((a+b) ~= Scalar(7.4), "Adding two scalars")
        XCTAssert((a-b) ~= Scalar(-3.2), "Substracting two scalars")
    }
    
    func testVector() {
        let a = Vec(3.2, 2.9, 1.3)
        let b = Vec(1.4, 3.1, 5.5)
        
        XCTAssert((a+b) ~= Vec(4.6, 6.0, 6.8), "Adding two vectors")
        XCTAssert((a-b) ~= Vec(1.8, -0.2, -4.2), "Substracting two vectors")
        XCTAssert((a*b) ~= Vec(4.48, 8.99, 7.15), "Multiplying two vectors")
        XCTAssert((a%b) ~= Vec(11.92, -15.78, 5.86), "Cross product of two vectors")
    }
    
    func testPixelRGBA() {
        let a = Color(0.5, 2.0, 3.0)
        let b = PixelRGBA(color: a)
        let c = PixelRGBA(a: 0, r: 127, g: 255, b: 255)
        
        XCTAssertEqual(b, c, "Initializing PixelRGBA")
    }
    
    func testSphere() {
        let a = Sphere(rad: 10, p: Vec(100, 200, 300), e: Vec(), c: Vec(), refl: Refl_t.DIFF)
        let r1 = Ray(o: Vec(), d: Vec(1, 2, 3).norm())
        let r2 = Ray(o: Vec(), d: Vec(-1, -2, -3).norm())
        var res = RayIntersection()
        
        XCTAssert(a.intersect(ray: r1, result: &res), "Successful intersection")
        XCTAssert(res.dist ~= 364.1657386773, "Intersection distance updated")
        XCTAssert(!a.intersect(ray: r2, result: &res), "Unsuccessful intersection")
        XCTAssert(res.dist ~= 364.1657386773, "Intersection distance not updated")
    }
    
    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }*/
    
}
