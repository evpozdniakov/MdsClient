struct Ajax {

    /**
        Creates NSURLSessionDataTask which sends http get request to url
        and passes the response to success handler

        **Warning:** The fail handler not implemented.

        Usage:

            Ajax.get(url) { data in <some code> }

        :param: url The url to send http request.
        :param: success The handler to perform (with response data as parameter) if server returns status 200.

        :returns: NSURLSessionDataTask
    */
    static func get(#url: NSURL, success: (data: NSData) -> ()) -> NSURLSessionDataTask {
        let session = NSURLSession.sharedSession()
        let dataTask = session.dataTaskWithURL(url) {data, response, error in
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
                // #FIXME: add optional faill handler and call it with error
                println("ajax-error-no-response")
                return
            }
            
            if httpResponse!.statusCode != 200 {
                // erver response code != 200
                // #FIXME: add optional faill handler and call it with error
                println("ajax-error-unexpected-response-code: \(httpResponse!.statusCode)")
                return
            }
            
            success(data: data)
        }

        dataTask.resume()

        return dataTask
    }

    // #MARK: - get JSON

    /**
        Shorthand for Ajax.get(), but it proceeds only if was able to create url from string passed.

        **Warning:** The fail handler not implemented.

        Usage:

            Ajax.getJsonByUrlString("http://bumagi.net/ios/mds/?q=abc")

        :param: urlString
        :param: success The success handler.

        :returns: NSURLSessionDataTask?
    */
    static func getJsonByUrlString(urlString: String, success: (NSData) -> Void) -> NSURLSessionDataTask? {
        if let url = NSURL(string:urlString) {
            let dataTask = Ajax.get(url: url, success: success)

            return dataTask
        }
        else {
            // #FIXME: add fail handler and return error back
        }

        return nil
    }

    /**
        Transforms json passed in nsdata format into [AnyObject] array.

        **Warning:** The errors not handled.

        Usage:

            Ajax.parseJsonArray(data)

        :param: data JSON in NSData format.

        :returns: optional array [AnyObject].
    */
    static func parseJsonArray(data: NSData) -> [AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [AnyObject] {
            return json
        }
        
        if let error = error {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            // #FIXME: handle the error
            println("data-model-error-1001: \(error)")
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [AnyObject] format
            // #FIXME: handle the error
            println("data-model-error-1002")
        }

        return nil
    }

    /**
        Transforms json passed in nsdata format into [String: AnyObject] dictionary.

        **Warning:** The errors not handled.

        Usage:

            Ajax.parseJsonDictionary(data)

        :param: data JSON in NSData format

        :returns: [String: AnyObject]?
    */
    static func parseJsonDictionary(data: NSData) -> [String: AnyObject]? {
        var error: NSError?
        
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error) as? [String: AnyObject] {
            return json
        }
        
        if let error = error {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            // #FIXME: handle the error
            println("data-model-error-1003: \(error)")
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [String: AnyObject] format
            // #FIXME: handle the error
            println("data-model-error-1004")
        }

        return nil
    }
}