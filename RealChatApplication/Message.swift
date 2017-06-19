//
//  Message.swift
//  RealChatApplication
//
//  Created by 규송 문 on 2017. 6. 8..
//  Copyright © 2017년 규송 문. All rights reserved.
//

import UIKit
import Firebase
class Message: NSObject {

    var fromId: String?
    var text: String?
    var timestamp: NSNumber?
    var toId: String?
    var imageUrl: String?
    var imageWidth: NSNumber?
    var imageHeight: NSNumber?
    
    init(_ dictionary: [String: Any]) {
        self.fromId = dictionary["fromId"] as? String
        self.text = dictionary["text"] as? String
        self.toId = dictionary["toId"] as? String
        self.timestamp = dictionary["timestamp"] as? NSNumber
        
        imageUrl = dictionary["imageUrl"] as? String
        imageHeight = dictionary["imageHeight"] as? NSNumber
        imageWidth = dictionary["imageWidth"] as? NSNumber
    }
    
    func checkPartnerId() -> String? {
        let chatPartnerId: String?
        
        if fromId == FIRAuth.auth()?.currentUser?.uid {
            return toId
        } else {
            return fromId
        }
    }
    
}
