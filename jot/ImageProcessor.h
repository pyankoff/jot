//
//  ImageProcessor.h
//  NNTest
//
//  Created by Samuel Wejéus on 18/07/2013.
//  Copyright (c) 2013 Samuel Wejéus. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#import <Foundation/Foundation.h>

using namespace cv;

@interface ImageProcessor : NSObject

- (NSMutableArray *) findDigits:(UIImage*)image;
- (NSMutableArray *) cvMat2MutableArray:(Mat) mat;
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer orientation:(UIInterfaceOrientation)orientation;

@end
