//
//  GameObject.swift
//  TowerVille
//
//  Created by Daniel Tian on 2018-01-24.
//  Copyright © 2018 The-Fighting-Mongeese. All rights reserved.
//

import Foundation

class GameObject {
    var id : String?
    var destroy : Bool = false
    var x: Float = 0
    var y : Float = 0
    var z : Float = 0
    var xRot : Float = 0
    var yRot : Float = 0
    var zRot : Float = 0
    var xScale : Float = 1
    var yScale : Float = 1
    var zScale : Float = 1
    
    func initialize(id : String?, x : Float, z : Float) {
        self.id = id
        self.x = x
        self.z = z
    }
    
    func update(dt : TimeInterval) {
        
    }
    
    func setScale(_ scale : Float) {
        self.xScale = scale
        self.yScale = scale
        self.zScale = scale
    }
    
    class func distanceBetween2D(_ objA : GameObject, _ objB : GameObject) -> Float
    {
        return sqrt( pow(objA.x - objB.x, 2) + pow(objA.z - objB.z, 2) )
    }
}

