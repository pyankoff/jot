//
//  Symbol.h
//  lua2
//
//  Created by Andrey Pyankov on 12/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/opencv.hpp>
#import "opencv2/highgui/ios.h"
#import "Parse/Parse.h"

@interface Symbol : NSObject

@property (nonatomic) NSUInteger x;
@property (nonatomic) NSUInteger y;
@property (nonatomic) cv::Mat image;
@property (nonatomic) NSString *symbol;
@property (nonatomic) NSString *type;

@property (strong, nonatomic) PFObject *parseObject;

@end
