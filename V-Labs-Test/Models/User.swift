//
//  User.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 11/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit
import ObjectMapper

typealias AnyDict = [String: Any]

class User {
    var id: Int
    var name: String
    var username: String
    
    // MARK: - FlatMap Event -> JSON
    init?(dictionary: AnyDict) {
        guard let m_id = dictionary["id"] as? Int,
            let m_name = dictionary["name"] as? String,
            let m_username = dictionary["username"] as? String
            else {
                return nil
        }
        
        id = m_id
        name = m_name
        username = m_username
    }
    
    // MARK: - Event -> JSON
    var dictionary: AnyDict {
        return [
            "id": id,
            "name" : name,
            "username": username
        ]
    }
}
