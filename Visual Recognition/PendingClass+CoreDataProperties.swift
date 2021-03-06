//
//  PendingClass+CoreDataProperties.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 5/9/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import Foundation
import CoreData


extension PendingClass {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingClass> {
        return NSFetchRequest<PendingClass>(entityName: "PendingClass")
    }

    @NSManaged public var name: String?
    @NSManaged public var id: String?
    @NSManaged public var created: Date?
    @NSManaged public var locked: NSNumber?
    var isLocked: Bool {
        get {
            return Bool(locked ?? false)
        }
        set {
            locked = NSNumber(value: newValue)
        }
    }
}
