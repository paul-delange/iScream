//
//  FaceObject.m
//  iSpy
//
//  Created by Paul de Lange on 11/04/2014.
//  Copyright (c) 2014 Chesterford. All rights reserved.
//

#import "FaceObject.h"
#import "EyeObject.h"

static cv::CascadeClassifier*   _leftEyeClassifier = new cv::CascadeClassifier([[[NSBundle mainBundle] pathForResource: @"haarcascade_lefteye_2splits" ofType: @"xml"] UTF8String]);
static cv::CascadeClassifier*   _rightEyeClassifier = new cv::CascadeClassifier([[[NSBundle mainBundle] pathForResource: @"haarcascade_righteye_2splits" ofType: @"xml"] UTF8String]);

static cv::Rect CVRectZero = cv::Rect(0,0,0,0);

@interface FaceObject ()

@property (strong) EyeObject* leftEye;
@property (strong) EyeObject* rightEye;

@end

@implementation FaceObject

- (cv::Rect) detectEye: (const cv::Mat &) image withClassifier: (cv::CascadeClassifier*) classifier {
    int flags = CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_SCALE_IMAGE;
    float scaleFactor = 1.2;
    
    cv::Size minimumSize = cv::Size(image.cols * 0.25, image.rows * 0.25);
    
    std::vector<cv::Rect> eyes;
    classifier->detectMultiScale(image,
                                     eyes,
                                     scaleFactor,
                                     1,
                                     flags,
                                     minimumSize);
    for(size_t i = 0;i<eyes.size();i++) {
        return eyes[i];
    }
    
    return CVRectZero;
}

- (NSArray*) eyesInImage: (const cv::Mat&) image {
    
    int width = floorf(image.cols/2.);
    int height = floorf(image.rows/2.);
    int y = 0;//floorf(image.rows/5.);
    
    cv::Rect leftEyeRect(0, y, width, height);
    cv::Rect rightEyeRect(width, y, width, height);
    
    cv::Mat leftEyeFrame = image(leftEyeRect);
    cv::Mat rightEyeFrame = image(rightEyeRect);
    
    //Equalize the image -> what does it do...?
    cv::Mat bothEyesFrame = image(cv::Rect(0, y, width*2, height));
    cv::equalizeHist(bothEyesFrame, bothEyesFrame);
    
    int matchLimit = 1000000;
    
    if( self.leftEye ) {
        EyeObject* obj = self.leftEye;
        cv::Mat tpl = obj.capture;
        
        int result_rows = leftEyeFrame.rows - tpl.rows + 1;
        int result_cols = leftEyeFrame.cols - tpl.cols + 1;
       
        
        NSAssert(result_rows > 0 , @"leftEyeRect is narrower than the eye template");
        NSAssert(result_cols > 0,  @"leftEyeRect is shorter than the eye template");
        
        cv::Mat dst(result_cols, result_rows, CV_32FC1);
        cv::matchTemplate(leftEyeFrame, tpl, dst, CV_TM_SQDIFF);
        
        double minval, maxval;
        cv::Point minloc, maxloc;
        cv::minMaxLoc(dst, &minval, &maxval, &minloc, &maxloc);
        
        
        if (minval <= matchLimit)
        {
            cv::Rect detectedFrame = cv::Rect(minloc.x,
                                              minloc.y,
                                              tpl.rows,
                                              tpl.cols);
            obj.bounds = detectedFrame;
            obj.lostCount = 0;
            leftEyeRect = detectedFrame;
        }
        else {
            obj.lostCount++;
            
            if( obj.lostCount > 5 )
                self.leftEye = nil;
            else
                leftEyeRect = obj.bounds;
        }
    }
    
    if(! self.leftEye ) {
        cv::Rect detectedFrame = [self detectEye: leftEyeFrame withClassifier: _leftEyeClassifier];
        
        if( detectedFrame != CVRectZero ) {
            
            EyeObject* eyeObject = [EyeObject new];
            
            eyeObject.capture = leftEyeFrame(detectedFrame);
            
            self.leftEye = eyeObject;
            
            eyeObject.bounds = detectedFrame;
            leftEyeRect = detectedFrame;
        }
    }
    
    if( self.rightEye ) {
        EyeObject* obj = self.rightEye;
        cv::Mat tpl = obj.capture;
        
        int result_rows = rightEyeFrame.rows - tpl.rows + 1;
        int result_cols = rightEyeFrame.cols - tpl.cols + 1;
        
        NSAssert(result_rows > 0 , @"rightEyeRect is narrower than the eye template");
        NSAssert(result_cols > 0,  @"rightEyeRect is shorter than the eye template");
        
        cv::Mat dst(result_rows, result_cols, CV_32FC1);
        cv::matchTemplate(rightEyeFrame, tpl, dst, CV_TM_SQDIFF);
        
        double minval, maxval;
        cv::Point minloc, maxloc;
        cv::minMaxLoc(dst, &minval, &maxval, &minloc, &maxloc);
        
        if (minval <= matchLimit)
        {
            cv::Rect detectedFrame = cv::Rect(minloc.x,
                                              minloc.y,
                                              tpl.rows,
                                              tpl.cols);
            obj.bounds = detectedFrame;
            obj.lostCount = 0;
            rightEyeRect = detectedFrame;
        }
        else {
            
            obj.lostCount++;
            
            if( obj.lostCount > 5 )
                self.rightEye = nil;
            else {
                rightEyeRect = obj.bounds;
            }
        }
    }
    
    
    if( !self.rightEye ) {
        cv::Rect detectedFrame = [self detectEye: rightEyeFrame withClassifier: _rightEyeClassifier];
        
        if( detectedFrame != CVRectZero ) {
            
            rightEyeRect = detectedFrame;
            EyeObject* eyeObject = [EyeObject new];
            
            eyeObject.capture = rightEyeFrame(detectedFrame);
            
            self.rightEye = eyeObject;
            eyeObject.bounds = detectedFrame;
        }
    }
    
    NSMutableArray* results = [NSMutableArray new];
    if( self.leftEye ) {
        leftEyeRect.y += y;
        
        CGRect rect = CGRectMake(leftEyeRect.x, leftEyeRect.y, leftEyeRect.width, leftEyeRect.height);
        [results addObject: [NSValue valueWithCGRect: rect]];
    }
    
    if( self.rightEye ) {
        rightEyeRect.x += width;
        rightEyeRect.y += y;
        
        CGRect rect = CGRectMake(rightEyeRect.x, rightEyeRect.y, rightEyeRect.width, rightEyeRect.height);
        [results addObject: [NSValue valueWithCGRect: rect]];
    }
    
    return results;
}

@end
