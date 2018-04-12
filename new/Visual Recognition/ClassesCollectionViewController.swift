//
//  ClassesCollectionViewController.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 5/12/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import Photos
import CoreData

struct ClassObj {
    var pendingClass: PendingClass
    var image: UIImage
    var imageCount: Int
}

protocol CreateClassDelegate {
    func createClass()
    func removeClass()
}

class ClassesCollectionViewController: UICollectionViewController, ClassCellDelegate {    
    var classifier = PendingClassifier()
    var classes = [ClassObj]()
    
    var delegate: CreateClassDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Fix this...
        classes = []
        
        for result in classifier.relationship?.allObjects as! [PendingClass] {
            classes.append(grabPhoto(for: result))
        }

        let epoch = Date().addingTimeInterval(0 - Date().timeIntervalSince1970)
        classes = classes.sorted(by: { $0.pendingClass.created ?? epoch < $1.pendingClass.created ?? epoch })

        reloadData()
        
        if let classifierId = classifier.classifierId {
            Classifier.buildClassifier(fromId: classifierId, completion: { [weak self] classifier in
                guard let `self` = self else { return }
                let classNames: [String] = self.classes.flatMap({ result in
                    return result.pendingClass.name
                })
                
                let newClasses = classifier.classes.filter({ !classNames.contains($0) })
                
                let _ = newClasses.map({ className in
                    let pendingClassClassName: String = String(describing: PendingClass.self)
                    
                    let pendingClass: PendingClass = NSEntityDescription.insertNewObject(forEntityName: pendingClassClassName, into: DatabaseController.getContext()) as! PendingClass
                    
                    pendingClass.name = className
                    pendingClass.id = UUID().uuidString
                    pendingClass.created = Date()
                    pendingClass.isLocked = true
                    
                    self.classifier.addToRelationship(pendingClass)
                    
                    self.classes.append(self.grabPhoto(for: pendingClass))
                    
                    self.insertItem()
                    
                    DatabaseController.saveContext()
                })
                }, error: {
            })
        }
    }
    
    func reloadData() {
        collectionView?.reloadData()
    }

    func insertItem() {
        collectionView?.insertItems(at: [IndexPath(row: classes.count - 1, section: 0)])
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return classes.count + 1
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < classes.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "classCell", for: indexPath) as! ClassCollectionViewCell
            if classes[indexPath.item].imageCount > 0 {
                cell.classImageImageView.image = classes[indexPath.item].image
            } else {
                cell.classImageImageView.backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1)
                cell.classImageImageView.image = nil
            }
            
            cell.delegate = self
            
            cell.remove.isHidden = !isEditing || classes[indexPath.item].pendingClass.isLocked
            
            cell.classImageImageView.layer.cornerRadius = 5
            cell.classImageImageView.clipsToBounds = true

            cell.classImageImageView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15).cgColor
            cell.classImageImageView.layer.borderWidth = 1.0 / UIScreen.main.scale

            cell.classNameLabel.text = classes[indexPath.item].pendingClass.name
            cell.classImageCountLabel.text = String(describing: classes[indexPath.item].imageCount)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "newClassCell", for: indexPath)
            if isEditing {
                cell.viewWithTag(0)?.alpha = 0.4
            } else {
                cell.viewWithTag(0)?.alpha = 1.0
            }
            cell.isUserInteractionEnabled = !isEditing
            cell.viewWithTag(1)?.layer.cornerRadius = 5
            cell.viewWithTag(1)?.clipsToBounds = true
            cell.viewWithTag(1)?.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15).cgColor
            cell.viewWithTag(1)?.layer.borderWidth = 1.0 / UIScreen.main.scale
            return cell
        }
    }
    
    func grabPhoto(for pendingClass: PendingClass) -> ClassObj {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl.appendingPathComponent(classifier.id!).appendingPathComponent(pendingClass.id!), includingPropertiesForKeys: nil, options: [])

            // if you want to filter the directory contents you can do like this:
            let jpgFiles = directoryContents.filter{ $0.pathExtension == "jpg" }
                .map { url -> (URL, TimeInterval) in
                    var lastModified = try? url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey])
                    return (url, lastModified?.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0)
                }
                .sorted(by: { $0.1 > $1.1 }) // sort descending modification dates
                .map{ $0.0 }

            return ClassObj(
                pendingClass: pendingClass,
                image: UIImage(contentsOfFile: jpgFiles.first!.path)!,
                imageCount: jpgFiles.count
            )

        } catch {
            print(error.localizedDescription)
        }
        return ClassObj(pendingClass: pendingClass, image: UIImage(), imageCount: 0)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        reloadData()
    }
    
    func remove(cell: ClassCollectionViewCell) {
        guard let indexPath = collectionView?.indexPath(for: cell) else {
            return
        }
        
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let classToRemove = classes[indexPath.item].pendingClass
        
        let path = documentsUrl.appendingPathComponent(classifier.id!).appendingPathComponent(classToRemove.id!)

        do {
            try FileManager.default.removeItem(at: path)
            DatabaseController.getContext().delete(classToRemove)
            DatabaseController.saveContext()
            delegate?.removeClass()
        } catch {
            // We might have tried to delete a folder that didn't exist (because no images were take)
            // so it's safe to remove the database connection
            print("Error: \(error.localizedDescription)")
            if FileManager.default.fileExists(atPath: path.path) {
                print("still exists")
            } else {
                DatabaseController.getContext().delete(classToRemove)
                DatabaseController.saveContext()
                delegate?.removeClass()
            }
        }
        
        classes.remove(at: indexPath.item)
        collectionView?.deleteItems(at: [indexPath])
    }
    
    @IBAction func createClass() {
        let classNames = self.classes.map{ $0.pendingClass.name! }

        let basename = "Untitled"
        var name = basename
        var count = 1

        while classNames.contains(name) {
            count += 1
            name = "\(basename)-\(count)"
        }

        let pendingClassClassName: String = String(describing: PendingClass.self)

        let pendingClass: PendingClass = NSEntityDescription.insertNewObject(forEntityName: pendingClassClassName, into: DatabaseController.getContext()) as! PendingClass

        pendingClass.name = name
        pendingClass.id = UUID().uuidString
        pendingClass.created = Date()

        self.classifier.addToRelationship(pendingClass)

        self.classes.append(self.grabPhoto(for: pendingClass))

        self.insertItem()

        DatabaseController.saveContext()
        
        delegate?.createClass()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        switch(identifier ?? "") {
        case "showSnapper":
            return !isEditing
        default:
            return true
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "showSnapper":
            guard let destination = segue.destination as? AdditionalSnapperViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedCell = sender as? ClassCollectionViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = collectionView?.indexPath(for: selectedCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedItem = classes[indexPath.row]
            destination.pendingClass = selectedItem.pendingClass
            destination.classifier = classifier
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
}
