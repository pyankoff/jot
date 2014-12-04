//
//  SymbolView.swift
//  JotCalculator
//
//  Created by Andrey Pyankov on 30/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

import UIKit

class SymbolView: UIScrollView, UIScrollViewDelegate {
    var symbolIndex: Int = 0
    var type: NSString?
    var symbol: NSString
    var count: Int = 9
    var nearestIndex: Int = 0 {
        didSet {
            symbol = symbolFromInt(nearestIndex)
        }
    }
    let signs = ["/", "*", "+", "-"]
    
    func symbolFromInt(i: Int) -> NSString {
        if count == 10 {
            return "\(count-i-1)"
        } else {
            return signs[i]
        }
    }
    
    func symbolToFloat(symbol: NSString) -> CGFloat {
        if count == 10 {
            return CGFloat(count-symbol.integerValue-1)
        } else {
            return CGFloat(find(signs, symbol)!)
        }
    }
    
    init(frame: CGRect, symbol: NSString) {
        self.symbol = symbol
        super.init(frame: frame)
        
        if let n = (symbol as String).toInt() {
            //println("number")
            count = 10
        } else {
            //println("sign")
            count = 4
        }
        
        contentSize = CGSize(width: frame.width, height: frame.height*CGFloat(count))
        showsVerticalScrollIndicator = false
        decelerationRate = UIScrollViewDecelerationRateFast
        delegate = self
        
        for i in 0...count-1 {
            let y = frame.height * CGFloat(i)
            let caption = UILabel(frame: CGRect(x: 0, y: y, width: frame.width, height: frame.height))
            caption.textColor = UIColor(red: 247/255, green: 82/255, blue: 28/255, alpha: 1)
            caption.textAlignment = NSTextAlignment.Center
            caption.text = symbolFromInt(i)
            caption.font = UIFont(name: "HelveticaNeue-Light", size: frame.height)
            
            self.addSubview(caption)
        }
        
        contentOffset.y = symbolToFloat(symbol) * frame.height
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName("symbolChange", object: nil)
    }
    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        nearestIndex = Int(round(targetContentOffset.memory.y / frame.height))
        println("view: \(nearestIndex), \(symbolIndex)")
        targetContentOffset.memory = CGPointMake(0, CGFloat(nearestIndex)*frame.height)
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        var change:Dictionary = ["index" : symbolIndex, "symbol" : symbol]
        NSNotificationCenter.defaultCenter().postNotificationName("symbolValue", object: change)
    }
}
