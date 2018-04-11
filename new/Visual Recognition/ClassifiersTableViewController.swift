//
//  ClassifiersTableViewController.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 3/20/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import CoreData
import Alamofire

class ClassifiersTableViewController: UITableViewController {
    let API_KEY: String = {
        if let path = Bundle.main.path(forResource: "Keys", ofType: "plist") {
            return (NSDictionary(contentsOfFile: path)?["API_KEY"] as? String)!
        }
        return ""
    }()
    
    var pending = [PendingClassifier]()
    var classifiers = [Classifier]()
    var isLoading = false
    
    func loadClassifiers() {
        if isLoading { return }
        
        isLoading = true
        Classifier.buildList(completion: { [weak self] classifiers in
            guard let `self` = self else { return }
            
            let numberOfSections = self.calculateNumberOfSections(self.pending, classifiers)
            
            // Instead of blindly reloading the entire list, we should reload/insert/remove row.
            var indexesToAdd = [IndexPath]()
            for classifier in classifiers {
                if !self.classifiers.contains(where: { $0.isEqual(classifier) }) {
                    print("inserting row \(indexesToAdd.count): \(classifier.name)")
                    indexesToAdd.append(IndexPath(row: indexesToAdd.count, section: numberOfSections - 1))
                }
            }
            
            var indexesToDelete = [IndexPath]()
            for classifier in self.classifiers {
                if !classifiers.contains(where: { $0.isEqual(classifier)}) {
                    let itemToDelete = self.classifiers.index(where: {$0.classifierId == classifier.classifierId})!
                    print("removing row \(itemToDelete): \(classifier.name)")
                    indexesToDelete.append(IndexPath(row: itemToDelete, section: numberOfSections - 1))
                }
            }
            
            var indexesToUpdate = [IndexPath]()
            for classifier in self.classifiers {
                // If the new classifier matches one of the old classifiers, but the status is different.
                if classifiers.contains(where: { $0.isEqual(classifier) && $0.status != classifier.status}) {
                    let itemToUpdate = self.classifiers.index(where: {$0.classifierId == classifier.classifierId})!
                    print("reloading row \(itemToUpdate): \(classifier.name)")
                    indexesToUpdate.append(IndexPath(row: itemToUpdate, section: numberOfSections - 1))
                }
            }
            
            self.classifiers = classifiers
            self.tableView.beginUpdates()
            self.tableView.insertRows(at: indexesToAdd, with: .automatic)
            self.tableView.deleteRows(at: indexesToDelete, with: .automatic)
            self.tableView.reloadRows(at: indexesToUpdate, with: .automatic)
            if numberOfSections > self.tableView.numberOfSections {
                self.tableView.insertSections([numberOfSections - 1], with: .automatic)
            } else if numberOfSections < self.tableView.numberOfSections {
                self.tableView.deleteSections([self.tableView.numberOfSections - 1], with: .automatic)
            }
            self.tableView.endUpdates()
            
            self.isLoading = false
            self.refreshControl?.endRefreshing()
            
            // After we update our table, check if anything is still training.
            let training = self.classifiers.filter({ $0.status == .training || $0.status == .training })
            if training.count > 0 {
                // If things are still training recheck in 4 seconds.
                self.reloadClassifiers()
            }
            
            }, error: { [weak self] in
                guard let `self` = self else { return }
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
                return
        })
    }

    func reloadClassifiers() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4), execute: { [weak self] in
            guard let `self` = self else { return }
            self.loadClassifiers()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = true
        }
        
        let fetchRequest:NSFetchRequest<PendingClassifier> = PendingClassifier.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "classifierId = nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PendingClassifier.created), ascending: false)]

        do {
            pending = try DatabaseController.getContext().fetch(fetchRequest)
        } catch {
            print("Error: \(error)")
        }
        tableView.reloadData()
        refreshControl?.beginRefreshingManually()
        loadClassifiers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl?.addTarget(self, action: #selector(self.loadClassifiers), for: .valueChanged)
        
        tableView.estimatedRowHeight = 85.0
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    @IBAction func unwindToClassifiers(segue: UIStoryboardSegue) {
        // Unwind
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        switch(identifier ?? "") {
        case "retrainClassifier":
            guard let selectedCell = sender as? ClassifierTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedItem = classifiers[indexPath.row]
            return selectedItem.status == .ready
        default:
            return true
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "showSnapperFromScratch":
            guard let destination = segue.destination as? SnapperViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            let pendingClassifierClassName:String = String(describing: PendingClassifier.self)
            
            let pendingClassifier:PendingClassifier = NSEntityDescription.insertNewObject(forEntityName: pendingClassifierClassName, into: DatabaseController.getContext()) as! PendingClassifier
            pendingClassifier.id = UUID().uuidString
            pendingClassifier.name = "Untitled Model"
            pendingClassifier.created = Date()
            
            // Create a new class thats blank
            let pendingClassClassName: String = String(describing: PendingClass.self)
            
            let pendingClass: PendingClass = NSEntityDescription.insertNewObject(forEntityName: pendingClassClassName, into: DatabaseController.getContext()) as! PendingClass
            
            pendingClass.id = UUID().uuidString
            pendingClass.name = String()
            pendingClass.created = Date()
            
            pendingClassifier.addToRelationship(pendingClass)
            
            DatabaseController.saveContext()
            
            destination.pendingClass = pendingClass
            destination.classifier = pendingClassifier
            
        case "draftedClassifier":
            guard let destination = segue.destination as? ClassesViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedCell = sender as? UITableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedItem = pending[indexPath.row]
            destination.classifier = selectedItem
            
        case "retrainClassifier":
            guard let destination = segue.destination as? ClassesViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedCell = sender as? ClassifierTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedItem = classifiers[indexPath.row]
            
            let fetchRequest: NSFetchRequest<PendingClassifier> = PendingClassifier.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "classifierId == %@", selectedItem.classifierId)
            // We probably want the newest one? But there should only be 1!
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PendingClassifier.created), ascending: false)]
            
            do {
                if let model: PendingClassifier = try DatabaseController.getContext().fetch(fetchRequest).first {
                    // We already have a model for the classifier id, so show that
                    destination.classifier = model
                    return
                }
                
            } catch {
                print("Error: \(error)")
            }
            
            // We didn't find anything, make one.
            let pendingClassifierClassName:String = String(describing: PendingClassifier.self)
            
            let pendingClassifier:PendingClassifier = NSEntityDescription.insertNewObject(forEntityName: pendingClassifierClassName, into: DatabaseController.getContext()) as! PendingClassifier
            pendingClassifier.id = UUID().uuidString
            pendingClassifier.name = selectedItem.name
            pendingClassifier.classifierId = selectedItem.classifierId
            pendingClassifier.created = Date()
            
            DatabaseController.saveContext()
            
            destination.classifier = pendingClassifier
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    func calculateNumberOfSections(_ pending: [PendingClassifier], _ classifiers: [Classifier]) -> Int {
        if pending.count <= 0 && classifiers.count <= 0 {
            return 0
        }
        if pending.count <= 0 || classifiers.count <= 0 {
            return 1
        }
        return 2
    }
}

extension ClassifiersTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return calculateNumberOfSections(pending, classifiers)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if pending.count > 0 && section == 0 {
            return pending.count
        }
        
        if classifiers.count > 0 && section == 0 {
            return classifiers.count
        }
        
        return classifiers.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if pending.count > 0 && section == 0 {
            return "🍺 drafts"
        }
        
        if classifiers.count > 0 && section == 0 {
            return "🚀 trained"
        }
        
        return "🚀 trained"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if pending.count > 0 && indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            cell.textLabel?.text = pending[indexPath.item].name!
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell2", for: indexPath) as! ClassifierTableViewCell
            
            let classifierData = classifiers[indexPath.item]
            
            cell.classifierNameLabel?.text = classifierData.name
            cell.classifierIdLabel?.text = classifierData.classifierId
            cell.status = classifierData.status
            
            return cell
        }
    }
}

extension ClassifiersTableViewController {
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if pending.count > 0 && indexPath.section == 0 {
                let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                
                let path = documentsUrl.appendingPathComponent(pending[indexPath.item].id!)
                
                do {
                    try FileManager.default.removeItem(at: path)
                    DatabaseController.getContext().delete(pending[indexPath.item])
                    DatabaseController.saveContext()
                    pending.remove(at: indexPath.item)
                    
                    let numberOfSection = calculateNumberOfSections(pending, classifiers)
                    
                    // If there is only one section just delete it.
                    if pending.count <= 0 && numberOfSection == 1 {
                        tableView.beginUpdates()
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        tableView.deleteSections([0], with: .automatic)
                        tableView.endUpdates()
                        tableView.setEditing(false, animated: false)
                    }
                        // If there is more than one section (i.e. 2). delete the first one and move the second one to the first
                    else if pending.count <= 0 && numberOfSection > 1 {
                        tableView.beginUpdates()
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        tableView.deleteSections([0], with: .automatic)
                        tableView.moveSection(1, toSection: 0)
                        tableView.endUpdates()
                        tableView.setEditing(false, animated: false)
                    }
                        // If we still have pending models we can delete it no issue.
                    else {
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                } catch {
                    // If it fails don't delete the row.
                    // We don't want it stuck for all eternity.
                    print("Error: \(error.localizedDescription)")
                    if FileManager.default.fileExists(atPath: path.path) {
                        print("still exists")
                    } else {
                        print("File does not exist")
                        DatabaseController.getContext().delete(pending[indexPath.item])
                        DatabaseController.saveContext()
                        pending.remove(at: indexPath.item)
                        
                        let numberOfSection = calculateNumberOfSections(pending, classifiers)
                        // If there is only one section just delete it.
                        if pending.count <= 0 && numberOfSection == 1 {
                            tableView.beginUpdates()
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                            tableView.deleteSections([0], with: .automatic)
                            tableView.endUpdates()
                            tableView.setEditing(false, animated: false)
                        }
                            // If there is more than one section (i.e. 2). delete the first one and move the second one to the first
                        else if pending.count <= 0 && numberOfSection > 1 {
                            tableView.beginUpdates()
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                            tableView.deleteSections([0], with: .automatic)
                            tableView.moveSection(1, toSection: 0)
                            tableView.endUpdates()
                            tableView.setEditing(false, animated: false)
                        }
                            // If we still have pending models we can delete it no issue.
                        else {
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    }
                }
            } else {
                classifiers[indexPath.item].delete()
                
                // Don't worry about deleting these right away.
                classifiers.remove(at: indexPath.item)
                
                let numberOfSection = calculateNumberOfSections(pending, classifiers)
                
                if classifiers.count <= 0 {
                    tableView.beginUpdates()
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.deleteSections([numberOfSection], with: .automatic)
                    tableView.endUpdates()
                    tableView.setEditing(false, animated: false)
                } else {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        }
    }
}
