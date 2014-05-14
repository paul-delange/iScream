//
//  FaceObject.m
//  iSpy
//
//  Created by Paul de Lange on 11/04/2014.
//  Copyright (c) 2014 Chesterford. All rights reserved.
//

#import "FaceObject.h"

// For an explanation of which cascade to use:
//      http://opencv-users.1802565.n2.nabble.com/with-OpenCV-haarcascades-can-i-detect-only-open-eye-or-closed-eye-td7534953.html

static cv::CascadeClassifier*   _leftEyeClassifier = new cv::CascadeClassifier([[[NSBundle mainBundle] pathForResource: @"haarcascade_lefteye_2splits" ofType: @"xml"] UTF8String]);
static cv::CascadeClassifier*   _rightEyeClassifier = new cv::CascadeClassifier([[[NSBundle mainBundle] pathForResource: @"haarcascade_righteye_2splits" ofType: @"xml"] UTF8String]);
static cv::CascadeClassifier*   _openEyeClassifier = new cv::CascadeClassifier([[[NSBundle mainBundle] pathForResource: @"haarcascade_eye_tree_eyeglasses" ofType: @"xml"] UTF8String]);

static cv::Rect const CVRectZero = cv::Rect(0,0,0,0);

@interface FaceObject ()

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

- (BOOL) leftEyeInImage: (const cv::Mat&) image {
    int width = floorf(image.cols/4.);
    int height = floorf(image.rows/2.);
    int y = 0;//floorf(image.rows/5.);
    
    cv::Rect leftEyeRect(width, y, width*2, height);
    
    cv::Mat leftEyeFrame = image(leftEyeRect);
    
    cv::equalizeHist(leftEyeFrame, leftEyeFrame);
    
    cv::Rect detectedFrame = [self detectEye: leftEyeFrame withClassifier: _openEyeClassifier];
    
    return detectedFrame != CVRectZero;
}

- (BOOL) rightEyeInImage: (const cv::Mat&) image {
    int width = floorf(image.cols/4.);
    int height = floorf(image.rows/2.);
    int y = 0;//floorf(image.rows/5.);
    
    cv::Rect rightEyeRect(0, y, width*2, height);
    
    cv::Mat rightEyeFrame = image(rightEyeRect);
    
    //Equalize the image -> what does it do...?
    cv::equalizeHist(rightEyeFrame, rightEyeFrame);
    
    cv::Rect detectedFrame = [self detectEye: rightEyeFrame withClassifier: _openEyeClassifier];
    
    return detectedFrame != CVRectZero;
}

@end
