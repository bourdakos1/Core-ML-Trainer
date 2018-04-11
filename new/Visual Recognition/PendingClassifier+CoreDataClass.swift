//
//  PendingClassifier+CoreDataClass.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 5/9/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import Foundation
import CoreData
import Zip
import Alamofire

public class PendingClassifier: NSManagedObject {
    func train(completion: @escaping (_ results: Any) -> Void) {
        do {
            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(id!)
            
            var paths = [URL]()
            
            for result in relationship?.allObjects as! [PendingClass] {
                // Check if the class has any images to send.
                do {
                    // Get the directory contents urls (including subfolders urls)
                    let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl.appendingPathComponent(result.id!), includingPropertiesForKeys: nil, options: [])
                    
                    let jpgFiles = directoryContents.filter{ $0.pathExtension == "jpg" }
                    
                    if jpgFiles.count <= 0 {
                        break
                    }
                    
                } catch {
                    break
                }
                
                // If it does, start the zip process.
                let destination = documentsUrl.appendingPathComponent(result.name!).appendingPathExtension("zip")
                
                paths.append(destination)
                
                // Delete any old zips before reziping the new images.
                if FileManager.default.fileExists(atPath: destination.path) {
                    print("Exists, deleting")
                    // Exist so delete first and then try.
                    do {
                        try FileManager.default.removeItem(at: destination)
                    } catch {
                        print("Error: \(error.localizedDescription)")
                        if FileManager.default.fileExists(atPath: destination.path) {
                            print("still exists")
                        }
                        completion("FAILUREEEEE")
                        return
                    }
                }
                
                // Make sure it's actually gone...
                if !FileManager.default.fileExists(atPath: destination.path) {
                    do {
                        try Zip.zipFiles(paths: [documentsUrl.appendingPathComponent(result.id!)], zipFilePath: destination, password: nil, progress: { progress in
                            print("Zipping: \(progress)")
                        })
                    } catch {
                        completion("FAILUREEEEE")
                        return
                    }
                }
            }
            
            var url = URL(string: "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers")!
            
            if let path = classifierId {
                url.appendPathComponent(path)
            }
            
            print(url)
            
            let urlRequest = URLRequest(url: url)
            
            guard let path = Bundle.main.path(forResource: "Keys", ofType: "plist") else {
                completion("FAILUREEEEE")
                return
            }
            
            let parameters: Parameters = [
                "api_key": (NSDictionary(contentsOfFile: path)?["API_KEY"] as? String)!,
                "version": "2016-05-20",
                ]
            
            let encodedURLRequest = try URLEncoding.queryString.encode(urlRequest, with: parameters)
            
            Alamofire.upload(
                multipartFormData: { multipartFormData in
                    for path in paths {
                        multipartFormData.append(
                            path,
                            withName: "\((path.pathComponents.last! as NSString).deletingPathExtension)_positive_examples"
                        )
                    }
                    multipartFormData.append(self.name!.data(using: .utf8, allowLossyConversion: false)!, withName :"name")
            },
                to: encodedURLRequest.url!,
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseJSON { response in
                            debugPrint(response)
                            
                            if let response = response.response {
                                if !(200 ..< 300 ~= response.statusCode) {
                                    completion("FAILUREEEEE")
                                    return
                                }
                            }
                            
                            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            
                            let path = documentsUrl.appendingPathComponent(self.id!)
                            
                            do {
                                try FileManager.default.removeItem(at: path)
                                DatabaseController.getContext().delete(self)
                                DatabaseController.saveContext()
                            } catch {
                                // If it fails don't delete the row.
                                // We don't want it stuck for all eternity.
                                print("Error: \(error.localizedDescription)")
                                if FileManager.default.fileExists(atPath: path.path) {
                                    print("still exists")
                                } else {
                                    print("File does not exist")
                                    DatabaseController.getContext().delete(self)
                                    DatabaseController.saveContext()
                                }
                            }
                            completion(response)
                        }
                        upload.uploadProgress(closure: { //Get Progress
                            progress in
                            print(progress.fractionCompleted)
                        })
                    case .failure(let encodingError):
                        print(encodingError)
                        completion("FAILUREEEEE")
                    }
            })
        }
        catch {
            print(error)
            completion("FAILUREEEEE")
        }
    }
}
