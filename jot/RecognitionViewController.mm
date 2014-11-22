//
//  ViewController.m
//  lua2
//
//  Created by Andrey Pyankov on 11/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

#import "RecognitionViewController.h"
#import "Torch.h"
#import "ImageProcessor.h"
#import "opencv2/highgui/ios.h"
#import "Symbol.h"
#import <mach/mach_time.h>
#import "SymbolView.h"

@interface RecognitionViewController ()  <UIGestureRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) ImageProcessor *imageProcessor;
@property (strong, nonatomic) Torch *torch;
@property (nonatomic) BOOL recognitionOn;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapRecognizer;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (nonatomic) int fontSize;


// Editing
@property (strong, nonatomic) SymbolView *activeSymbol;
@property (nonatomic) int initialDigit;

// Camera
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) dispatch_queue_t queue;

@end

@implementation RecognitionViewController

#define FOCUS_RECT_X 40
#define FOCUS_RECT_Y 70
#define FOCUS_RECT_Y_BOTTOM 80
- (int)padding { return (960 - 540 * self.view.bounds.size.height / self.view.bounds.size.width) / 2; }

- (void)viewDidLoad {
    
    [super viewDidLoad];

    self.queue = dispatch_queue_create("recognitionQueue", NULL);
    [self.torch initialize];

    //[self setNeedsStatusBarAppearanceUpdate];
    self.tapRecognizer.delegate = self;
    self.recognitionOn = NO;
    
    
    
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        [self setupCaptureSession];
        [self toggleRecognition];
    } else {
        NSLog(@"no camera");
    }
}

- (IBAction)toggleRecognition {
    if (self.recognitionOn) {
        NSLog(@"recognition stopped");
        self.recognitionOn = NO;
        
        //[self.captureSession stopRunning];
        
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.imageView setImage:self.image];
    } else {
        NSLog(@"recognition started");
        self.recognitionOn = YES;
        [self startRecognition];
        
        //[self.captureSession startRunning]; // blinks, how to fix?
        
        [self.imageView setImage:nil];
        [self.imageView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    [self animateStatus];
}

- (void)animateStatus {
    if (!self.recognitionOn) {
        self.statusLabel.text = @"Tap for new calculation";
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.statusLabel.alpha = 1.0f;
                         }
                         completion:^(BOOL finished){
                             // Do nothing
                         }];
    } else {
        self.statusLabel.text = @"Processing...";
        self.statusLabel.alpha = 1.0f;
        [UIView animateWithDuration:1.0
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut |
         UIViewAnimationOptionRepeat |
         UIViewAnimationOptionAutoreverse |
         UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.statusLabel.alpha = 0.0f;
                         }
                         completion:^(BOOL finished){
                             // Do nothing
                         }];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (touch.view == self.infoButton) {
        return NO;
    }
    return YES;
}

- (IBAction)infoButtonPressed:(UIButton *)sender {
    UIAlertView *help = [[UIAlertView alloc] initWithTitle:@"Welcome to JotCalculator!"
                                                   message:@"Write numbers on separate lines and signs on the left."
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
    [help show];
}

- (void)startRecognition
{
    dispatch_async(self.queue, ^{
        while (self.recognitionOn) {
            [self recognize];
        }
    });
}

- (void)recognize {
    uint64_t startTime = 0;
    uint64_t endTime = 0;
    double elapsedTime = 0;
    mach_timebase_info_data_t timeBaseInfo;
    mach_timebase_info(&timeBaseInfo);
    startTime = mach_absolute_time();
    
    //[self.imageView1 setImage:self.image];
    
    NSMutableArray *digits;
    NSMutableArray *signs = [[NSMutableArray alloc] init];
    
    UIImage *croppedImage = [self cropImage:self.image];
    if (!CGSizeEqualToSize(croppedImage.size, CGSizeZero)) {
        digits = [self findDigits: croppedImage];
        
        int minX = (int)[[digits valueForKeyPath:@"@min.x"] integerValue];
        
        int averageWidth = 0;
        int averageHeight = 0;
        for (int i = 0; i< [digits count]; i++ ) {
            Symbol *digit = digits[i];
            averageWidth += digit.image.cols;
            averageHeight += digit.image.rows;
        }
        averageWidth = averageWidth / [digits count];
        averageHeight = averageHeight / [digits count];
        self.fontSize = averageHeight * 9 / 10;
        //NSLog(@"minX: %d, averageWidth: %d", minX, averageWidth);
        
        for (int i = 0; i< [digits count]; i++ ) {
            Symbol *symbol = digits[i];
            
            if (symbol.x < minX+averageWidth) {
                symbol.symbol = [self recognizeSymbol:symbol type:@"sign"];
                [signs addObject:symbol];
            } else {
                symbol.symbol = [self recognizeSymbol:symbol type:@"digit"];
            }
        }
        
        NSArray *digitsToShow = [[NSArray alloc] initWithArray:digits];
        [digits removeObjectsInArray:signs];
        
        [signs sortUsingComparator:^NSComparisonResult(Symbol *s1, Symbol *s2) {
            NSNumber *x1 = [NSNumber numberWithInt:(int)s1.y];
            NSNumber *x2 = [NSNumber numberWithInt:(int)s2.y];
            return [x1 compare:x2];
        }];
        
        endTime = mach_absolute_time();
        elapsedTime = (endTime - startTime) * timeBaseInfo.numer / timeBaseInfo.denom / 1e9;
        NSLog(@"elapsed time: %f", elapsedTime);
        
        NSMutableArray *numbers = [[NSMutableArray alloc] init];
        NSMutableArray *rows = [[NSMutableArray alloc] init];
        
        while ([digits count] > 0) {
            NSArray *row = [self getRow:digits];
            NSMutableString *rowString = [[NSMutableString alloc] initWithString:@""];
            
            //NSLog(@"%@", @([row count]));
            for (Symbol *symbol in row) {
                [rowString appendString:symbol.symbol];
            }
            
            //float plug
            [rowString appendString:@".0"];
            
            //NSLog(@"%@", rowString);
            [numbers addObject:rowString];
            Symbol *digit = row[0];
            [rows addObject:@(digit.y)];
        }
        
        NSString *answer = @"";
        if ([numbers count] == [signs count] + 1 and self.recognitionOn) {
            for (int i = 0; i < [signs count]; i++) {
                Symbol *sign = signs[i];
                sign.y = ([rows[i] integerValue] + [rows[i+1] integerValue]) / 2;
            }
            answer = [self getAnswer:numbers signs:signs];
            [self drawExpression:digitsToShow answer:answer];
        }
    }
}

- (UIImage *)cropImage:(UIImage *)image {
    //NSLog(@"image to crop width: %f, height: %f", image.size.width, image.size.height);
    int viewWidth = self.view.bounds.size.width;
    int imgWidth = image.size.width;
    int imgHeight = image.size.height;

    float scale = (float)imgWidth / viewWidth;
    
    float x = FOCUS_RECT_X * scale;
    float y = [self padding] + FOCUS_RECT_Y * scale;
    int width = imgWidth - 2 * x;
    int height = imgHeight - (FOCUS_RECT_Y+FOCUS_RECT_Y_BOTTOM) * scale - 2 * [self padding];
    
    //NSLog(@"padding: %d, scale: %f, x: %f, y: %f, width: %d, height: %d", [self padding], scale, x, y, width, height);
    
    CGRect cropRect = CGRectMake(x, y, width, height);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self.image CGImage], cropRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return croppedImage;
}

- (NSString *)getAnswer:(NSArray *)numbers signs:(NSArray *)signs {
    NSMutableString *expression = [[NSMutableString alloc] initWithString:@""];
    
    [expression appendString:numbers[0]];
    for (int i = 0; i < [signs count]; i++) {
        Symbol *sign = signs[i];
        [expression appendString:sign.symbol];
        [expression appendString:numbers[i+1]];
    }
    NSLog(@"%@/n", expression);
    
    NSExpression *expressionToProcess = [NSExpression expressionWithFormat:expression];
    NSNumber *answer = [expressionToProcess expressionValueWithObject:nil context:nil];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    return [NSString stringWithFormat:@"%@", [formatter stringFromNumber:answer]];
}

- (void)drawExpression:(NSArray *)digits answer:(NSString *)answer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
        for (int i = 0; i< [digits count]; i++ ) {
            Symbol *symbol = digits[i];
            [self drawDigit:symbol];
        }
        UILabel *answerLabel = [[UILabel alloc] initWithFrame:CGRectMake(FOCUS_RECT_X, self.view.bounds.size.height-FOCUS_RECT_Y_BOTTOM+10, self.view.bounds.size.width-2*FOCUS_RECT_X, FOCUS_RECT_Y_BOTTOM-20)];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        NSAttributedString *labelValue = [[NSAttributedString alloc] initWithString:answer
                                                                          attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.7],
                                                                                       NSStrokeWidthAttributeName: @(0.0),
                                                                                       NSStrokeColorAttributeName:[UIColor redColor],
                                                                                       NSFontAttributeName: [UIFont boldSystemFontOfSize:MIN(50, 400/[answer length])],
                                                                                       NSParagraphStyleAttributeName:paragraphStyle }];
        
        answerLabel.attributedText = labelValue;
        answerLabel.layer.cornerRadius = 6;
        answerLabel.layer.backgroundColor = [UIColor colorWithRed:247.0/255 green:82.0/255 blue:28.0/255 alpha:1].CGColor;
        //answerLabel.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.6];
        [self.imageView addSubview:answerLabel];
    });
    
}

- (NSArray *)getRow:(NSMutableArray *)digits {
    NSMutableArray *row = [[NSMutableArray alloc] init];
    
    int minY = (int)[[digits valueForKeyPath:@"@min.y"] integerValue];
    
    int averageHeight = 0;
    for (int i = 0; i< [digits count]; i++ ) {
        Symbol *digit = digits[i];
        averageHeight += digit.image.rows;
    }
    averageHeight = averageHeight / [digits count];
    
    for (Symbol *symbol in digits) {
        if (symbol.y < minY + averageHeight) {
            symbol.y = minY;
            [row addObject:symbol];
        }
    }
    [digits removeObjectsInArray:row];
    //NSLog(@"minY: %d, averageHeight: %d", minY, averageHeight);
    [row sortUsingComparator:^NSComparisonResult(Symbol *s1, Symbol *s2) {
        NSNumber *x1 = [NSNumber numberWithInt:(int)s1.x];
        NSNumber *x2 = [NSNumber numberWithInt:(int)s2.x];
        return [x1 compare:x2];
    }];
    
    Symbol *firstSymbol = [row firstObject];
    Symbol *lastSymbol = [row lastObject];
    
    for (int i = 0; i < [row count]; i++) {
        Symbol *symbol = row[i];
        symbol.x = firstSymbol.x + i * (lastSymbol.x - firstSymbol.x) / ([row count] - 1);
    }
    
    return row;
}

- (void)drawDigit:(Symbol *)digit {
    
    int x = FOCUS_RECT_X + digit.x * self.imageView.bounds.size.width  / 540;
    int y = FOCUS_RECT_Y + digit.y * self.imageView.bounds.size.height  / (960 - 2 * [self padding]);
    //NSLog(@"x: %d, y: %d, symbol: %@", x, y, digit.symbol);
    SymbolView *digitLabel = [[SymbolView alloc] initWithFrame:CGRectMake(x, y, self.fontSize, self.fontSize)];
    
    NSAttributedString *labelSymbol = [[NSAttributedString alloc] initWithString:digit.symbol
                        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4],
                                        NSStrokeWidthAttributeName: @(-1.5),
                                     NSStrokeColorAttributeName:[UIColor colorWithRed:247.0/255 green:82.0/255 blue:28.0/255 alpha:1],
                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:self.fontSize] }];
    
    digitLabel.attributedText = labelSymbol;
    digitLabel.userInteractionEnabled = YES;
    [self.imageView addSubview:digitLabel];
    //[self.imageView setImage:self.image];
    
}

- (IBAction)adjust:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [sender locationInView:self.imageView];
        UIView *tappedView = [self.imageView hitTest:point withEvent:nil];
        
        if ([tappedView isKindOfClass:[SymbolView class]]) {
            self.activeSymbol = (SymbolView *)tappedView;
            self.initialDigit = [[self.activeSymbol.attributedText string] integerValue];
            [self adjustDigit:[sender translationInView:self.imageView].y];
        }
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        [self adjustDigit:[sender translationInView:self.imageView].y];
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        self.activeSymbol = nil;
        self.initialDigit = NULL;
    }
}

- (void)adjustDigit:(float)translation {
    //NSLog(@"%f", translation);
    int digit = min(max(self.initialDigit - int(translation/30),0), 9);
    
    self.activeSymbol.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d", digit]
                                                            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4],
                                                                         NSStrokeWidthAttributeName: @(-1.5),
                                                                         NSStrokeColorAttributeName:[UIColor colorWithRed:247.0/255 green:82.0/255 blue:28.0/255 alpha:1],
                                                                         NSFontAttributeName: [UIFont boldSystemFontOfSize:self.fontSize] }];
}







// Create and configure a capture session and start it running
- (void)setupCaptureSession
{
    NSError *error = nil;
    
    // Create the session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    session.sessionPreset = AVCaptureSessionPresetiFrame960x540;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    // Specify the pixel format
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // Start the session running to start the flow of data
    [self startCapturingWithSession:session];
    
    // Assign session to an ivar.
    self.captureSession = session;
}

- (void)startCapturingWithSession: (AVCaptureSession *) captureSession
{
    //NSLog(@"Adding video preview layer");
    [self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession]];
    
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    
    //----- DISPLAY THE PREVIEW LAYER -----
    //Display it full screen under out view controller existing controls
    //NSLog(@"Display the preview layer ");
    CGRect layerRect = [[[self view] layer] bounds];
    [self.previewLayer setBounds:layerRect];
    [self.previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),
                                               CGRectGetMidY(layerRect))];
    //[[[self view] layer] addSublayer:[[self CaptureManager] self.previewLayer]];
    //We use this instead so it goes on a layer behind our UI controls (avoids us having to manually bring each control to the front):
    UIView *CameraView = [[UIView alloc] init];
    [self.view addSubview:CameraView];
    [self.view sendSubviewToBack:CameraView];
    
    [[CameraView layer] addSublayer:self.previewLayer];
    [[self.imageView layer] addSublayer:[self focusRect]];
    
    
    //----- START THE CAPTURE SESSION RUNNING -----
    [captureSession startRunning];
}


- (CAShapeLayer *)focusRect {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    UIBezierPath *holePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(FOCUS_RECT_X, FOCUS_RECT_Y, self.view.bounds.size.width-2*FOCUS_RECT_X, self.view.bounds.size.height-FOCUS_RECT_Y-FOCUS_RECT_Y_BOTTOM) cornerRadius:6];
    [path appendPath:holePath];
    [path setUsesEvenOddFillRule:YES];
    
    CAShapeLayer *focusRect = [CAShapeLayer layer];
    //focusRect.bounds = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    focusRect.path = path.CGPath;
    focusRect.fillRule = kCAFillRuleEvenOdd;
    focusRect.fillColor = [UIColor blackColor].CGColor;
    focusRect.opacity = 0.15;
    
    return focusRect;
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // Create a UIImage from the sample buffer data
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    self.image = [self imageFromSampleBuffer:sampleBuffer];
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
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
    
    return (image);
}






- (NSString *)recognizeSymbol:(Symbol *)symbol type:(NSString *)type{

    NSMutableArray *flatImage;
    flatImage = [self.imageProcessor cvMat2MutableArray:symbol.image];
    
    //int max = [[flatImage valueForKeyPath:@"@max.intValue"] intValue];
    //NSLog(@"max: %d, count: %d", max, [flatImage count]);
    //NSLog(@"%@", flatImage);
    
    int recognizedDigit = [self.torch performClassification:flatImage
                                                       rows:symbol.image.rows
                                                       cols:symbol.image.cols
                                                       type:type];
    NSString *result;
    if ([type isEqualToString:@"digit"]) {
        result = [NSString stringWithFormat:@"%d", recognizedDigit];
    } else if ([type isEqualToString:@"sign"]) {
        NSDictionary *signs = @{@1: @"/", @2: @"*", @3: @"+", @4: @"-"};
        result = [NSString stringWithFormat:@"%@", [signs objectForKey:@(recognizedDigit)]];
    }
    
    return result;
}



- (ImageProcessor *)imageProcessor {
    if (!_imageProcessor) {
        _imageProcessor = [[ImageProcessor alloc] init];
    }
    return _imageProcessor;
}

- (Torch *)torch {
    if (!_torch) {
        _torch = [[Torch alloc] init];
    }
    return _torch;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
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
        
        kernel = getStructuringElement(MORPH_ELLIPSE, cv::Size(13, 13));
        morphologyEx(thresh, thresh, MORPH_CLOSE, kernel);
        
        //[self.imageView1 setImage:MatToUIImage(thresh)];
        
        Mat pic;
        thresh.copyTo(pic);
        
        vector<vector<cv::Point> > contours;
        vector<Vec4i> hierarchy;
        findContours(thresh, contours, hierarchy, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
        
        //vector<vector<cv::Point>> contours_poly(contours.size());
        //cv::vector<cv::Rect> boundRect( contours.size() );
        //cv::vector<cv::Point2f>center( contours.size() );
        //cv::vector<float>radius( contours.size() );
        //cv::vector<cv::Mat> digits(contours.size());
        cv::vector<cv::Point> contours_poly;
        cv::Rect boundRect;
        cv::Point2f center;
        float radius;
        cv::Mat digit;
        
        
        NSLog(@"number of contours %d", int(contours.size()));
        
        //[self showImage:MatToUIImage(pic)];
        
        if (int(contours.size()) < 100) {
            
            for (int i = 0; i < contours.size(); i++ )
            {
                if (cv::arcLength(contours[i], YES) > 100) {
                    
                    NSLog(@"contour: %f", cv::arcLength(contours[i], YES));
            
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
    }
    
    return foundDigits;
}

- (void)showImage:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 250)];
    [imageView setImage:image];
    [self.view addSubview:imageView];
}

@end
