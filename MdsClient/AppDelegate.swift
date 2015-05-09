//
//  AppDelegate.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-15.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit

/**
    Displays error message

    Usage:

        appDisplayError("Message text", withHandler: nil, inViewController: self)
*/
internal func appDisplayError(message: String, inViewController viewCtlr: UIViewController, withHandler handler: (Void -> Void)?) {
    let alert = UIAlertController(
        title: "Ошибка!",
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

internal func appLogError(error: NSError, withMessage message: String, callFailureHandler fail: ( NSError->Void )?) {
    appLogError(error, withMessage: message)
    if let fail = fail {
        fail(error)
    }
}

internal func appLogError(error: NSError, withMessage message: String) {
    println(" ")
    println("ERROR [ \(error.domain): \(error.code) ]")
    println(message)
    println(" ")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        DataModel.storeRecords()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        DataModel.storeRecords()
    }
}

