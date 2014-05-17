//
//  GameViewController.m
//  iScream
//
//  Created by Paul de Lange on 14/05/2014.
//  Copyright (c) 2014 Gilmert Bentley. All rights reserved.
//

#import "GameViewController.h"

#import "UIFacialGestureRecognizer.h"

@interface GameViewController () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIView *leftView;
@property (weak, nonatomic) IBOutlet UIView *rightView;

@end

@implementation GameViewController

#pragma mark - Actions
- (IBAction) faceRecognized: (UIFacialGestureRecognizer*) sender {
    switch (sender.state) {
        case UIGestureRecognizerStateRecognized:
        {
            NSLog(@"VC: %d | %d", sender.hasLeftEye, sender.hasRightEye);
            self.leftView.backgroundColor = sender.hasLeftEye ? [UIColor blackColor] : [UIColor whiteColor];
            self.rightView.backgroundColor = [sender hasRightEye] ? [UIColor blackColor] : [UIColor whiteColor];
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIFacialGestureRecognizer* facialRecognizer = [[UIFacialGestureRecognizer alloc] initWithTarget: self
                                                                                             action: @selector(faceRecognized:)];
    facialRecognizer.delegate = self;
    [self.view addGestureRecognizer: facialRecognizer];
}

@end
