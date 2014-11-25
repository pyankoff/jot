//
//  SymbolView.m
//  JotCalculator
//
//  Created by Andrey Pyankov on 22/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

#import "SymbolView.h"

@interface SymbolView ()
+ (NSArray *)validSigns;
- (NSString *)signFromNumber:(int)number;
@end

@implementation SymbolView

+ (NSArray *)validSigns {
    return @[@"/", @"*", @"+", @"-"];
}

- (NSString *)signFromNumber:(int)number {
    return [SymbolView validSigns][number];
}

- (int)numberFromSign:(NSString *)symbol {
    int number;
    if ([self.type  isEqual: @"sign"]) {
        number = (int)[[SymbolView validSigns] indexOfObjectIdenticalTo:symbol];
    } else if ([self.type  isEqual: @"digit"]) {
        number = (int)[symbol integerValue];
    }
    return number;
}

- (void)setSymbol:(NSString *)symbol {
    if (!_symbol) {
        _symbol = @"";
    }
    _symbol = symbol;
    _symbolNumber = [self numberFromSign:_symbol];
    NSMutableParagraphStyle *paragraphStyle= [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    
    self.attributedText = [[NSAttributedString alloc] initWithString:_symbol
                attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4],
                             NSStrokeWidthAttributeName: @(-1.5),
                             NSStrokeColorAttributeName:[UIColor colorWithRed:247.0/255 green:82.0/255 blue:28.0/255 alpha:1],
                             NSFontAttributeName: [UIFont boldSystemFontOfSize:self.fontSize],
                             NSParagraphStyleAttributeName: paragraphStyle }];
}

- (void)setSymbolNumber:(int)symbolNumber {
    _symbolNumber = symbolNumber;
    if ([self.type  isEqual: @"sign"]) {
        self.symbol = [self signFromNumber:symbolNumber];
    } else if ([self.type  isEqual: @"digit"]) {
        self.symbol = [NSString stringWithFormat:@"%d", symbolNumber];
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
