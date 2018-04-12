//
//  Classifier.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 7/17/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import Foundation
import Alamofire

struct Classifier {
    enum Status: String {
        case ready, training, retraining, failed
    }
    
    static let BASE_URL = "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers"
    
    let name: String
    let classes: [String]
    let classifierId: String
    let created: Date
    let status: Status
    let explanation: String
}

extension Classifier {

    init(name: String) {
        self.name = name
        self.classes = [String]()
        self.classifierId = String()
        self.created = Date()
        self.status = .ready
        self.explanation = String()
    }
    
    init?(json: Any) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let json = json as? [String: Any],
            let name = json["name"] as? String,
            let classesArray = json["classes"] as? [Any],
            let classifierId = json["classifier_id"] as? String,
            let created = json["created"] as? String,
            let date = dateFormatter.date(from: created),
            let statusString = json["status"] as? String,
            let status = Status(rawValue: statusString)
            else {
                return nil
        }
        
        let explanation = json["explanation"] as? String ?? String()
        
        var classes = [String]()
        for classJSON in classesArray {
            guard let classJSON = classJSON as? [String: Any],
                let classItem = classJSON["class"] as? String
                else {
                    return nil
            }
            classes.append(classItem)
        }
        
        self.name = name
        self.classes = classes
        self.classifierId = classifierId
        self.created = date
        self.status = status
        self.explanation = explanation
    }
    
    func delete() {
        guard let path = Bundle.main.path(forResource: "Keys", ofType: "plist") else {
            return
        }
        
        guard let apiKey = NSDictionary(contentsOfFile: path)?["API_KEY"] else {
            return
        }
        
        let url = "\(Classifier.BASE_URL)/\(classifierId)"
    
        let params: Parameters = [
            "api_key": apiKey,
            "version": "2016-05-20",
            ]
        
        Alamofire.request(url, method: .delete, parameters: params).responseData { response in
            switch response.result {
            case .success:
                break
            case .failure(let error):
                print(error)
            }
        }
    }
    
    static func buildClassifier(fromId classifierId: String, completion: @escaping (_ results: Classifier) -> Void, error: @escaping () -> Void) {
        guard let path = Bundle.main.path(forResource: "Keys", ofType: "plist") else {
            error()
            return
        }
        
        guard let apiKey = NSDictionary(contentsOfFile: path)?["API_KEY"] else {
            error()
            return
        }
        
        let url = "\(Classifier.BASE_URL)/\(classifierId)"
        
        let params = [
            "api_key": apiKey,
            "version": "2016-05-20",
            "verbose": "true"
        ]
        
        Alamofire.request(url, parameters: params).validate().responseJSON { response in
            switch response.result {
            case .success:
                guard let json = response.result.value as? [String : Any] else {
                    error()
                    return
                }
                
                guard let classifier = Classifier(json: json) else {
                    error()
                    return
                }
                
                completion(classifier)
                
            case .failure:
                error()
                return
            }
        }
    }
    
    static func buildList(completion: @escaping (_ results: [Classifier]) -> Void, error: @escaping () -> Void) {
        guard let path = Bundle.main.path(forResource: "Keys", ofType: "plist") else {
            error()
            return
        }

        guard let apiKey = NSDictionary(contentsOfFile: path)?["API_KEY"] else {
            error()
            return
        }
        
        let params = [
            "api_key": apiKey,
            "version": "2016-05-20",
            "verbose": "true"
        ]
        
        Alamofire.request(BASE_URL, parameters: params).validate().responseJSON { response in
            switch response.result {
            case .success:
                guard let json = response.result.value as? [String : Any] else {
                    error()
                    return
                }
                
                guard let classifiersJSON = json["classifiers"] as? [Any] else {
                    error()
                    return
                }
                
                completion(
                    classifiersJSON.flatMap { (classifierJSON: Any) -> Classifier? in
                        guard let classifier = Classifier(json: classifierJSON) else {
                            error()
                            return nil
                        }
                        return classifier
                    }.sorted(by: { $0.created > $1.created })
                )
                
            case .failure:
                error()
                return
            }
        }
    }
    
    func isEqual(_ object: Classifier) -> Bool {
        // Status might be something we want to check... don't know.
        return classifierId == object.classifierId && name == object.name
    }
    
    static var defaults = [Classifier(name: "Default"), Classifier(name: "Food"), Classifier(name: "Face Detection")]
}
