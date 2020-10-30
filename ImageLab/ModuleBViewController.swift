//
//  ModuleBViewController.swift
//  ImageLab
//
//  Created by Reid Russell on 10/30/20.
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class ModuleBViewController: UIViewController {


    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    


    @IBOutlet var cameraView: UIView!
    
    @IBOutlet var subView: UIView!
    
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.subView)
        }()
    
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel!
    
    @IBOutlet weak var toggleFlash: UIButton!
    @IBOutlet weak var toggleCamera: UIButton!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.bridge.loadHaarCascade(withFilename: "nose")
        self.videoManager = VideoAnalgesic(mainView: self.cameraView)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
     
        

        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
        

        self.view.addSubview(self.subView)
        self.view.addSubview(self.cameraView)
        
        graph?.addGraph(withName: "PPG", shouldNormalize: true, numPointsInGraph: 100)
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
       
    
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        
        // if no faces, just return original image
        
        var retImage = inputImage
        

        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        self.videoManager.turnOnFlashwithLevel(0.2)
        let finger = self.bridge.processFinger()
        if finger{
            if self.bridge.checkR(){
                self.updateGraph()
                let hr = self.bridge.processHeartRate()
                NSLog("%f",hr)
            }
        }
//        if finger != nil{
//        DispatchQueue.main.async {
//
//                if finger{
//                    self.toggleFlash.isHidden = true
//                    self.toggleCamera.isHidden = true
//                    self.videoManager.turnOnFlashwithLevel(1.0)
//                }
//                else{
//                    self.toggleFlash.isHidden = false
//                    self.toggleCamera.isHidden = false
//                    self.videoManager.turnOffFlash()
//                }
//
//        }
//        }
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        
        return retImage
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filters.append(filterPinch)
        
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        for f in features {
            //set where to apply filter
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            
            //do for each filter (assumes all filters have property, "inputCenter")
            for filt in filters{
                filt.setValue(retImage, forKey: kCIInputImageKey)
                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                // could also manipualte the radius of the filter based on face size!
                retImage = filt.outputImage!
            }
        }
        return retImage
    }
    
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            self.videoManager.turnOnFlashwithLevel(sender.value)
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }

    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        if self.bridge.checkR(){
            self.graph?.updateGraph(
                data: self.bridge.getR() as! [Float],
                forKey: "PPG"
            )
        
        }
        
        
        
    }
}
