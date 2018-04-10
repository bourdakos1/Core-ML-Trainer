//
//  ClassCollectionViewCell.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 5/12/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit

protocol ClassCellDelegate {
    func remove(cell: ClassCollectionViewCell)
}

class ClassCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var classNameLabel: UILabel!
    @IBOutlet weak var classImageCountLabel: UILabel!
    @IBOutlet weak var classImageImageView: UIImageView!
    @IBOutlet weak var remove: UIButton! {
        didSet {
            remove.isHidden = true
        }
    }
    
    var delegate: ClassCellDelegate?
    
    @IBAction func remove(sender: UIButton) {
        delegate?.remove(cell: self)
    }
}
