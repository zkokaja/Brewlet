//
//  BrewletTests.swift
//  BrewletTests
//
//  Created by Colton Padden on 5/17/20.
//  Copyright © 2020 zzada. All rights reserved.
//

import XCTest

@testable import Brewlet

class BrewletTests: XCTestCase {
    
    // Create placeholder of application delegate to be set in `setUp`
    var delegate: StatelessAppDelegate!
    
    /// App delegate where functions with side-effects have been removed
    class StatelessAppDelegate : AppDelegate {
        
        // allow unit tests to overwrite the stdout of the `run_command` closure
        var stdout: String = ""
        
        /// Modified to not run `brew` subprocess, and to use `stdout` property in closure
        override func run_command(
            arguments: [String],
            fileRedirect: FileHandle? = nil,
            outputHandler: @escaping (Process, Data) -> Void) {
            
            // Return parameters for closure
            outputHandler(Process(), self.stdout.data(using: .utf8)!)
        }
        
        /// Disable notifications in tests
        override func sendNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
            // pass
        }
        
    }
    
    override func setUp() {
        super.setUp()
        delegate = StatelessAppDelegate()
        
        // Initialize MainMenu.xib
        var objects: NSArray?
        Bundle.main.loadNibNamed("MainMenu", owner: delegate, topLevelObjects: &objects)
    
        // set `statusMenu` of app delegate
        for object in objects ?? [] {
            NSLog("Bundle object type: \(type(of: object))")
            if object is NSMenu {
                delegate.statusMenu = (object as! NSMenu)
                break
            }
        }
        
        // Re-initialize defaults instead of triggering `applicationDidFinishLaunching`
        delegate.statusItem.button?.toolTip = "Brewlet"
        delegate.statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
    }
    
    override func tearDown() {
        super.tearDown()
        delegate = nil
    }
    
    func testSetupTimers() {
        XCTAssertNil(delegate.timer)
        delegate.setupTimers()
        XCTAssertNotNil(delegate.timer)
        XCTAssertTrue(delegate.timer!.isValid)
    }
    
    func testUpdateUpgrade() {
        delegate.update_upgrade(sender: nil)
        
        // Last updated timestamp is set
        let expectedStatus = "Brewlet. Last updated \(delegate.formatDate())"
        XCTAssertEqual(expectedStatus, delegate.statusItem.button?.toolTip)
    }
    
    func testToggleAnalytics() {
        delegate.toggle_analytics(turnOn: true)
        let s1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        NSLog("shareAnalytics: %d", s1)
        XCTAssertTrue(s1)
        
        delegate.toggle_analytics(turnOn: false)
        let s2 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        NSLog("shareAnalytics: %d", s2)
        XCTAssertFalse(s2)
    }
    
    func testExportList() {
        
        // re-instantiatiate delegate with mocked stdout
        delegate.stdout = "fzf\nfzf"
        
        delegate.export_list(sender: NSMenuItem())
        let file = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
            )[0].appendingPathComponent("brew-packages.txt")
        NSLog("Reading from file: \(file)")
        do {
            // `brew list -1` contents are written to `brew-packages.txt`
            let contents = try String(contentsOf: file, encoding: .utf8)
            XCTAssert(contents == "fzf\nfzf")
        } catch {
            NSLog("Failed reading file")
        }
    }
    
    func testUpdateAnalytics() {
        delegate.stdout = """
        Analytics are enabled.
        UUID: <redacted>
        """
        delegate.update_analytics()
        XCTAssert(delegate.userDefaults.bool(forKey: "shareAnalytics") == true)
        
        delegate.stdout = """
        Analytics are disabled.
        """
        delegate.update_analytics()
        XCTAssert(delegate.userDefaults.bool(forKey: "shareAnalytics") == false)
    }
    
    func testCheckOutdated() {
        // TODO
    }
    
    func testFillPackageMenu() {
        // TODO
    }
    
    func testUpgradePackage() {
        // TODO
    }
    
    func testUpdateInfo() {
        delegate.stdout = """
        231 kegs, 197,732 files, 5.1GB
        """
        delegate.update_info()
        let item = delegate.statusMenu.item(withTag: 3)
        XCTAssert(item?.title == delegate.stdout)
    }
        
    func testAnimateIcon() {
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
    
    func testGetTemporaryFile() {
        // TODO
    }
    
    func testFormatDate() {
        let d = Date(timeIntervalSinceReferenceDate: 410220000)
        let f = delegate.formatDate(date: d)
        XCTAssert(f == "Dec 31, 2013 at 5:00 PM")
    }
    
    func testIncludeDependenciesChanged() {
        // TODO
    }
    
    func testShareAnalyticsChanged() {
        delegate.shareAnalyticsChanged(newState: .on)
        let v0 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        XCTAssert(v0 == true)
        
        delegate.shareAnalyticsChanged(newState: .off)
        let v1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        XCTAssert(v1 == false)
    }
    
    func testUpdateIntervalChanges() {
        delegate.updateIntervalChanged(newInterval: 3000)
        let v0 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v0 == 3000)
        
        delegate.updateIntervalChanged(newInterval: 3600)
        let v1 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v1 == 3600)
    }
}
