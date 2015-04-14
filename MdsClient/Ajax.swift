//
//  Ajax.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-11.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

struct Ajax {
    static func get(#url: NSURL, success: (data: NSData) -> ()) -> NSURLSessionDataTask {
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

        return dataTask
    }

    // parse json nsdata as array
    static func parseJsonArray(data: NSData) -> [AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [AnyObject] {
            return json
        }
        
        if let error = error {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            println("data-model-error-1001: \(error)")
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [AnyObject] format
            println("data-model-error-1002")
        }

        return nil
    }

    // parse json nsdata as dictionary
    static func parseJsonDictionary(data: NSData) -> [String: AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [String: AnyObject] {
            return json
        }
        
        if let error = error {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            println("data-model-error-1003: \(error)")
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [String: AnyObject] format
            println("data-model-error-1004")
        }

        return nil
    }
}