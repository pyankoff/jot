//
//  InfoViewController.swift
//  JotCalculator
//
//  Created by Andrey Pyankov on 26/11/14.
//  Copyright (c) 2014 AP. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    
    var pageImages: [UIImage] = []
    var pageLabels: [NSString] = ["Just point your camera at expression",
            "Get instant answer",
            "Swipe up-down to adjust digits",
            "Jot learns from your writing"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageImages = [UIImage(named: "imgs/iphone0.png")!,
            UIImage(named: "imgs/iphone0.png")!,
            UIImage(named: "imgs/iphone0.png")!,
            UIImage(named: "imgs/iphone0.png")!]
        
        scrollView.frame.size = self.view.frame.size
        
        scrollView.contentSize = CGSize(width: scrollView.frame.size.width,
            height: scrollView.frame.size.height * CGFloat(pageImages.count+1))
        
        for i in 0..<pageImages.count {
            
            addCaption(i)
            addImage(i)
            addCloseButtons()
            addContacts()
            
        }
        
    }
    
    func width() -> CGFloat {
        return scrollView.frame.size.width
    }
    
    func height() -> CGFloat {
        return scrollView.frame.size.height
    }
    
    func addContacts() {
        let totalHeight = height() * CGFloat(pageImages.count) + 50
        let caption = UILabel(frame: CGRect(x: 20, y: totalHeight, width: width() - 40, height: 120))
        caption.textColor = UIColor.whiteColor()
        caption.textAlignment = NSTextAlignment.Center
        caption.text = "Please contact us:"
        caption.font = UIFont(name: "HelveticaNeue-Light", size: 28)
        caption.numberOfLines = 3
        scrollView.addSubview(caption)
    }
    
    func addCaption(i: Int) {
        let y = 30 + scrollView.frame.size.height * CGFloat(i)
        let caption = UILabel(frame: CGRect(x: 20, y: y, width: width() - 40, height: 120))
        caption.textColor = UIColor.whiteColor()
        caption.textAlignment = NSTextAlignment.Center
        caption.text = pageLabels[i]
        caption.font = UIFont(name: "HelveticaNeue-Light", size: 28)
        caption.numberOfLines = 3
        scrollView.addSubview(caption)
    }
    
    func addImage(i: Int) {
        let imageWidth = pageImages[i].size.width
        let imageHeight = pageImages[i].size.height
        
        let photoWidth = CGFloat(250.0)
        let photoHeight = imageHeight * photoWidth / imageWidth
        let photoX = CGFloat((width()-photoWidth) / CGFloat(2))
        
        let photoY = (height() - photoHeight - 20) +  height() * CGFloat(i)
        var frame = CGRect(x: photoX, y: photoY, width: photoWidth, height: photoHeight)
        
        let image = UIImageView(image: pageImages[i])
        image.contentMode = .ScaleAspectFit
        image.frame = frame
        scrollView.addSubview(image)
    }
    
    func addCloseButtons() {
        let totalHeight = height() * CGFloat(pageImages.count+1) - 40
        let closeTop = UIButton(frame: CGRect(x: width() - 70, y: 30, width: 50, height: 20))
        closeTop.setTitle("Close", forState: .Normal)
        closeTop.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        closeTop.titleLabel!.font = UIFont(name: "HelveticaNeue-UltraLight", size:18)
        closeTop.addTarget(self, action: "close", forControlEvents: .TouchUpInside)
        
        let closeBottom = UIButton(frame: CGRect(x: width()/2-25, y: totalHeight, width: 50, height: 20))
        closeBottom.setTitle("Close", forState: .Normal)
        closeBottom.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        closeBottom.titleLabel!.font = UIFont(name: "HelveticaNeue", size:18)
        closeBottom.addTarget(self, action: "close", forControlEvents: .TouchUpInside)
        
        scrollView.addSubview(closeTop)
        scrollView.addSubview(closeBottom)
    }
    
    func close() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return UIInterfaceOrientation.Portrait.rawValue
    }
}
