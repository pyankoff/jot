//
//  ImageProcessor.m
//  NNTest
//
//  Created by Samuel Wejéus on 18/07/2013.
//  Copyright (c) 2013 Samuel Wejéus. All rights reserved.
//

#import "ImageProcessor.h"
#import "Symbol.h"

@implementation ImageProcessor


- (NSMutableArray *) cvMat2MutableArray:(cv::Mat) mat
{
    NSMutableArray *sample = [[NSMutableArray alloc] initWithCapacity:mat.rows*mat.cols];
    
    int flatIndex = 0;
    for (int row = 0; row < mat.rows; ++row) {
        
        unsigned char* inp  = mat.ptr<unsigned char>(row); // check this if correct type!
        
        for (int col = 0; col < mat.cols; ++col) {
            [sample setObject:@(*inp) atIndexedSubscript:flatIndex]; // training was preformed on inverted grayscale images -> convert to match
            inp++;
            flatIndex++;
        }
    }
    
    return sample;
}

- (NSArray *) findDigits:(UIImage*)image
{
    // Convert UIImage* to cv::Mat
    Mat cvImage;
    Mat scaledImage(cv::Size(600, 800), CV_8UC3);
    UIImageToMat(image, cvImage);
    
    
    NSArray *foundDigits = [[NSArray alloc] init];
    
    if (!cvImage.empty())
    {
        Mat thresh;
        thresh = [self removeBackground:cvImage];
        foundDigits = [self cutSymbols:thresh];

    }
    return foundDigits;
}

- (Mat)removeBackground:(Mat)image {
    Mat gray;
    Mat blur;
    Mat blur2;
    
    double minVal;
    double maxVal;
    cv::Point minLoc;
    cv::Point maxLoc;
    
    cvtColor(image, gray, CV_RGBA2GRAY);
    
    medianBlur(gray, blur, 5);
    
    float k = 0.5;
    blur = (gray + k * blur) * (1 - k);
    
    medianBlur(gray, blur2, 41);
    
    blur = 120 * blur / blur2;
    
    minMaxLoc(blur, &minVal, &maxVal, &minLoc, &maxLoc);
    
    blur = 255 * blur / maxVal;
    blur.convertTo(blur, CV_8UC1);
    
    Mat thresh;
    threshold(blur, thresh, 0, 255, THRESH_BINARY_INV+THRESH_OTSU);
    
    Mat kernel = getStructuringElement(MORPH_RECT, cv::Size(2, 2));
    morphologyEx(thresh, thresh, MORPH_OPEN, kernel);
    
    kernel = getStructuringElement(MORPH_ELLIPSE, cv::Size(9, 9));
    morphologyEx(thresh, thresh, MORPH_CLOSE, kernel);
    
    //[self.imageView1 setImage:MatToUIImage(thresh)];
    return thresh;
}

- (NSArray *)cutSymbols:(Mat)image {
    Mat pic;
    image.copyTo(pic);
    NSMutableArray *foundDigits = [[NSMutableArray alloc] init];
    
    vector<vector<cv::Point> > contours;
    vector<Vec4i> hierarchy;
    findContours(image, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
    
    cv::vector<cv::Point> contours_poly;
    cv::Rect boundRect;
    cv::Point2f center;
    float radius;
    cv::Mat digit;
    
    
    //NSLog(@"number of contours %d", int(contours.size()));
    
    //[self showImage:MatToUIImage(pic)];
    
    if (int(contours.size()) < 100) {
        
        for (int i = 0; i < contours.size(); i++ )
        {
            if (cv::arcLength(contours[i], YES) > 100) {
                
                //NSLog(@"contour: %f", cv::arcLength(contours[i], YES));
                
                cv::approxPolyDP(cv::Mat(contours[i]), contours_poly, 3, true);
                boundRect = cv::boundingRect( cv::Mat(contours_poly) );
                cv::minEnclosingCircle((cv::Mat)contours_poly, center, radius);
                
                //cv::drawContours(thresh, contours_poly, i, cv::Scalar(255), 3, 8, cv::vector<cv::Vec4i>(), 0, cv::Point() );
                //cv::rectangle(edges, boundRect[i].tl(), boundRect[i].br(), 255, 2, 8, 0 );
                //cv::circle( edges, center[i], (int)radius[i], 255, 2, 8, 0 );
                
                cv::Mat digitRect;
                
                int x = max(boundRect.x-5, 0);
                int y = max(boundRect.y-5, 0);
                int width = min(x + boundRect.width+10, pic.size[1]) - x;
                int height = min(y + boundRect.height+10, pic.size[0]) - y;
                
                digitRect.create(width, height, CV_32F);
                digitRect = pic(cv::Rect(x, y, width, height));
                
                digitRect.copyTo(digit);
                
                Symbol *symbol = [[Symbol alloc] init];
                symbol.x = boundRect.x;
                symbol.y = boundRect.y;
                symbol.image = *(&digit);
                [foundDigits addObject:symbol];
            }
        }
    } else {
        NSLog(@"too many contours");
    }
    return foundDigits;
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer orientation:(UIInterfaceOrientation)orientation
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    UIImage *resultImage = [[UIImage alloc] initWithCGImage: image.CGImage
                                                      scale: 1.0
                                                orientation: [self getOrientation:orientation]];
    
    return resultImage;
}

- (UIImageOrientation)getOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return UIImageOrientationDown;
    } else if (orientation == UIInterfaceOrientationPortrait) {
        return UIImageOrientationRight;
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return UIImageOrientationUp;
    } else {
        return UIImageOrientationLeft;
    }
}




/*- (void)showImage:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 250)];
    [imageView setImage:image];
    [self.view addSubview:imageView];
}*/

@end
