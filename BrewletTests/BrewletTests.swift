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

    // Create placeholder of application delegate
    var delegate: AppDelegate!
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        delegate = NSApplication.shared.delegate as! AppDelegate
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
