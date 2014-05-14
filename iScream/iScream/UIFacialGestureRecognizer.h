//
//  UIFacialGestureRecognizer.h
//  iScream
//
//  Created by Paul de Lange on 14/05/2014.
//  Copyright (c) 2014 Gilmert Bentley. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIFacialGestureRecognizer : UIGestureRecognizer

@property (assign, readonly) BOOL hasRightEye;
@property (assign, readonly) BOOL hasLeftEye;

@end
