/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Camera preview.
  
*/

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface AAPLPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;
- (UIImage *)imageFromLayer;

@end
