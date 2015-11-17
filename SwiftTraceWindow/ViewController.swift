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

        // Do any additional setup after loading the view.
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let scene = Scene(w: 320, h: 240)
            while true {
                // render another frame
                let start = NSDate().timeIntervalSince1970
                scene.render()
                let duration = NSDate().timeIntervalSince1970 - start
                print("Profiler: completed in \(duration * 1000)ms")

                // update the UI
                let image = scene.framebuffer.cgImage()
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView!.image = NSImage(CGImage: image, size: NSZeroSize)
                    self.view.window!.title = "Samples \(scene.total_samples)"
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

