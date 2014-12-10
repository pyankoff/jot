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
    
    let pageImages = ["column",
                "separate",
                "no_shit",
                "no_shit2",
                "iphone_hand",
                "iphone_swipe"]
    
    let pageHeadings: [NSString] = ["Write","Focus","Compute","Adjust"]
    
    var pageLabels: [NSString] = ["Write expression in column",
            "Make sure all digits are separated",
            "Adjust frame to fit the expression",
            "Don't include any other marks",
            "Tap equals sign to get answer. Tap answer to start new calculation",
            "Swipe digits to adjust"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.frame.size = CGSize(width: min(self.view.bounds.width, self.view.bounds.height), height: max(self.view.bounds.width, self.view.bounds.height))
        
        scrollView.contentSize = CGSize(width: scrollView.frame.size.width,
            height: scrollView.frame.size.height * CGFloat(pageHeadings.count+1))
        
        addHeading(0)
        addCaption(0, page: 0, y: 0.2*height())
        addImage(pageImages[0], page: 0, y: 0.25*height(), imgHeight: 0.3*height())
        addCaption(1, page: 0, y: 0.6*height())
        addImage(pageImages[1], page: 0, y: 0.65*height(), imgHeight: 0.3*height())
        
        addHeading(1)
        addCaption(2, page: 1, y: 0.2*height())
        addImage(pageImages[2], page: 1, y: 0.25*height(), imgHeight: 0.3*height())
        addCaption(3, page: 1, y: 0.6*height())
        addImage(pageImages[3], page: 1, y: 0.65*height(), imgHeight: 0.3*height())
        
        
        addHeading(2)
        addCaption(4, page: 2, y: 0.2*height())
        addImage(pageImages[4], page: 2, y: 0.3*height(), imgHeight: 0.65*height())
        
        
        addHeading(3)
        addCaption(5, page: 3, y: 0.2*height())
        addImage(pageImages[5], page: 3, y: 0.3*height(), imgHeight: 0.65*height())

        addCloseButtons()
        addContacts()
        
    }
    
    func width() -> CGFloat {
        return scrollView.frame.size.width
    }
    
    func height() -> CGFloat {
        return scrollView.frame.size.height
    }
    
    func addContacts() {
        let totalHeight = height() * CGFloat(pageHeadings.count) + 0.1*height()
        let caption = UILabel(frame: CGRect(x: 20, y: totalHeight, width: width() - 40, height: 40))
        caption.textColor = UIColor.whiteColor()
        caption.textAlignment = NSTextAlignment.Center
        caption.text = "Tell us what you think:"
        caption.font = UIFont(name: "HelveticaNeue-Light", size: 28)
        caption.numberOfLines = 1
        
        let iconHeight = 0.2 * height()
        let x = (width() - iconHeight)/2
        
        let icons = ["facebook", "twitter", "mail"]
        
        for i in 0...2 {
            let y = 0.2 * height() +  height() * CGFloat(pageHeadings.count) + 0.20 * height() * CGFloat(i)
            let icon = UIButton(frame: CGRect(x: x, y: y, width: iconHeight, height: iconHeight))
            icon.setImage(UIImage(named: icons[i]), forState: .Normal)
            icon.addTarget(self, action: "goTo:", forControlEvents: .TouchUpInside)
            icon.tag = i
            scrollView.addSubview(icon)
        }
        
        scrollView.addSubview(caption)
    }
    
    func goTo(sender: UIButton) {
        if sender.tag == 0 {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://facebook.com/jotcalculator")!)
        } else if sender.tag == 1 {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://twitter.com/jotcalculator")!)
        } else if sender.tag == 2 {
            println("huy")
            UIApplication.sharedApplication().openURL(NSURL(string: "mailto:jotcalculator@gmail.com")!)
        }
    }
    
    func addHeading(page: Int) {
        let y = 0.03 * height() + height() * CGFloat(page)
        let caption = UILabel(frame: CGRect(x: 20, y: y, width: width() - 40, height: 120))
        
        caption.textColor = UIColor.whiteColor()
        caption.textAlignment = NSTextAlignment.Center
        caption.text = pageHeadings[page]
        caption.font = UIFont(name: "HelveticaNeue-UltraLight", size: 32)
        caption.numberOfLines = 1
        
        scrollView.addSubview(caption)
    }
    
    func addCaption(index: Int, page: Int, y: CGFloat) {
        let y = y + height() * CGFloat(page)
        let caption = UILabel(frame: CGRect(x: 20, y: y, width: width() - 40, height: 120))
        
        caption.textColor = UIColor.whiteColor()
        caption.textAlignment = NSTextAlignment.Center
        caption.text = pageLabels[index]
        caption.font = UIFont(name: "HelveticaNeue-Light", size: 18)
        caption.numberOfLines = 0
        caption.sizeToFit()
        let captionFrame = CGRect(x: 20, y: y, width: width() - 40, height: caption.frame.height)
        caption.frame = captionFrame
        
        scrollView.addSubview(caption)
    }
    
    func addImage(imageName: NSString, page: Int, y: CGFloat, imgHeight: CGFloat) {
        let image = UIImage(named: imageName)!
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let photoHeight = imgHeight //0.65 * height()
        let photoWidth = 0.9 * width()
        
        let photoY = y +  height() * CGFloat(page)
        var frame = CGRect(x: (width()-photoWidth)/2, y: photoY, width: photoWidth, height: photoHeight)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        imageView.frame = frame
        scrollView.addSubview(imageView)
    }
    
    func addCloseButtons() {
        let closeTop = UIButton(frame: CGRect(x: width() - 90, y: 20, width: 80, height: 40))
        closeTop.setTitle("Close", forState: .Normal)
        closeTop.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        closeTop.titleLabel!.font = UIFont(name: "HelveticaNeue-Light", size:18)
        closeTop.addTarget(self, action: "close", forControlEvents: .TouchUpInside)
        
        let totalHeight = height() * CGFloat(pageHeadings.count+1) - 60
        let closeBottom = UIButton(frame: CGRect(x: width()/2-40, y: totalHeight, width: 80, height: 40))
        closeBottom.setTitle("Close", forState: .Normal)
        closeBottom.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        closeBottom.titleLabel!.font = UIFont(name: "HelveticaNeue-Light", size:18)
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
        return Int(UIInterfaceOrientationMask.Portrait.rawValue)
    }
}
