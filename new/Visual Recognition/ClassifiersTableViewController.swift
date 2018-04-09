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
//    override var preferredStatusBarStyle: UIStatusBarStyle {
//        return .default
//    }
    
    let VISION_API_KEY = "4ef2b4c252cbaa92235bd7724d15a9962f59cf85"
    
    var pending = [PendingClassifier]()
    var classifiers = [Classifier]()
    
    var pendingClassifier = PendingClassifier()
    var pendingClass = PendingClass()
    
    weak var AddAlertSaveAction: UIAlertAction?
    
    @IBAction func createClassifier() {
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
        
        self.pendingClassifier = pendingClassifier
        self.pendingClass = pendingClass
        
        DatabaseController.saveContext()
        
        self.performSegue(withIdentifier: "showSnapperFromScratch", sender: nil)
    }
    
//    WHAT THE FUCK DOES THIS DO? I DON'T REMEMBER WRITING THIS...
    func handleTextDidChange(_ sender:UITextField) {
        // Enforce a minimum length of >= 1 for secure text alerts.
        AddAlertSaveAction!.isEnabled = (sender.text?.utf16.count)! >= 1
    }
    
    var isLoading = false
    func loadClassifiers() {
        print("prepare to load")
        // Load from Watson
        let apiKey = UserDefaults.standard.string(forKey: "api_key")

        if apiKey == nil || apiKey == "" {
            classifiers = []
            // This should be okay.
            tableView.reloadData()
            refreshControl?.endRefreshing()
            return
        }

        let url = "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers"
        let params = [
            "api_key": apiKey!,
            "version": "2016-05-20",
            "verbose": "true"
        ]
        if isLoading {
            return
        }
        print("loading from server")
        isLoading = true
        Alamofire.request(url, parameters: params).validate().responseJSON { [weak self] response in
            guard let `self` = self else { return }
            self.isLoading = false
            print("done")
            self.refreshControl?.endRefreshing()
            switch response.result {
            case .success:
                if let json = response.result.value as? [String : Any] {
                    if let classifiersJSON = json["classifiers"] as? [Any] {

                        // Build classifiers from json.
                        var classifiers = [Classifier]()
                        for classifierJSON in classifiersJSON {
                            let classifier = Classifier(json: classifierJSON)!
                            classifiers.append(classifier)
                        }

                        classifiers = classifiers.sorted(by: { $0.created > $1.created })

                        // Instead of blindly reloading the entire list, we should reload/insert/remove row.
                        var indexesToAdd = [IndexPath]()
                        for classifier in classifiers {
                            if !self.classifiers.contains(where: { $0.isEqual(classifier) }) {
                                print("inserting row \(indexesToAdd.count): \(classifier.name)")
                                indexesToAdd.append(IndexPath(row: indexesToAdd.count, section: self.tableView.numberOfSections - 1))
                            }
                        }

                        var indexesToDelete = [IndexPath]()
                        for classifier in self.classifiers {
                            if !classifiers.contains(where: { $0.isEqual(classifier)}) {
                                let itemToDelete = self.classifiers.index(where: {$0.classifierId == classifier.classifierId})!
                                print("removing row \(itemToDelete): \(classifier.name)")
                                indexesToDelete.append(IndexPath(row: itemToDelete, section: self.tableView.numberOfSections - 1))
                            }
                        }

                        var indexesToUpdate = [IndexPath]()
                        for classifier in self.classifiers {
                            // If the new classifier matches one of the old classifiers, but the status is different.
                            if classifiers.contains(where: { $0.isEqual(classifier) && $0.status != classifier.status}) {
                                let itemToUpdate = self.classifiers.index(where: {$0.classifierId == classifier.classifierId})!
                                print("reloading row \(itemToUpdate): \(classifier.name)")
                                indexesToUpdate.append(IndexPath(row: itemToUpdate, section: self.tableView.numberOfSections - 1))
                            }
                        }

                        self.classifiers = classifiers
                        self.tableView.beginUpdates()
                        self.tableView.insertRows(at: indexesToAdd, with: .automatic)
                        self.tableView.deleteRows(at: indexesToDelete, with: .automatic)
                        self.tableView.reloadRows(at: indexesToUpdate, with: .automatic)
                        self.tableView.endUpdates()

                        // After we update our table, check if anything is still training.
                        let training = self.classifiers.filter({ $0.status == .training || $0.status == .training })
                        if training.count > 0 {
                            // If things are still training recheck in 4 seconds.
                            self.reloadClassifiers()
                        }
                    }
                }
            case .failure(let error):
                print(error)
            }
        }
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

        do {
            let searchResults = try DatabaseController.getContext().fetch(fetchRequest)
            pending = []
            for result in searchResults as [PendingClassifier] {
                pending.append(result)
            }

            let epoch = Date().addingTimeInterval(0 - Date().timeIntervalSince1970)
            pending = pending.sorted(by: { $0.created ?? epoch > $1.created ?? epoch })
        }
        catch {
            print("Error: \(error)")
        }
        tableView.reloadData()
        loadClassifiers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl?.addTarget(self, action: #selector(self.loadClassifiers), for: .valueChanged)
        
        tableView.estimatedRowHeight = 85.0
        tableView.rowHeight = UITableViewAutomaticDimension
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if pending.count <= 0 && classifiers.count <= 0 {
            return 0
        }
        if pending.count <= 0 || classifiers.count <= 0 {
            return 1
        }
        return 2
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell2", for: indexPath) as! ClassiferTableViewCell
            
            let classifierData = classifiers[indexPath.item]
            
            cell.classifierNameLabel?.text = classifierData.name
            cell.classifierIdLabel?.text = classifierData.classifierId
            
            switch classifierData.status {
            case .ready:
                cell.classifierStatusEmoji?.text = ""
            case .training, .retraining:
                cell.classifierStatusEmoji?.text = "😴"
                cell.classifierIdLabel?.text = classifierData.status.rawValue
            case .failed:
                cell.classifierStatusEmoji?.text = "😭"
                cell.classifierIdLabel?.text = "Verify there are at least 10 images per class."
            }
            
            if classifierData.status == .ready {
                cell.classifierNameLabel?.alpha = 1.0
                cell.classifierIdLabel?.alpha = 1.0
                cell.activityIndicator?.stopAnimating()
                cell.activityIndicator?.isHidden = true
            } else if classifierData.status == .training || classifierData.status == .retraining {
                cell.classifierNameLabel?.alpha = 0.4
                cell.classifierIdLabel?.alpha = 0.4
                cell.activityIndicator?.startAnimating()
                cell.activityIndicator?.isHidden = false
            } else {
                cell.classifierNameLabel?.alpha = 0.4
                cell.classifierIdLabel?.alpha = 0.4
                cell.activityIndicator?.stopAnimating()
                cell.activityIndicator?.isHidden = true
            }
            
            if classifierData.classifierId == String() && classifierData.name == "Loading..." {
                cell.activityIndicator?.startAnimating()
                cell.activityIndicator?.isHidden = false
                
                cell.classifierNameLabel?.text = String()
                cell.classifierIdLabel?.text = "Loading..."
            }
            
            cell.checkmark?.isHidden = true
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.pendingClassifier = pending[indexPath.row]
        
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "newClassifier", sender: nil)
        }
    }
    
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
                    if (pending.count <= 0) {
                        tableView.beginUpdates()
                        tableView.deleteSections([0], with: .automatic)
                        tableView.moveSection(1, toSection: 0)
                        tableView.endUpdates()
                        tableView.setEditing(false, animated: false)
                    } else {
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
                        if (pending.count <= 0) {
                            tableView.beginUpdates()
                            tableView.deleteSections([0], with: .automatic)
                            tableView.moveSection(1, toSection: 0)
                            tableView.endUpdates()
                            tableView.setEditing(false, animated: false)
                        } else {
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                    }
                }
            } else {
                let url = URL(string: "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers/\(classifiers[indexPath.item].classifierId)")!
                
                let parameters: Parameters = [
                    "api_key": UserDefaults.standard.string(forKey: "api_key")!,
                    "version": "2016-05-20",
                    ]
                
                Alamofire.request(url, method: .delete, parameters: parameters).responseData { response in
                    switch response.result {
                    case .success:
                        break
                    case .failure(let error):
                        print(error)
                    }
                }
                
                // Don't worry about deleting these right away.
                classifiers.remove(at: indexPath.item)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    @IBAction func unwindToClassifiers(segue: UIStoryboardSegue) {
        // Unwind
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "newClassifier",
            let destination = segue.destination as? ClassesViewController {
            destination.classifier = pendingClassifier
        }
        
        if  segue.identifier == "showSnapperFromScratch",
            let destination = segue.destination as? SnapperViewController {
            destination.pendingClass = pendingClass
            destination.classifier = pendingClassifier
        }
    }
}
