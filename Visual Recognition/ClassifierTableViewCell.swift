//
//  ClassiferTableViewCell.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 5/8/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
class ClassifierTableViewCell: UITableViewCell {
    @IBOutlet weak var classifierNameLabel: UILabel!
    @IBOutlet weak var classifierIdLabel: UILabel!
    @IBOutlet weak var classifierStatusEmoji: UILabel!
    @IBOutlet weak var leftPadding: NSLayoutConstraint!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var status: Classifier.Status = .ready {
        didSet {
            switch status {
            case .ready:
                accessoryType = .disclosureIndicator
                leftPadding.constant = 0
                classifierStatusEmoji?.text = ""
                classifierNameLabel?.alpha = 1.0
                classifierIdLabel?.alpha = 1.0
                activityIndicator?.stopAnimating()
                activityIndicator?.isHidden = true
            case .training, .retraining:
                accessoryType = .none
                leftPadding.constant = 48
                activityIndicator.layoutIfNeeded()
                classifierNameLabel?.alpha = 0.4
                classifierIdLabel?.alpha = 0.4
                activityIndicator?.startAnimating()
                activityIndicator?.isHidden = false
                classifierStatusEmoji?.text = "😴"
                classifierIdLabel?.text = status.rawValue
            case .failed:
                accessoryType = .none
                leftPadding.constant = 0
                classifierNameLabel?.alpha = 0.4
                classifierIdLabel?.alpha = 0.4
                activityIndicator?.stopAnimating()
                activityIndicator?.isHidden = true
                classifierStatusEmoji?.text = "😭"
                classifierIdLabel?.text = "Verify there are at least 10 images per class."
            }
        }
    }
}
