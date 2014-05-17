//
//  UIFacialGestureRecognizer.m
//  iScream
//
//  Created by Paul de Lange on 14/05/2014.
//  Copyright (c) 2014 Gilmert Bentley. All rights reserved.
//

#import "UIFacialGestureRecognizer.h"

#import "FaceObject.h"

#import <opencv2/opencv.hpp>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

static inline cv::Rect CVRectFromCGRect(CGRect rect) {
    return cv::Rect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

static inline AVCaptureVideoOrientation AVCaptureVideoOrientationFromUIDeviceOrientation(UIDeviceOrientation orientation) {
    // NSLog(@"Orientation: %d", orientation);
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

static CGImageRef CGImageCreateFromOpenCVMatrix(const cv::Mat& cvMat) {
    
    CFDataRef data = CFDataCreate(NULL, cvMat.data, cvMat.elemSize() * cvMat.total());
    
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    CFRelease(data);
    
    return imageRef;
}

@interface UIFacialGestureRecognizer () <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession*                       _captureSession;
    
    dispatch_queue_t                        _dataProcessingQueue;
    dispatch_queue_t                        _videoProcessingQueue;
    
    AVCaptureMetadataOutput*                _metatdataOutput;
    AVCaptureVideoDataOutput*               _videoDataOutput;
    
    BOOL _hasLeftEye, _hasRightEye;
}

@property (copy, atomic) NSSet* faces;

@end

@implementation UIFacialGestureRecognizer

- (void) start {
    NSParameterAssert(![_captureSession isRunning]);
    
    AVCaptureMetadataOutput* metadataOutput = [AVCaptureMetadataOutput new];
    
    if([_captureSession canAddOutput: metadataOutput]) {
        [_captureSession addOutput: metadataOutput];
    }
    else {
        //Error
        NSLog(@"Couldn't add metadata output");
        return;
    }
    
    if([metadataOutput.availableMetadataObjectTypes containsObject: AVMetadataObjectTypeFace]) {
        metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
    }
    else {
        //Error
        NSLog(@"Couldn't use face detection");
        return;
    }
    
    _metatdataOutput = metadataOutput;
    [_metatdataOutput setMetadataObjectsDelegate: self queue: _dataProcessingQueue];
    
    _videoDataOutput = [AVCaptureVideoDataOutput new];
    _videoDataOutput.videoSettings = @{
                                       (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                       };
    _videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    if( [_captureSession canAddOutput: _videoDataOutput] ) {
        [_captureSession addOutput: _videoDataOutput];
    }
    else {
        //Error
        NSLog(@"Couldn't add video output");
        return;
    }
    
    [_videoDataOutput setSampleBufferDelegate: self queue: _videoProcessingQueue];
    
    AVCaptureConnection* videoConnection = [_videoDataOutput connectionWithMediaType: AVMediaTypeVideo];
    videoConnection.videoOrientation = AVCaptureVideoOrientationFromUIDeviceOrientation([[UIDevice currentDevice] orientation]);
    
    [_captureSession startRunning];
}

- (void) stop {
    if( [_captureSession isRunning] ) {
        [_captureSession stopRunning];
    }
    
    [_metatdataOutput setMetadataObjectsDelegate: nil queue: nil];
    _metatdataOutput = nil;
    
    [_videoDataOutput setSampleBufferDelegate: nil queue: nil];
    _videoDataOutput = nil;
    
    _faces = nil;
}

#pragma mark - Notifications
- (IBAction) deviceOrientationChanged:(NSNotification*)sender {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    AVCaptureConnection* videoConnection = [_videoDataOutput connectionWithMediaType: AVMediaTypeVideo];
    videoConnection.videoOrientation = AVCaptureVideoOrientationFromUIDeviceOrientation(orientation);
}

#pragma mark - NSObject
- (void) dealloc {
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - UIGestureRecognizer
- (instancetype) initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget: target action: action];
    if( self ) {
        _dataProcessingQueue = dispatch_queue_create("Data Processing", DISPATCH_QUEUE_SERIAL);
        _videoProcessingQueue = dispatch_queue_create("Video Processing", DISPATCH_QUEUE_SERIAL);
        
        NSString* preset = AVCaptureSessionPresetHigh;
        _captureSession = [AVCaptureSession new];
        if([_captureSession canSetSessionPreset: preset]) {
            _captureSession.sessionPreset = preset;
        }
        
#if TARGET_OS_IPHONE
        for(AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType: AVMediaTypeVideo]) {
            if( device.position == AVCaptureDevicePositionFront ) {
                
                __autoreleasing NSError* error;
                AVCaptureDeviceInput* defaultInput = [AVCaptureDeviceInput deviceInputWithDevice: device error: &error];
                NSAssert(!error, @"Error creating input device: %@", error);
                NSAssert([_captureSession canAddInput: defaultInput], @"Can not add device: %@", defaultInput);
                [_captureSession addInput: defaultInput];
                
                break;
            }
        }
#endif
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(deviceOrientationChanged:)
                                                     name: UIDeviceOrientationDidChangeNotification
                                                   object: nil];
        
        [self start];
    }
    
    return self;
}

- (void) setEnabled:(BOOL)enabled {
    [super setEnabled: enabled];
    
    if( enabled ) {
        [self start];
    }
    else {
        [self stop];
    }
}

- (void) reset {
    
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    if( self.state == UIGestureRecognizerStateRecognized ) {
        self.state = UIGestureRecognizerStateEnded;
    }
    
    if ( metadataObjects.count == 0 ) {
        self.faces = nil;
        return;
    }
    
    if( self.state == UIGestureRecognizerStateCancelled ||
       self.state == UIGestureRecognizerStateEnded ||
       self.state == UIGestureRecognizerStateFailed ) {
        self.state = UIGestureRecognizerStateBegan;
    }
    
    @autoreleasepool {
        
        NSMutableSet* facesToSave = [NSMutableSet set];
        
        for ( AVMetadataObject *object in metadataObjects ) {
            if ( [[object type] isEqual:AVMetadataObjectTypeFace] ) {
                AVMetadataFaceObject* face = (AVMetadataFaceObject*)object;
                
                FaceObject* aFaceObject;
                NSSet* trackedAndMatchingFaces = [_faces filteredSetUsingPredicate: [NSPredicate predicateWithFormat: @"foundationID = %d", face.faceID]];
                aFaceObject = trackedAndMatchingFaces.anyObject;
                
                if( !aFaceObject ) {
                    aFaceObject = [FaceObject new];
                    aFaceObject.foundationID = face.faceID;
                }
                
                aFaceObject.bounds = [face bounds];
                
                
                NSParameterAssert([face hasRollAngle]);
                NSParameterAssert([face hasYawAngle]);
                
                //NSLog(@"Roll: %f, Yaw: %f", face.rollAngle, face.yawAngle);
                
                //TODO: Roll depends on the rotation
                
                //aFaceObject.isFacingCamera = /*fabs(face.rollAngle) < 45 &&*/ fabs(face.yawAngle) < 45;
                
                [facesToSave addObject: aFaceObject];
            }
        }
        
        self.faces = facesToSave;
        
        if( [facesToSave count] ) {
            if( self.state == UIGestureRecognizerStateBegan ) {
                self.state = UIGestureRecognizerStatePossible;
            }
        }
        else {
            if( self.state == UIGestureRecognizerStateBegan ) {
                self.state = UIGestureRecognizerStateFailed;
            }
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        NSSet* faces = self.faces;
        
        if( [faces count] <= 0 )
            return;
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        //Images are coming in YUV format, the first channel is the intensity (luma)...
        size_t lumaPlane = 0;
        
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        uint8_t* baseAddress = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, lumaPlane);
        size_t width = CVPixelBufferGetWidthOfPlane(imageBuffer, lumaPlane);
        size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer, lumaPlane);
        
        //Take Core Video pixel buffer and convert it to a openCV image matrix
        cv::Mat gray(cv::Size((int)width, (int)height), CV_8UC1, baseAddress, cv::Mat::AUTO_STEP);
        
        FaceObject* biggestFace = [faces anyObject];
        
        for(FaceObject* face in faces) {
            
            CGRect bounds = [captureOutput rectForMetadataOutputRectOfInterest: face.bounds];
            
            if( CGRectContainsRect(CGRectMake(0, 0, width, height), bounds) ) {
                //If the face is inside the capture frame
                CGRect biggestBounds = [captureOutput rectForMetadataOutputRectOfInterest: biggestFace.bounds];
                CGFloat biggestArea = CGRectGetWidth(biggestBounds) * CGRectGetHeight(biggestBounds);
                CGFloat faceArea = CGRectGetWidth(bounds) * CGRectGetHeight(bounds);
                
                if( faceArea > biggestArea ) {
                    biggestFace = face;
                }
            }
        }
        
        if( biggestFace ) {
            CGRect bounds = [captureOutput rectForMetadataOutputRectOfInterest: biggestFace.bounds];
            if( CGRectGetMaxY(bounds) < height && CGRectGetMaxX(bounds) < width ) {
            cv::Rect faceRect = CVRectFromCGRect(bounds);
            cv::Mat faceFrame = gray(faceRect);
            
            _hasLeftEye = [biggestFace leftEyeInImage: faceFrame];
            _hasRightEye = [biggestFace rightEyeInImage: faceFrame];
            
            if( _hasRightEye || _hasLeftEye ) {
                NSLog(@"R: %d | %d", _hasLeftEye, _hasRightEye);
                
                if( self.state == UIGestureRecognizerStatePossible ) {
                    self.state = UIGestureRecognizerStateRecognized;
                }
            }
            else {
                if( self.state == UIGestureRecognizerStatePossible ) {
                    self.state = UIGestureRecognizerStateFailed;
                }
            }
            }
            else {
                if( self.state == UIGestureRecognizerStatePossible ) {
                    self.state = UIGestureRecognizerStateFailed;
                }
            }
        }
        else {
            if( self.state == UIGestureRecognizerStatePossible ) {
                self.state = UIGestureRecognizerStateFailed;
            }
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
}

@end
