//
//  SymbolView.h
//  JotCalculator
//
//  Created by Andrey Pyankov on 22/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SymbolView : UIScrollView

@property (strong, nonatomic) NSString *type;

@property (nonatomic) int symbolNumber;
@property (strong, nonatomic) NSString *symbol;

@property (nonatomic) int symbolIndex;
@property (nonatomic) int fontSize;

@end
