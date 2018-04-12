//
//  Extensions.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 4/5/18.
//  Copyright © 2018 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import Foundation

extension UIImage {
    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension UIRefreshControl {
    func beginRefreshingManually() {
        // This may cause issues with our swanky navigation controller.
        if let scrollView = superview as? UIScrollView {
            if (scrollView.contentOffset.y == 0) {
                scrollView.setContentOffset(CGPoint(x: 0, y: -frame.height), animated: true)
                beginRefreshing()
            }
        }
    }
}
