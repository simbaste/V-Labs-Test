//
//  Comment.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 14/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import Foundation

class Comment {
    var title: Int
    var body: String
    var userId: String
    
    // MARK: - FlatMap Event -> JSON
    init?(dictionary: AnyDict) {
        guard let m_title = dictionary["title"] as? Int,
            let m_body = dictionary["body"] as? String,
            let m_userId = dictionary["userId"] as? String
            else {
                return nil
        }
        
        title = m_title
        body = m_body
        userId = m_userId
    }
    
    // MARK: - Event -> JSON
    var dictionary: AnyDict {
        return [
            "title": title,
            "body" : body,
            "userId": userId
        ]
    }
}
