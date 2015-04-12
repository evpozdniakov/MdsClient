//
//  Ajax.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-11.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

struct Ajax {
	static func get(#url: NSURL, success: (data: NSData) -> ()) {
		// println("Ajax.request called with url: \(url)")
		// success()

		let session = NSURLSession.sharedSession()
		let dataTask = session.dataTaskWithURL(url, completionHandler: {data, response, error in
		    if let error = error {
		        if error.code == -999 { return } // task cancelled

		        // The operation couldn’t be completed. (kCFErrorDomainCFNetwork error -1003.)
		        // It happens when URL is unreachable
		        println("ajax-error-task-cancelled: \(error)")
		        return
		    }

		    let httpResponse = response as? NSHTTPURLResponse

		    if httpResponse == nil || httpResponse!.statusCode == 500 {
		        // Server didn't return any response
		        println("ajax-error-no-response")
		        return
		    }
		    
		    if httpResponse!.statusCode != 200 {
		        // erver response code != 200
		        println("ajax-error-unexpected-response-code: \(httpResponse!.statusCode)")
		        return
		    }
		    
		    success(data: data)
		})

		dataTask.resume()
	}
}