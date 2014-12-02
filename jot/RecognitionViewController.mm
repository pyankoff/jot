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
#import "Parse/Parse.h"
#import "AAPLPreviewView.h"
#import "JotCalculator-Swift.h"

@interface RecognitionViewController ()  <UIApplicationDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) ImageProcessor *imageProcessor;
@property (strong, nonatomic) Torch *torch;
@property (nonatomic) BOOL recognitionOn;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapRecognizer;
@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) UILabel *answerLabel;
@property (nonatomic) int fontSize;

// Flash
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (nonatomic) BOOL flashOn;

// Data
@property (strong, nonatomic) NSArray *symbols;
@property (strong, nonatomic) NSArray *signsIndexes;
@property (strong, nonatomic) NSArray *numbersIndexes;
@property (strong, nonatomic) NSString *answer;

// Parse
@property (strong, nonatomic) PFObject *photo;

// Editing
//@property (strong, nonatomic) SymbolView *activeSymbol;
@property (nonatomic) int initialSymbolNumber;

// Camera
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (strong, nonatomic) AVCaptureSession *session;
@property (weak, nonatomic) IBOutlet AAPLPreviewView *previewView;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDevice *videoDevice;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) CAShapeLayer *focusRect;

// Simulator
@property (nonatomic) BOOL onSimulator;

@end

@implementation RecognitionViewController



#pragma mark - initializations

#define FOCUS_RECT_X 40
#define FOCUS_RECT_Y 70
#define FOCUS_RECT_Y_BOTTOM 80

- (int)padding { return (self.image.size.height - self.image.size.width * self.view.bounds.size.height / self.view.bounds.size.width) / 2; }

- (int)focusRectY {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight)  {
        return FOCUS_RECT_Y/2;
    } else {
        return FOCUS_RECT_Y;
    }
}

- (int)focusRectYBottom {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft || deviceOrientation == UIDeviceOrientationLandscapeRight)  {
        return FOCUS_RECT_Y_BOTTOM*0.7;
    } else {
        return FOCUS_RECT_Y_BOTTOM;
    }
}

/*
- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
    }
    return _imageView;
}
*/
- (NSString *)signFromNumber:(int)number {
    NSDictionary *signs = @{@1: @"/", @2: @"*", @3: @"+", @4: @"-"};
    return [signs objectForKey:@(number)];
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

- (NSArray *)signsIndexes {
    if (!_signsIndexes) {
        _signsIndexes = [[NSArray alloc] init];
    }
    return _signsIndexes;
}

- (NSArray *)numbersIndexes {
    if (!_numbersIndexes) {
        _numbersIndexes = [[NSArray alloc] init];
    }
    return _numbersIndexes;
}

- (NSString *)answer {
    if (!_answer) {
        _answer = @"";
    }
    return _answer;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (UILabel *)statusLabel {
    if (!_statusLabel) {
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(FOCUS_RECT_X, [self focusRectY]-40, self.view.bounds.size.width-2*FOCUS_RECT_X, [self focusRectY]-20)];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        [self.imageView addSubview:_statusLabel];
    }
    [_statusLabel setNeedsDisplay];
    return _statusLabel;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    if ([[AVCaptureDevice devices] count] > 0) {
        self.onSimulator = NO;
        
        [self createSession];
        
    } else {
        NSLog(@"no camera");
        self.onSimulator = YES;
    }
    
    self.queue = dispatch_queue_create("recognitionQueue", NULL);
    [self.torch initialize];
    
    self.focusRect = [self drawFocusRect];
    [[self.imageView layer] addSublayer:self.focusRect];
    
    self.recognitionOn = NO;
    self.flashOn = NO;
    [self toggleRecognition];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:@"symbolChange"
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification)
    {
        if (self.recognitionOn) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self stopRecognition];
            });
        }
    }];
    [center addObserverForName:@"symbolValue"
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *notification)
     {
         NSLog(@"%@", notification.object);
         [self symbolChange:notification];
     }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.onSimulator) {
        dispatch_async([self sessionQueue], ^{
            [[self session] startRunning];
        });
    }
}

- (void)createSession {
    
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    
    // Set up preview
    [[self previewView] setSession:session];
    
    // Check for device authorization
    [self checkDeviceAuthorizationStatus];
    
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
    
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
        
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [RecognitionViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error)
        {
            NSLog(@"%@", error);
        }
        
        [[self session] beginConfiguration];
        
        if ([session canAddInput:videoDeviceInput])
        {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            [self setVideoDevice:videoDeviceInput.device];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Why are we dispatching this to the main queue?
                // Because AVCaptureVideoPreviewLayer is the backing layer for our preview view and UIView can only be manipulated on main thread.
                // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
                [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[[UIApplication sharedApplication] statusBarOrientation]];
                ((AVCaptureVideoPreviewLayer *)[[self previewView] layer]).videoGravity = AVLayerVideoGravityResizeAspectFill;
            });
        }
        
        session.sessionPreset = AVCaptureSessionPresetiFrame960x540;
        
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
        
        
        [[self session] commitConfiguration];
    });
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
    
    [self.focusRect removeFromSuperlayer];
    self.focusRect = [self drawFocusRect];
    [[self.imageView layer] addSublayer:self.focusRect];
    
    if (self.recognitionOn) {
        [self.imageView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    } else {
        [self drawExpression];
        [self drawAnswer];
    }
}


#pragma mark Utilities

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}


- (void)checkDeviceAuthorizationStatus
{
    NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (granted)
        {
            [self setDeviceAuthorized:YES];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"JotCalculator"
                                            message:@"JotCalculator doesn't have permission to use the Camera"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                [self setDeviceAuthorized:NO];
            });
        }
    }];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self sendSymbolsToParse];
}

#pragma mark - camera delegate

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // Create a UIImage from the sample buffer data
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    self.image = [self.imageProcessor imageFromSampleBuffer:sampleBuffer orientation:orientation];
}

- (IBAction)toggleLight {
    // check if flashlight available
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            if (!self.flashOn) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                self.flashOn = YES; //define as a variable/property if you need to know status
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
                self.flashOn = NO;
            }
            [device unlockForConfiguration];
        }
    }
}




#pragma mark - support UI

- (CAShapeLayer *)drawFocusRect {
    CAShapeLayer *focusRect = [CAShapeLayer layer];
    
    CGFloat width, height;
    if (!self.focusRect) {
        width = self.view.bounds.size.width;
        height = self.view.bounds.size.height;
    } else {
        width = self.view.bounds.size.height;
        height = self.view.bounds.size.width;
    }
    
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, width, height)];
    UIBezierPath *holePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(FOCUS_RECT_X, [self focusRectY], width-2*FOCUS_RECT_X, height-[self focusRectY]-[self focusRectYBottom]) cornerRadius:6];
    [path appendPath:holePath];
    [path setUsesEvenOddFillRule:YES];
    NSLog(@"focus rect y: %d", [self focusRectY]);
    
    //focusRect.bounds = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    focusRect.path = path.CGPath;
    focusRect.fillRule = kCAFillRuleEvenOdd;
    focusRect.fillColor = [UIColor blackColor].CGColor;
    focusRect.opacity = 0.15;
    
    return focusRect;
}

#pragma mark - Parse

- (void)saveToParse {
    // track calculation stops
    [PFAnalytics trackEvent:@"Calculation" dimensions:@{}];
    
    // save photo
    NSData *imageData = UIImageJPEGRepresentation(self.image, 0.05f);
    PFFile *imageFile = [PFFile fileWithName:@"Image.jpg" data:imageData];
    [imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!error) {
            PFObject *photo = [PFObject objectWithClassName:@"Photo"];
            [photo setObject:imageFile forKey:@"imageFile"];
            [photo setObject:[PFUser currentUser] forKey:@"user"];
            [photo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (!error) {
                    for (Symbol *symbol in self.symbols) {
                        symbol.parseObject[@"PhotoId"] = photo;
                    }
                }
            }];
        }
    }];
    [self saveSymbolsFromPhoto:self.photo];
}

- (void)saveSymbolsFromPhoto:(PFObject *)photo {
    for (Symbol *symbol in self.symbols) {
        symbol.parseObject = [PFObject objectWithClassName:@"Symbol"];
        symbol.parseObject[@"recognized"] = [NSString stringWithFormat:@"%@", symbol.symbol];
        symbol.parseObject[@"adjusted"] = @"";
        
        NSData *imageData = UIImageJPEGRepresentation(MatToUIImage(symbol.image), 0.05f);
        PFFile *imageFile = [PFFile fileWithName:@"Image.jpg" data:imageData];
        [imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (!error) {
                symbol.parseObject[@"imgFile"] = imageFile;
            } else {
                NSLog(@"%@", error);
            }
        }];
    }
}

- (void)updateAdjustedSymbol:(int)i {
    Symbol *symbol = self.symbols[i];
    [symbol.parseObject setObject:[NSString stringWithFormat:@"%@", symbol.symbol] forKey:@"adjusted"];
    NSLog(@"%@", symbol.parseObject[@"adjusted"]);
}

- (void)sendSymbolsToParse {
    for (Symbol *symbol in self.symbols) {
        [symbol.parseObject saveEventually];
    }
}

#pragma mark - recognition

- (void)toggleRecognition {
    if (self.recognitionOn) {
        [self stopRecognition];
    } else {
        [self beginRecognition];
    }
}

- (void)stopRecognition {
    NSLog(@"recognition stopped");
    self.recognitionOn = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.imageView setImage:self.image];
    });
    
    [self.session stopRunning];
    
    [self saveToParse];
}

- (IBAction)beginRecognition {
    dispatch_async(self.queue, ^{
        [self sendSymbolsToParse];
        self.symbols = nil;
    });
    if (self.onSimulator) {
        int i = arc4random() % 8;
        self.image = [UIImage imageNamed:[NSString stringWithFormat:@"imgs/img%d.jpg", i]];
        [self.imageView setImage:self.image];
    } else {
        [self.imageView setImage:nil];
        self.image = nil;
    }
    [self clearScreen];
    
    NSLog(@"recognition started");
    
    self.recognitionOn = YES;
    [self startRecognition];
    
    [self.session startRunning]; // blinks, how to fix?
}

- (void)startRecognition
{
    dispatch_async(self.queue, ^{
        while (self.recognitionOn) {
            @autoreleasepool {
                [self recognize];
                if (self.onSimulator) {
                    self.recognitionOn = NO;
                }
            }
        }
    });

}

- (void)recognize {
    UIImage *croppedImage = [self cropImage:self.image];
    
    //NSMutableArray *digits;
    //NSMutableArray *signs = [[NSMutableArray alloc] init];
    
    if (!CGSizeEqualToSize(croppedImage.size, CGSizeZero)) {
        NSArray *symbols = [self.imageProcessor findDigits:croppedImage];
        
        if ([symbols count] > 0 and self.recognitionOn) {
            [self getBlocks:symbols];
        }
    }
}

- (void)getBlocks:(NSArray *)symbols {
    NSArray *signsIndexes = [self peelSigns:symbols];
    NSMutableArray *numbersIndexes = [[NSMutableArray alloc] init];
    NSLog(@"initial # simbols: %lu", (unsigned long)[symbols count]);

    NSPredicate *check = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        Symbol *symbol = (Symbol *)evaluatedObject;
        return symbol.type == nil;
    }];
    
    while ([[symbols filteredArrayUsingPredicate:check] count] > 0) {
        [numbersIndexes addObject:[self peelDigitsFrom:symbols]];
    }
    
    symbols = [self recognizeSymbols:symbols];
    
    if ([numbersIndexes count] == [signsIndexes count] + 1 and self.recognitionOn) {
        self.symbols = symbols;
        self.signsIndexes = signsIndexes;
        self.numbersIndexes = numbersIndexes;
        
        [self display];
    }
}

- (void)display {
    [self makeExpression];
    
    [self drawExpression];
    
    [self drawAnswer];
}

- (NSArray *)peelSigns:(NSArray *)symbols {
    int minX = (int)[[symbols valueForKeyPath:@"@min.x"] integerValue];
    
    int averageWidth = 0;
    int averageHeight = 0;
    for (int i = 0; i< [symbols count]; i++ ) {
        Symbol *symbol = symbols[i];
        averageWidth += symbol.image.cols;
        averageHeight += symbol.image.rows;
    }
    averageWidth = averageWidth / [symbols count];
    averageHeight = averageHeight / [symbols count];
    self.fontSize = averageHeight * 9 / 10;
    //NSLog(@"minX: %d, averageWidth: %d", minX, averageWidth);
    
    NSMutableArray *signs = [[NSMutableArray alloc] init];
    
    for (int i = 0; i< [symbols count]; i++ ) {
        Symbol *symbol = symbols[i];
        if (symbol.x < minX+averageWidth) {
            [signs addObject:symbol];
        }
    }
    
    [signs sortUsingComparator:^NSComparisonResult(Symbol *s1, Symbol *s2) {
        NSNumber *x1 = [NSNumber numberWithInt:(int)s1.y];
        NSNumber *x2 = [NSNumber numberWithInt:(int)s2.y];
        return [x1 compare:x2];
    }];
    
    //NSLog(@"number of signs: %d", [signs count]);
    NSMutableArray *signsIndexes = [[NSMutableArray alloc] init];
    for (Symbol *sign in signs) {
        sign.type = @"sign";
        [signsIndexes addObject:[NSNumber numberWithUnsignedInteger:[symbols indexOfObjectIdenticalTo:sign]]];
    }
    //NSLog(@"sign index: %@", self.signsIndexes);
    return signsIndexes;
}

- (NSArray *)peelDigitsFrom:(NSArray *)symbols {
    NSArray *workingSymbols = [symbols filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        Symbol *symbol = (Symbol *)evaluatedObject;
        return symbol.type == nil;
    }]];
    
    int minY = (int)[[workingSymbols valueForKeyPath:@"@min.y"] integerValue];
    
    int averageHeight = 0;
    for (int i = 0; i< [workingSymbols count]; i++ ) {
        Symbol *digit = workingSymbols[i];
        averageHeight += digit.image.rows;
    }
    averageHeight = averageHeight / [workingSymbols count];
    
    NSMutableArray *row = [[NSMutableArray alloc] init];
    for (Symbol *digit in workingSymbols) {
        if (digit.y < minY + 0.7*averageHeight) {
            digit.y = minY;
            [row addObject:digit];
        }
    }
    
    [row sortUsingComparator:^NSComparisonResult(Symbol *s1, Symbol *s2) {
        NSNumber *x1 = [NSNumber numberWithInt:(int)s1.x];
        NSNumber *x2 = [NSNumber numberWithInt:(int)s2.x];
        return [x1 compare:x2];
    }];
    
    Symbol *firstSymbol = [row firstObject];
    Symbol *lastSymbol = [row lastObject];
    
    if ([row count] > 1) {
        for (int i = 0; i < [row count]; i++) {
            Symbol *symbol = row[i];
            symbol.x = firstSymbol.x + i * (lastSymbol.x - firstSymbol.x) / ([row count] - 1);
        }
    }
    
    NSMutableArray *numbersRow = [[NSMutableArray alloc] init];
    
    for (Symbol *digit in row) {
        digit.type = @"digit";
        [numbersRow addObject:[NSNumber numberWithUnsignedInteger:[symbols indexOfObjectIdenticalTo:digit]]];
    }

    return numbersRow;
}

- (NSArray *)recognizeSymbols:(NSArray *)symbols{
    for (Symbol *symbol in symbols) {
        NSMutableArray *flatImage;
        flatImage = [self.imageProcessor cvMat2MutableArray:symbol.image];
        
        int recognizedSymbol = [self.torch performClassification:flatImage
                                                            rows:symbol.image.rows
                                                            cols:symbol.image.cols
                                                            type:symbol.type];

        if ([symbol.type isEqualToString:@"digit"]) {
            symbol.symbol = [NSString stringWithFormat:@"%d", recognizedSymbol];
        } else if ([symbol.type isEqualToString:@"sign"]) {
            symbol.symbol = [NSString stringWithFormat:@"%@", [self signFromNumber:recognizedSymbol]];
        }
        //NSLog(symbol.symbol);
    }
    return symbols;
}

- (void)makeExpression {
    NSLog(@"making new expression");
    NSMutableArray *signs = [[NSMutableArray alloc] init];
    NSMutableArray *numbers = [[NSMutableArray alloc] init];
    
    //NSLog(@"signIndexes size: %lu", (unsigned long)[self.signsIndexes count]);
    //NSLog(@"numbersIndexes size: %lu", (unsigned long)[self.numbersIndexes count]);
    //NSLog(@"number of symbols: %lu", (unsigned long)[self.symbols count]);
    for (NSNumber *index in self.signsIndexes) {
        int i = (int)[index integerValue];
        Symbol *sign = self.symbols[i];
        //NSLog(@"sign x: %lu", (unsigned long)sign.x);
        //NSLog(@"sign at index %d: %@", i, sign.symbol);
        [signs addObject:sign.symbol];
        //NSLog(@"sign index: %d", i);
    }
    
    for (NSArray *row in self.numbersIndexes) {
        NSMutableString *string = [[NSMutableString alloc] initWithString:@""];
        for (NSNumber *index in row) {
            int i = (int)[index integerValue];
            Symbol *digit = self.symbols[i];
            [string appendString:digit.symbol];
        }
        [string appendString:@".0"];
        [numbers addObject:string];
    }
    
    //NSLog(@"numbers: %d, signs: %d", [numbers count], [signs count]);
    
    if ([numbers count] == [signs count] + 1) {
        /*for (int i = 0; i < [signs count]; i++) {
            Symbol *sign = signs[i];
            sign.y = ([numbers[i] integerValue] + [numbers[i+1] integerValue]) / 2;
        }*/
        self.answer = [self getAnswer:numbers signs:signs];
        NSLog(@"%@", self.answer);
    }
}

- (NSString *)getAnswer:(NSArray *)numbers signs:(NSArray *)signs {
    NSMutableString *expression = [[NSMutableString alloc] initWithString:@""];
    NSLog(@"number: %@, signs: %@", numbers, signs);
    [expression appendString:numbers[0]];
    for (int i = 0; i < [signs count]; i++) {
        [expression appendString:signs[i]];
        [expression appendString:numbers[i+1]];
    }
    NSLog(@"expression: %@", expression);
    
    NSExpression *expressionToProcess = [NSExpression expressionWithFormat:expression];
    NSNumber *answer = [expressionToProcess expressionValueWithObject:nil context:nil];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    return [NSString stringWithFormat:@"%@", [formatter stringFromNumber:answer]];
}

- (UIImage *)cropImage:(UIImage *)image {
    //NSLog(@"image to crop width: %f, height: %f", image.size.width, image.size.height);
    int viewWidth = self.view.bounds.size.width;
    int imgWidth = image.size.width;
    int imgHeight = image.size.height;
    
    float scale = (float)imgWidth / viewWidth;
    
    float x = FOCUS_RECT_X * scale;
    float y = [self padding] + [self focusRectY] * scale;
    int width = imgWidth - 2 * x;
    int height = imgHeight - ([self focusRectY]+[self focusRectYBottom]) * scale - 2 * [self padding];
    
    //NSLog(@"padding: %d, scale: %f, x: %f, y: %f, width: %d, height: %d", [self padding], scale, x, y, width, height);
    
    CGRect cropRect = CGRectMake(x, y, width, height);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self.image CGImage], cropRect);
    //Rotation from buffer doesn't apply to underlying CGimage here, so we have to apply same rotation here
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return croppedImage;
}



#pragma mark - display

- (void)clearScreen {
    for (UIView *view in self.imageView.subviews) {
        if ([view isKindOfClass:[SymbolView class]]) {
            [view removeObserver:self forKeyPath:@"targetContentOffset"];
        }
    }
    [self.imageView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
}

- (void)drawExpression {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearScreen];
        for (int i = 0; i < [self.symbols count]; i++ ) {
            Symbol *symbol = self.symbols[i];
            [self drawSymbol:symbol];
        }
    });
}

- (void)drawAnswer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.answer length] > 0) {
            self.answerLabel = [[UILabel alloc] initWithFrame:CGRectMake(FOCUS_RECT_X, self.view.bounds.size.height-[self focusRectYBottom]+10, self.view.bounds.size.width-2*FOCUS_RECT_X, [self focusRectYBottom]-20)];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];

            paragraphStyle.alignment = NSTextAlignmentCenter;
            
            CGFloat size = MIN([self focusRectYBottom]-25, 400/([self.answer length]+3));
            
            NSMutableAttributedString *labelValue = [[NSMutableAttributedString alloc] initWithString:self.answer
                                                                             attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:1 blue:1 alpha:1],
                                                                                          NSStrokeWidthAttributeName: @(0.0),
                                                                                          NSStrokeColorAttributeName:[UIColor redColor],
                                                                                          NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:size],
                                                                                          NSParagraphStyleAttributeName:paragraphStyle }];
            
            self.answerLabel.attributedText = labelValue;
            [self.answerLabel setNeedsDisplay];
            self.answerLabel.layer.cornerRadius = 6;
            self.answerLabel.layer.backgroundColor = [UIColor colorWithRed:247.0/255 green:82.0/255 blue:28.0/255 alpha:1].CGColor;
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleRecognition)];
            [self.answerLabel addGestureRecognizer:tap];
            self.answerLabel.userInteractionEnabled = YES;
            
            [self.imageView addSubview:self.answerLabel];
        }
    });
}

- (void)drawSymbol:(Symbol *)symbol {
    int x = FOCUS_RECT_X + symbol.x * self.imageView.bounds.size.width  / self.image.size.width;
    //NSLog(@"image size: %f %f", self.image.size.width, self.image.size.height);
    //NSLog(@"imageView size: %f %f", self.imageView.bounds.size.width, self.imageView.bounds.size.height);
    int y = [self focusRectY] + symbol.y * self.imageView.bounds.size.height  / (self.image.size.height - 2 * [self padding]);
    //NSLog(@"x: %d, y: %d, padding: %d", x, y, [self padding]);
    SymbolView *digitLabel = [[SymbolView alloc] initWithFrame:CGRectMake(x, y, self.fontSize*0.55, self.fontSize*0.8) symbol:symbol.symbol];
    
    //digitLabel.fontSize = self.fontSize;
    digitLabel.type = symbol.type;
    digitLabel.symbolIndex = [self.symbols indexOfObjectIdenticalTo:symbol];
    [self.imageView addSubview:digitLabel];
    [digitLabel addObserver:self forKeyPath:@"targetContentOffset" options:0 context:nil];
}

- (void)symbolChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"asdf");
        NSDictionary *change = (NSDictionary *)notification.object;
        int index = (int)((NSNumber *)[change objectForKey:@"index"]).integerValue;
        Symbol *symbol = self.symbols[index];
        symbol.symbol = (NSString *)[change objectForKey:@"symbol"];
        [self updateAdjustedSymbol:index];
        dispatch_async(self.queue, ^{
            [self makeExpression];
            [self drawAnswer];
        });
    });
}

@end
