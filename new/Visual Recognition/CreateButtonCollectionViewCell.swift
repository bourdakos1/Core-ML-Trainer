//
//  CreateButtonCollectionViewCell.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 4/11/18.
//  Copyright © 2018 Nicholas Bourdakos. All rights reserved.
//

import UIKit

class CreateButtonCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var button: UIButton! {
        didSet {
            button.layer.cornerRadius = 5
            button.clipsToBounds = true
            button.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15).cgColor
            button.layer.borderWidth = 1.0 / UIScreen.main.scale
        }
    }
    
    var isVisible = true {
        didSet {
            if isVisible {
                stackView.alpha = 1.0
                button.alpha = 1.0
            } else {
                stackView.alpha = 0.4
                button.alpha = 0.4
            }
            isUserInteractionEnabled = isVisible
        }
    }
}

