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

        throwErrorMessage("Message text", withHandler: nil, inViewController: self)
*/
func throwErrorMessage(message: String, inViewController viewCtlr: UIViewController, withHandler handler: (Void -> Void)?) {
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

// do-nothing function
func noop(_: AnyObject...) {}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var dataModel: DataModel?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        dataModel = DataModel()

        if let window = window {
            if let tabBarCtlr = window.rootViewController as? UITabBarController {
                if let viewControllers = tabBarCtlr.viewControllers {
                    if let searchCatalog = viewControllers[0] as? SearchCatalog,
                        playlist = viewControllers[1] as? Playlist {

                        searchCatalog.dataModel = dataModel
                        playlist.dataModel = dataModel
                    }
                }
            }
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        dataModel?.storeRecords()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        dataModel?.storeRecords()
    }
}

