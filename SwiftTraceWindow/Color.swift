//
//  Color.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 5/25/16.
//  Copyright © 2016 Manuel Broncano Rodriguez. All rights reserved.
//

import Foundation

/// Color is currently an alias for simd.double3
typealias Color = Vec
extension Color {
    /// The color red
    static let Red  =  Color(1, 0, 0)
    /// The color green
    static let Green = Color(0, 1, 0)
    /// The color blue
    static let Blue  = Color(0, 0, 1)
    /// The color white
    static let White = Color(1, 1, 1)
    /// The color black
    static let Black = Color(0, 0, 0)

    func gammaCorrected() -> Color {
        let gamma: Scalar = 0.45
        return Color(pow(x, gamma), pow(y, gamma), pow(z, gamma))
    }
}