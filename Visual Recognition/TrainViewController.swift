//
//  TrainViewController.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 7/24/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import CoreData

class TrainViewController: UIViewController {
    @IBOutlet var modelName: UITextField! {
        didSet {
            if classifier.name != "Untitled Model" {
                modelName.text = classifier.name
            }
        }
    }
    
    var classifier = PendingClassifier()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        modelName.becomeFirstResponder()
    }

    @IBAction func train() {
        print("train")
        // Show an activity indicator while its loading.
        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        
        alert.view.tintColor = UIColor.black
        let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50)) as UIActivityIndicatorView
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        loadingIndicator.startAnimating()
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        
        if let text = modelName.text, text.isEmpty {
            classifier.name = "Untitled Model"
        } else if let text = modelName.text {
            classifier.name = text
        }
        
        DatabaseController.saveContext()
        
        // Not sure if this needs to be weak or unowned. You shouldn't be able to leave the page so we can probably leave it as is...?
        // Lets do weak to be safe
        classifier.train(completion: { [weak self] response in
            guard let `self` = self else { return }
            self.dismiss(animated: false, completion: {
                self.performSegue(withIdentifier: "unwindToClassifiersFromTrain", sender: self)
            })
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let text = modelName.text, text.isEmpty {
            classifier.name = "Untitled Model"
        } else if let text = modelName.text {
            classifier.name = text
        }
        
        DatabaseController.saveContext()
        
        if  segue.identifier == "additionalClasses",
            let destination = segue.destination as? SnapperViewController {
            
            let pendingClassClassName: String = String(describing: PendingClass.self)
            
            let newPendingClass: PendingClass = NSEntityDescription.insertNewObject(forEntityName: pendingClassClassName, into: DatabaseController.getContext()) as! PendingClass
            
            newPendingClass.id = UUID().uuidString
            newPendingClass.name = String()
            newPendingClass.created = Date()
            
            classifier.addToRelationship(newPendingClass)
            
            DatabaseController.saveContext()
            destination.pendingClass = newPendingClass
            destination.classifier = classifier
        }
    }

}
