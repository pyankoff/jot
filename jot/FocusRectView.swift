//
//  FocusRectView.swift
//  JotCalculator
//
//  Created by Andrey Pyankov on 09/12/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

import UIKit

class FocusRectView: UIView {
    
    var leftEdge: CGFloat = 0
    
    var topEdge: CGFloat = 0
    
    var maxHeight: CGFloat = 0
    
    var adjustmentY: CGFloat = 0
    
    var adjustmentX: CGFloat = 0
    
    var baseX: CGFloat = 0
    
    var baseY: CGFloat = 0
    
    func top() -> CGFloat {
        return max(min(adjustmentY + baseY, topEdge+maxHeight/2-frame.height/10), topEdge);
    }
    
    func height() -> CGFloat {
        return min(max(maxHeight + 2*(topEdge - top()), frame.height/5), maxHeight);
    }
    
    func left() -> CGFloat {
        return max(min(adjustmentX + baseX, frame.width/2.8), leftEdge);
    }
    
    func width() -> CGFloat {
        return frame.width - 2 * left()
    }
    
    override func drawRect(rect: CGRect) {
        let c = UIGraphicsGetCurrentContext()
        //println("\(left()), \(top()), \(width()), \(height())")
        var path = UIBezierPath(rect: frame)
        var holePath = UIBezierPath(roundedRect: CGRectMake(left(), top(), width(), height()), cornerRadius: 6)
        path.appendPath(holePath)
        path.usesEvenOddFillRule = true
        
        CGContextAddPath(c, path.CGPath)
        CGContextSetFillColorWithColor(c, UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).CGColor)
        CGContextDrawPath(c, kCGPathEOFill)
        
        CGContextTranslateCTM(c, left(), top())
        drawCorner()
        CGContextTranslateCTM(c, width(), 0)
        CGContextRotateCTM(c, CGFloat(M_PI_2))
        drawCorner()
        CGContextTranslateCTM(c, height(), 0)
        CGContextRotateCTM(c, CGFloat(M_PI_2))
        drawCorner()
        CGContextTranslateCTM(c, width(), 0)
        CGContextRotateCTM(c, CGFloat(M_PI_2))
        drawCorner()
    }
    
    func drawCorner() {
        let c = UIGraphicsGetCurrentContext()
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 10, 40)
        CGPathAddLineToPoint(path, nil, 10, 10)
        CGPathAddLineToPoint(path, nil, 40, 10)

        CGContextAddPath(c, path)
        CGContextSetLineWidth(c, 4)
        CGContextSetStrokeColorWithColor(c , UIColor.whiteColor().CGColor)
        CGContextStrokePath(c)
    }

    
    func setup() {
        backgroundColor = nil;
        contentMode = UIViewContentMode.Redraw;
        userInteractionEnabled = true
    }
    
    override func awakeFromNib() {
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
 
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
   

}
