//
//  ViewController.swift
//  SwiftTraceWindow
//
//  Created by Manuel Broncano Rodriguez on 11/15/15.
//  Copyright © 2015 Manuel Broncano Rodriguez. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadScene()
    }

    func loadScene() {
        // dispatch the main routine
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let width = 320, height = 240
            var scene: Scene
            var render: Renderer

            do {
                let file = NSBundle.mainBundle().pathForResource("scene", ofType: "json")!
                let data = NSData(contentsOfFile: file)!
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                scene = try Scene.decode(json)
                
                // FIXME: load materials from scene file
                try scene.defaultMaterials()
            } catch {
                print(error)
                return
            }
            
            // FIXME: choose the renderer from the scene file
            render = PathTracer(scene: scene, w: width, h: height)
//            let render = DistributedRayTracer(scene: scene, w: width, h: height)
//            let render = WhittedTracer(scene: scene, w: width, h: height)
            
            var avg:NSTimeInterval = 0
            while true {
                let start = NSDate().timeIntervalSince1970
                
                // render a frame
                render.render() //Tile(size: 64)
                
                let duration = NSDate().timeIntervalSince1970 - start
                avg = avg + duration
                print("Profiler: frame in \(Int(duration * 1000))ms, avg. \(Int(avg * 1000 / Double(render.framebuffer.samples)))ms")
                
                // update the UI at least once a second or every ten samples
                if duration < 1.0 && (render.framebuffer.samples % 10 != 1) { continue }
                
                // FIXME: warn the user if there is any problem
                guard let image = render.framebuffer.cgImage() else { continue }
                
                // update window on the main loop
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView!.image = NSImage(CGImage: image, size: NSZeroSize)
                    self.view.window!.title = "Samples \(render.framebuffer.samples)"
                }
            }
        }
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }


}

