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
    var delegate: AppDelegate!
    
    /// App delegate where functions with side-effects have been removed
    class StatelessAppDelegate : AppDelegate {
        
        /// `run_command` where `brew` is not actually invoked
        override func run_command(
            arguments: [String],
            fileRedirect: FileHandle? = nil,
            outputHandler: @escaping (Process, Data) -> Void) {
            
            // Mock closure data depending on `brew` command arguments when the data variable is leveraged
            var data = Data()
            switch arguments {
            case ["list", "-1"]:
                data = """
                    fzf
                    vim
                    """.data(using: .utf8)!
            case ["analytics", "state"]:
                let stdout = """
                    Analytics are enabled.
                    UUID: <redacted>
                    """
                data = stdout.data(using: .utf8)!
            case ["info", "--json", "--installed"]:
                data = Data()
            case ["info"]:
                data = "231 kegs, 197,732 files, 5.1GB".data(using: .utf8)!
            default:
                data = Data()
            }
            
            // Return parameters for closure
            outputHandler(Process(), data)
        }
        
    }
 
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        delegate = StatelessAppDelegate() as AppDelegate
        
        // Re-initialize defaults instead of triggering `applicationDidFinishLaunching`
        delegate.statusItem.button?.toolTip = "Brewlet"
        delegate.statusItem.button?.image = NSImage(named: "BrewletIcon-Black")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        delegate = nil
    }
    
    /// Date is formatted appropriately
    func testFormatDate() {
        let d = Date(timeIntervalSinceReferenceDate: 410220000)
        let f = delegate.formatDate(date: d)
        XCTAssert(f == "Dec 31, 2013 at 5:00 PM")
    }
    
    /// Icon cycles through images when timer is fired
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
    
    /// User defaults are updated to desired interval value
    func testUpdateIntervalChanges() {
        delegate.updateIntervalChanged(newInterval: 3000)
        let v0 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v0 == 3000)
        
        delegate.updateIntervalChanged(newInterval: 3600)
        let v1 = delegate.userDefaults.value(forKey: "updateInterval") as! Int
        XCTAssert(v1 == 3600)
    }
    
    /// Toggle share analytics in preferences - `brew` command is not invoked as  delegate method `run_command` has been overriden
    func testShareAnalyticsChanged() {
        delegate.shareAnalyticsChanged(newState: .on)
        let v0 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        XCTAssert(v0 == true)
        
        delegate.shareAnalyticsChanged(newState: .off)
        let v1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        XCTAssert(v1 == false)
    }
    
    /// `shareAnalytics` user default is toggled betweetn true and false
    func testToggleAnalytics() {
        delegate.toggle_analytics(turnOn: true)
        let s1 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        NSLog("shareAnalytics: %d", s1)
        XCTAssert(s1 == true)
        
        delegate.toggle_analytics(turnOn: false)
        let s2 = delegate.userDefaults.bool(forKey: "shareAnalytics")
        NSLog("shareAnalytics: %d", s2)
        XCTAssert(s2 == false)
    }
    
    /// `brew list -1` contents are written to `brew-packages.txt`
    func testExportList() {
        delegate.export_list(sender: NSMenuItem())
        let file = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
            )[0].appendingPathComponent("brew-packages.txt")
        NSLog("Reading from file: \(file)")
        do {
            let contents = try String(contentsOf: file, encoding: .utf8)
            XCTAssert(contents == "fzf\nvim")
        } catch {
            NSLog("Failed reading file")
        }
    }
    
    /// userDefault `shareAnalytics` is set to `brew analytics state`
    func testUpdateAnalytics() {
        // TODO: mock both enabled and disabled analytics
        delegate.update_analytics()
        XCTAssert(delegate.userDefaults.bool(forKey: "shareAnalytics") == true)
    }
}
