//
//  BrewletTests.swift
//  BrewletTests
//
//  Created by Colton Padden on 5/17/20.
//  Copyright © 2020 zzada. All rights reserved.
//

// TODO - mock "run_command"

import XCTest

@testable import Brewlet

class BrewletTests: XCTestCase {
    
    /// App delegate where functions with side-effects have been removed
    class StatelessAppDelegate : AppDelegate {
        
        /// `run_command` where `brew` is not actually invoked
        override func run_command(arguments: [String], fileRedirect: FileHandle? = nil, outputHandler: @escaping (Process, Data) -> Void) {
            NSLog("overridden `run_command`")
        }
    
    }

    // Create placeholder of application delegate
    var delegate: AppDelegate!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        delegate = StatelessAppDelegate() as! AppDelegate
        
        // Re-initialize defaults instead of triggering `applicationDidFinishLaunching`
        delegate.statusItem.button?.toolTip = "Brewlet"
        delegate.statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        delegate = nil
    }
    
    func testFormatDate() {
        let d = Date(timeIntervalSinceReferenceDate: 410220000)
        let f = delegate.formatDate(date: d)
        XCTAssert(f == "Dec 31, 2013 at 5:00 PM")
    }
    
    func testAnimateIconImages() {
        let animateTimer = delegate.animateIcon()
        
        // Status button image name initial value
        XCTAssert(delegate.statusItem.button?.image?.name() == "BrewletIcon-Black")
        
        // Trigger the timer 7 times, the status icon name will increment from "Brewlet-Filled-0" to "Brewlet-Filled-6"
        for n in 0...6 {
            animateTimer.fire()
            let statusImageName = (delegate.statusItem.button?.image?.name())!
            NSLog("Status Image: \(statusImageName)")
            XCTAssert("Brewlet-Filled-\(n)" == statusImageName)
        }
    }
    
    /// Ensure user defaults is updated to desired interval value
    func testUpdateIntervalChanges() {
        delegate.updateIntervalChanged(newInterval: 3000)
        let v0 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v0 == 3000)
        
        delegate.updateIntervalChanged(newInterval: 3600)
        let v1 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v1 == 3600)
    }
    
    // NOTE: this does not work, as the overriden `run_command` will not trigger the
    // self.userDefaults.set(turnOn, forKey: "shareAnalytics") in `toggle_analytics`
//    /// Toggle share analytics in preferences - `brew` command is not invoked as  delegate method `run_command` has been overriden
//    func testShareAnalyticsChanged() {
//        delegate.shareAnalyticsChanged(newState: .on)
//        let v0 = delegate.userDefaults.bool(forKey: "shareAnalytics")
//        XCTAssert(v0 == true)
//
//        delegate.shareAnalyticsChanged(newState: .off)
//        let v1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
//        XCTAssert(v1 == false)
//    }

//    func testToggleAnalytics() {
//
//        // NOTE: this will actually set the analytics setting for homebrew, we should figure out how
//        // to mock this functionality.
//
//        delegate.toggle_analytics(turnOn: true)
//        let s1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
//        NSLog("shareAnalytics: %d", s1)
//        XCTAssert(s1 == true)
//
//        delegate.toggle_analytics(turnOn: false)
//        let s2 = delegate.userDefaults.bool(forKey: "shareAnalytics")
//        NSLog("shareAnalytics: %d", s2)
//        XCTAssert(s2 == false)
//    }
}
