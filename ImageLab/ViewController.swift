//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    
    //MARK: Outlets in view
    
    @IBOutlet weak var totalFacesLabel: UILabel!
    @IBOutlet weak var blinkDetectorLabel: UILabel!
    @IBOutlet weak var smileDetctorLabel: UILabel!
    @IBOutlet weak var toggleCamera: UIButton!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorEyeBlink:true,CIDetectorSmile:true,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // For converting the Core Image Coordinates to UIView Coordinates
//        let ciImageSize = inputImage.extent.size
//        var transform = CGAffineTransform(scaleX: 1, y: -1)
//        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        
        // detect faces
        var smile = false
        var blink = 0
        
        let f = getFaces(img: inputImage)
        let numFace = f.count
        print("total faces:", f.count)
        // if no faces, just return original image
        var retImage = inputImage
        var faceBounds = retImage.extent
        // if faces == 1 detect smile and blink
        if f.count == 1 {
            if let face = f.first as? CIFaceFeature {
//                print("found bounds are \(face.bounds)")
                faceBounds = face.bounds
//                print("left eye: ", face.leftEyePosition, " right eye: ", face.rightEyePosition, " mouth: ", face.mouthPosition)
                if face.hasSmile {
//                    print("=========BIG SMILE=========")
                    smile = true
                }
                
                if face.leftEyeClosed && face.rightEyeClosed {
                    blink = 3
                }
                if face.rightEyeClosed && !face.leftEyeClosed {
                    blink = 1
                }
                if face.leftEyeClosed && !face.rightEyeClosed{
                    blink = 2
                }
                retImage = applyFiltersToEM(inputImage: retImage, face: face)
            }
        }else if f.count > 1{
            retImage = applyFiltersToFaces(inputImage: inputImage, features: f)
        }

//        if f.count > 0{
//            retImage = applyFiltersToFaces(inputImage: inputImage, features: f)
//        }
        
        
        
        // if you just want to process on separate queue use this code
        // this is a NON BLOCKING CALL, but any changes to the image in OpenCV cannot be displayed real time
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
//            self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
//            self.bridge.processImage()
//        }
        
        // use this code if you are using OpenCV and want to overwrite the displayed image via OpenCv
        // this is a BLOCKING CALL
//        self.bridge.setTransforms(self.videoManager.transform)
//        self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
//        self.bridge.processImage()
//        retImage = self.bridge.getImage()
        
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: faceBounds, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        
        DispatchQueue.main.async {
            self.totalFacesLabel.text = "Total faces: " + String(numFace)
            if smile {
                self.smileDetctorLabel.text = "Yes, Sweet!"
            }else{
                self.smileDetctorLabel.text = "Say Cheese"
            }
            switch blink {
            case 1:
                self.blinkDetectorLabel.text = "blink eye: right"
                break
            case 2:
                self.blinkDetectorLabel.text = "blink eye: left"
                break
            case 3:
                self.blinkDetectorLabel.text = "both closed"
                break
            default:
                self.blinkDetectorLabel.text = "try to blink"
            }
        
        }
//        self.bridge.processImage()
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
        
        
        let filterBlur = CIFilter(name:"CITwirlDistortion")!
        filterBlur.setValue(75, forKey: "inputRadius")
        filterBlur.setValue(3.14, forKey: "inputAngle")
        filters.append(filterBlur)
        
        
    }
    
    //MARK: Apply filters to eyes and mouth
    func applyFiltersToEM(inputImage:CIImage, face:CIFaceFeature)->CIImage{
        var retImage = inputImage
        var filterCenters = [CGPoint]()
        filterCenters.append(face.leftEyePosition)
        filterCenters.append(face.rightEyePosition)
        filterCenters.append(face.mouthPosition)
        
        print(filterCenters)
        
        for fc in filterCenters {
            filters[0].setValue(retImage, forKey: kCIInputImageKey)
            filters[0].setValue(CIVector(cgPoint: fc), forKey: "inputCenter")
            // could also manipualte the radius of the filter based on face size!
            retImage = filters[0].outputImage!

        }
        return retImage
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
            filters[1].setValue(retImage, forKey: kCIInputImageKey)
            filters[1].setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
            // could also manipualte the radius of the filter based on face size!
            retImage = filters[1].outputImage!
        }
        return retImage
    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [
            CIDetectorImageOrientation:self.videoManager.ciOrientation,
            CIDetectorSmile: true,
            CIDetectorEyeBlink: true
        ] as [String: Any]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
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

   
}

