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
    
    kernel = getStructuringElement(MORPH_ELLIPSE, cv::Size(13, 13));
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

/*- (void)showImage:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 250)];
    [imageView setImage:image];
    [self.view addSubview:imageView];
}*/

@end
