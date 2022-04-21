//
//  AppDelegate.swift
//  YHDownloadDemo
//
//  Created by XiaoBai on 2022/4/9.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        YHDownloadTool.shared.enableBreakPointDownload = true
        YHDownloadTool.shared.enableBackgroundDownload = true
        return true
    }


}

