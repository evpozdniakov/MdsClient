//
//  Record.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-17.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import Foundation

struct RecordSource {
    var domain: String
    var url: NSURL
    
    init(domain: String, url: NSURL) {
        self.domain = domain
        self.url = url
    }
}

class Record {
    var author: String
    var title: String
    var sources: [RecordSource]?
    
    init(author: String, title: String, sources: [AnyObject]) {
        self.author = author
        self.title = title
    	self.sources = [RecordSource]()

        for source in sources {
	        if let source = source as? [String: AnyObject] {
                if let domain = source["domain"] as? String {
                    if let urlString = source["url"] as? String {
                        if let url = NSURL(string: urlString) {
                            self.sources?.append(RecordSource(domain: domain, url: url))
                        }
                    }
                }
	        }
        }
    }
}