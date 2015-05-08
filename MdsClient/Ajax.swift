//
//  Ajax.swift
//
//  Created by Evgeniy Pozdnyakov on 2015-04-25.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import Foundation

class Ajax: NSObject {
    static let errorDomain = "Ajax"

    enum ErrorCode : Int {
        case NoResponseFromServer = 1
        case UnexpectedResponseCode = 2
        case CantMakeNSURLFromString = 3
        case CantCastJSONToArray = 4
        case CantCastJSONToDictionary = 5
    }

    var downloadTask: NSURLSessionDownloadTask?
    var localURL: NSURL?

    var progressHandler: ( (Int64, Int64)->Void )?
    var completionHandler: ( Void->Void )?
    var failureHandler: ( NSError->Void )?

    /**
        Creates NSURLSessionDataTask which sends http get request to url
        and passes the response to success handler

        **Warning:** Static method.

        Usage:

            Ajax.get(url: url,
                    success: { data in
                        // success code
                    },
                    fail: { error in
                        // failure code
                    })

        :param: url: NSURL The url to send http request.
        :param: success: NSData->Void  The handler to perform (with response data as parameter) if server returns status 200.
        :param: fail: NSError->Void The code to perform in case of any error.

        :returns: NSURLSessionDataTask
    */
    static func get(#url: NSURL,
                    success: NSData->Void,
                    fail: NSError->Void)
                    -> NSURLSessionDataTask {
        // println("call Ajax.get() with url: \(url)")
        let session = NSURLSession.sharedSession()
        let dataTask = session.dataTaskWithURL(url) { data, response, error in
            // println("Ajax.get callback for url: \(url)")
            if let error = error {
                if error.code == -999 {
                    // task cancelled
                    return
                }

                // The operation couldn’t be completed. (kCFErrorDomainCFNetwork error -1003.)
                // It happens when URL is unreachable
                self.throwError(error, withMessage: "Probably the URL [\(url)] is unreachable.", callFailureHandler: fail)
                return
            }

            let httpResponse = response as? NSHTTPURLResponse

            if httpResponse == nil || httpResponse!.statusCode == 500 {
                // Server didn't return any response
                self.throwError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)
                return
            }

            if httpResponse!.statusCode != 200 {
                // erver response code != 200
                self.throwError(.UnexpectedResponseCode, withMessage: "Unexpected response code: \(httpResponse!.statusCode).", callFailureHandler: fail)
                return
            }

            success(data)
        }

        dataTask.resume()

        return dataTask
}

    /**
        Shorthand for Ajax.get(), but it proceeds only if was able to create url from string passed.

        **Warning:** Static method.

        Usage:

            Ajax.getJsonByUrlString("http://bumagi.net/ios/mds/?q=abc",
                                    success: { data in
                                        // success code
                                    },
                                    fail: { error in
                                        // failure code
                                    })

        :param: urlString: String String representing remote URL.
        :param: success: NSData->Void The handler to perform (with response data as parameter) if server returns status 200.
        :param: fail: NSError->Void The code to perform in case of any error.

        :returns: NSURLSessionDataTask?
    */
    static func getJsonByUrlString(urlString: String,
                                    success: NSData->Void,
                                    fail: NSError->Void)
                                    -> NSURLSessionDataTask? {
        // println("call getJsonByUrlString with urlString: \(urlString)")
        if let url = NSURL(string:urlString) {
            // println("url is correct")

            let dataTask = Ajax.get(url: url, success: success, fail: fail)

            return dataTask
        }
        else {
            throwError(.CantMakeNSURLFromString, withMessage: "Can't make NSURL from string [\(urlString)]", callFailureHandler: fail)
        }

        return nil
    }

    /**
        Transforms json passed in nsdata format into [AnyObject] array.

        **Warning:** Static method.

        Usage:

            var error: NSError?
            if let json = Ajax.parseJsonArray(data, error: &error) {
                // use json
            }
            else if let error = error {
                // report error
            }

        :param: data: NSData JSON in NSData format.
        :param: error: NSErrorPointer Pointer to NSError object.

        :returns: [AnyObject]?
    */
    static func parseJsonArray(data: NSData,
                                error errorPointer: NSErrorPointer)
                                -> [AnyObject]? {
        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: errorPointer) as? [AnyObject] {
            return json
        }

        if let error = errorPointer.memory {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            throwError(error, withMessage: "JSON text did not start with array or object", callFailureHandler: nil)
        }
        else {
            // Error: JSON could be parsed, but it can't be casted to [AnyObject] format
            errorPointer.memory = NSError(domain: errorDomain, code: ErrorCode.CantCastJSONToArray.rawValue, userInfo: nil)
            throwError(errorPointer.memory!, withMessage: "JSON could be parsed, but can't be casted to [AnyObject]?", callFailureHandler: nil)
        }

        return nil
    }

    /**
        Transforms json passed in nsdata format into [String: AnyObject] dictionary.

        **Warning:** Static method.

        Usage:

            var error: NSError?
            if let json = Ajax.parseJsonDictionary(data, error: &error) {
                // use json
            }
            else if let error = error {
                // report error
            }


        :param: data: NSData JSON in NSData format
        :param: error: NSErrorPointer Pointer to NSError object.

        :returns: [String: AnyObject]?
    */
    static func parseJsonDictionary(data: NSData,
                                    error errorPointer: NSErrorPointer)
                                    -> [String: AnyObject]? {

        if let json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: errorPointer) as? [String: AnyObject] {
            return json
        }

        if let error = errorPointer.memory {
            // Cocoa error 3840: JSON text did not start with array or object and option to allow fragments not set
            throwError(error, withMessage: "JSON text did not start with array or object", callFailureHandler: nil)
        }
        else {
            // Error: JSON could be parsed, but it can be casted to [String: AnyObject] format
            errorPointer.memory = NSError(domain: errorDomain, code: ErrorCode.CantCastJSONToDictionary.rawValue, userInfo: nil)
            throwError(errorPointer.memory!, withMessage: "JSON could be parsed, but can't be casted to [String: AnyObject]?", callFailureHandler: nil)
        }


        return nil
    }

    /**
        Will download file from remote and save it locally.
        It will call progress handler periodically while downloading.
        It will call completion handler once when download complete.

        **Warning:** Static method, works asyncronously.

        Usage:

            Ajax.downloadFileFromUrl(remoteURL, saveTo: localURL,
                reportingProgress: { bytesWritten, bytesTotal in
                    // progress code
                },
                reportingCompletion: {
                    // success code
                },
                reportingFailure: { error in
                    // failure code
                })

        :param: remoteURL: NSURL
        :param: saveTo:    NSURL
        :param: reportingProgress:  (Int64, Int64)->Void
        :param: reportingCompletion: Void->Void
        :param: reportingFailure:    NSError->Void

        :returns: NSURLSessionDownloadTask
    */
    static func downloadFileFromUrl(remoteURL: NSURL, saveTo localURL: NSURL,
                                    reportingProgress progressHandler: (Int64, Int64)->Void,
                                    reportingCompletion completionHandler: Void->Void,
                                    reportingFailure failureHandler: NSError->Void)
                                    -> NSURLSessionDownloadTask {
        // println("call downloadFileFromUrl(), url: \(remoteURL), save to: \(localURL)")
        let ajax = Ajax()
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration, delegate: ajax, delegateQueue: nil)
        let downloadTask = session.downloadTaskWithURL(remoteURL)

        ajax.downloadTask = downloadTask
        ajax.localURL = localURL
        ajax.progressHandler = progressHandler
        ajax.completionHandler = completionHandler
        ajax.failureHandler = failureHandler

        downloadTask.resume()
        // println("task \(downloadTask) resumed")

        return downloadTask
    }

    // MARK: helpers

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            throwError(.NoResponseFromServer, withMessage: "Server didn't return any response.", callFailureHandler: fail)

        :param: code: ErrorCode Error code.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failutre handler.
    */
    static func throwError(code: ErrorCode,
                            withMessage message: String,
                            callFailureHandler failureHandler: ( NSError->Void )? ) {

        let error = NSError(domain: errorDomain, code: code.rawValue, userInfo: nil)

        throwError(error, withMessage: message, callFailureHandler: failureHandler)
    }

    /**
        Will create error:NSError and call generic function logError()

        **Warning:** Static method.

        Usage:

            throwError(error, withMessage: "Server didn't return any response.") { error in
                // failure code
            }

        :param: error: NSError The error.
        :param: message: String Error description.
        :param: failureHandler: ( NSError->Void )? Failure handler.
    */
    static func throwError(error: NSError,
                            withMessage message: String,
                            callFailureHandler failureHandler: ( NSError->Void )? ) {

        logError(error, withMessage: message)

        if let failureHandler = failureHandler {
            failureHandler(error)
        }
    }
}

extension Ajax: NSURLSessionDownloadDelegate {
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        assert(localURL != nil)
        assert(self.downloadTask != nil)
        assert(completionHandler != nil)

        // println("file saved at \(location)")

        if downloadTask == self.downloadTask {
            let fileManager = NSFileManager.defaultManager()
            var error: NSError?

            fileManager.moveItemAtURL(location, toURL: localURL!, error: &error)

            if let error = error {
                logError(error, withMessage: "Can't move file to [\(localURL)].")
                if let failureHandler = failureHandler {
                    failureHandler(error)
                }
            }

            if let completionHandler = completionHandler {
                completionHandler()
            }
        }
    }

    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        assert(progressHandler != nil)
        assert(self.downloadTask != nil)

        if downloadTask == self.downloadTask {
            if let progressHandler = progressHandler {
                progressHandler(totalBytesWritten, totalBytesExpectedToWrite)
            }
        }
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let error = error {
            Ajax.throwError(error, withMessage: "NSURLSessionDownloadTask error.", callFailureHandler: failureHandler)
        }
    }
}