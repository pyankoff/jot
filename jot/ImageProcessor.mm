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

- (NSMutableArray *) findDigits:(UIImage*)image
{
    // Convert UIImage* to cv::Mat
    Mat cvImage;
    Mat scaledImage(cv::Size(600, 800), CV_8UC3);
    UIImageToMat(image, cvImage);
    
    int rows = cvImage.rows;
    int cols = cvImage.cols;
    //NSLog(@"Original rows: %d, cols: %d", rows, cols);
    
    resize(cvImage, scaledImage, scaledImage.size());
    rows = scaledImage.rows;
    cols = scaledImage.cols;
    //NSLog(@"Scaled rows: %d, cols: %d", rows, cols);
    //cv::transpose(scaledImage, scaledImage);
    //cv::flip(scaledImage, scaledImage, 270);
    
    NSMutableArray *foundDigits = [[NSMutableArray alloc] init];
    
    if (!scaledImage.empty())
    {
        Mat gray;
        Mat blur;
        Mat blur2;
        
        double minVal;
        double maxVal;
        cv::Point minLoc;
        cv::Point maxLoc;
        
        cvtColor(cvImage, gray, CV_RGBA2GRAY);
        
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
        
        kernel = getStructuringElement(MORPH_ELLIPSE, cv::Size(5, 5));
        morphologyEx(thresh, thresh, MORPH_CLOSE, kernel);
        
        //[self.imageView1 setImage:MatToUIImage(thresh)];
        
        Mat pic;
        thresh.copyTo(pic);
        
        vector<vector<cv::Point> > contours;
        vector<Vec4i> hierarchy;
        findContours(thresh, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
        
        vector<vector<cv::Point>> contours_poly(contours.size());
        cv::vector<cv::Rect> boundRect( contours.size() );
        cv::vector<cv::Point2f>center( contours.size() );
        cv::vector<float>radius( contours.size() );
        cv::vector<cv::Mat> digits(contours.size());
        
        //NSLog(@"number of contours %d", int(contours.size()));
        
        if (int(contours.size()) < 100) {
            
            for (int i = 0; i < contours.size(); i++ )
            {
                cv::approxPolyDP(cv::Mat(contours[i]), contours_poly[i], 3, true);
                boundRect[i] = cv::boundingRect( cv::Mat(contours_poly[i]) );
                cv::minEnclosingCircle( (cv::Mat)contours_poly[i], center[i], radius[i] );
            }
            
            for( int i = 0; i< contours.size(); i++ )
            {
                cv::drawContours(thresh, contours_poly, i, cv::Scalar(255), 3, 8, cv::vector<cv::Vec4i>(), 0, cv::Point() );
                //cv::rectangle(edges, boundRect[i].tl(), boundRect[i].br(), 255, 2, 8, 0 );
                //cv::circle( edges, center[i], (int)radius[i], 255, 2, 8, 0 );
            }
            
            for( int i = 0; i< contours.size(); i++ )
            {
                cv::Mat digitRect;
                
                int x = max(boundRect[i].x-5, 0);
                int y = max(boundRect[i].y-5, 0);
                int width = min(x + boundRect[i].width+10, pic.size[1]) - x;
                int height = min(y + boundRect[i].height+10, pic.size[0]) - y;
                
                digitRect.create(width, height, CV_32F);
                digitRect = pic(cv::Rect(x, y, width, height));
                
                digitRect.copyTo(digits[i]);
                
            }
            
            for (int i = 0; i< contours.size(); i++) {
                Symbol *digit = [[Symbol alloc] init];
                digit.x = boundRect[i].x;
                digit.y = boundRect[i].y;
                digit.image = *(&digits[i]);
                [foundDigits addObject:digit];
            }
        } else {
            NSLog(@"too many contours");
        }
    }
    
    return foundDigits;
}

@end
