//
//  AppDelegate.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-15.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

/*

    TODO:
        *** after each task find and implement one todo or fixme or write swift doc to any function ***
        [x] make downloaded files playable
        [x] fix issue: displaying progress for downloaded tracks
        [x] fix issue: activity indicator while switching from one track to another
        [x] stop playing record if it was removed from list
        [x] remove buttons play/pause/activityIndicator from search tab
        [x] display all records in search
        [ ] make filter from search, filter records while typing
        [ ] group records by year
        [ ] block/unblock UI while downloading catalog
        [ ] remember record current time


    FIXME:
        - ищем "погоня за учителем", кликаем заголовок, переключаемся в плейлист, ждем "!", возвращаемся в поиск и видим кнопку play, кликаем еще раз заголовок - кнопка play пропадает

*/

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        // Restore DataModel state and data from DataModel.plist
        DataModel.restore()

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        DataModel.store()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        DataModel.store()
    }
}

// #MARK: global functions

// #TODO: detect current view controller in place and avoid passing it as parameter
/**
    Displays error custom message to the user as an alert.
    Calls handler when user closes alert dialog.

    Usage:

        appDisplayError("Message text", withHandler: nil, inViewController: self)

    :param: message: String Custom error message.
    :param: inViewController: UIViewController The controller which user sees.
*/
internal func appDisplayError(message: String,
                                inViewController viewCtlr: UIViewController,
                                withHandler handler: (Void -> Void)?) {
    let alert = UIAlertController(
        title: "Error!",
        message: message,
        preferredStyle: .Alert
    )

    let action = UIAlertAction(
        title: "OK",
        style: .Default,
        handler: { (alert: UIAlertAction!) in
            if let handler = handler {
                handler()
            }
        }
    )

    alert.addAction(action)
    viewCtlr.presentViewController(alert, animated: true, completion: nil)
}

/**
    Will log passed error (domain, code, message) and call failure handler if provided.

    **Warning:** If you don't have failure handler, use appLogError:withMessage:

    Usage:

        appLogError(err, withMessage: msg, callFailureHandler: failureHandler)

    :param: error: NSError The error.
    :param: withMessage: String Error custom message.
    :param: callFailureHandler: ( NSError->Void )? Failure handler.
*/
internal func appLogError(error: NSError,
                        withMessage message: String,
                        callFailureHandler failureHandler: ( NSError->Void )?) {

    appLogError(error, withMessage: message)

    if let failureHandler = failureHandler {
        failureHandler(error)
    }
}

/**
    Will log passed error (domain, code, message).

    Usage:

        appLogError(error, withMessage: "Error custom message.")

    :param: error: NSError The error.
    :param: withMessage: String Error custom message.
*/
internal func appLogError(error: NSError, withMessage message: String) {
    println(" ")
    println("ERROR [ \(error.domain): \(error.code) ]")
    println(message)
    println(" ")
}

/**
    Returns true if current thread is main, false othrewise.

    Usage:

        if !appIsMainThread() {
            // go to the main thread
        }
*/
internal func appIsMainThread() -> Bool {
    return NSThread.currentThread().isMainThread
}

/**
    Performs the handler in main thread. Switches to main thread only if needed.

    Usage:

        appMainThread() {
            // handler code
        }

    :param: handler: Void->Void
*/
internal func appMainThread(handler: Void->Void) {
    if appIsMainThread() {
        handler()
    }
    else {
        dispatch_async(dispatch_get_main_queue()) {
            handler()
        }
    }

}