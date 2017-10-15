//
//  Photo.swift
//  V-Labs-Test
//
//  Created by Stephane Darcy SIMO MBA on 13/10/2017.
//  Copyright © 2017 v-Labs. All rights reserved.
//

import UIKit

class Photo {
    var id: Int
    var title: String
    var thumbnailUrl: String
    
    // MARK: - FlatMap Event -> JSON
    init?(dictionary: AnyDict) {
        guard let m_id = dictionary["id"] as? Int,
            let m_title = dictionary["title"] as? String,
            let m_thumbnailUrl = dictionary["thumbnailUrl"] as? String
            else {
                return nil
        }
        
        id = m_id
        title = m_title
        thumbnailUrl = m_thumbnailUrl
    }
    
    // MARK: - Event -> JSON
    var dictionary: AnyDict {
        return [
            "id": id,
            "title" : title,
            "thumbnailUrl": thumbnailUrl
        ]
    }
}
