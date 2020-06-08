//
//  PreferencesController.swift
//  Brewlet
//
//  Created by zzada on 2/23/20.
//  Copyright © 2020 zzada. All rights reserved.
//

import OSLog
import Cocoa

protocol PreferencesDelegate {
    func updateIntervalChanged(newInterval: TimeInterval?) // if nil, then don't update
    func includeDependenciesChanged(newState: NSControl.StateValue)
    func shareAnalyticsChanged(newState: NSControl.StateValue)
}

class PreferencesController: NSWindowController {

    @IBOutlet weak var includeDependencies: NSButton!
    @IBOutlet weak var updateInterval: NSSlider!
    @IBOutlet weak var shareAnalytics: NSButton!
    @IBOutlet weak var autoUpgrade: NSButton!
    @IBOutlet weak var dontNotifyAvailable: NSButton!
    
    var delegate: PreferencesDelegate?
    
    override func windowDidLoad() {
        super.windowDidLoad()

        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.level = .popUpMenu
        NSApp.activate(ignoringOtherApps: true)
        
        // Update view with current preferences
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "includeDependencies") {
            includeDependencies.state = .on
        } else {
            includeDependencies.state = .off
        }
        
        let currentInterval = defaults.double(forKey: "updateInterval")
        if currentInterval == -1 {
            updateInterval.doubleValue = updateInterval.maxValue
        } else {
            let intervalIndex = (currentInterval / 3600) * 2
            updateInterval.doubleValue = intervalIndex
        }
        
        if defaults.bool(forKey: "shareAnalytics") {
            shareAnalytics.state = .on
        } else {
            shareAnalytics.state = .off
        }        
        
        autoUpgrade.state = defaults.bool(forKey: "autoUpgrade") ? .on : .off
        dontNotifyAvailable.state = defaults.bool(forKey: "dontNotify") ? .on : .off
    }
    
    @IBAction func includeDependenciesPressed(_ sender: NSButton) {
        delegate?.includeDependenciesChanged(newState: sender.state)
    }
    
    @IBAction func shareAnalyticsPressed(_ sender: NSButton) {
        delegate?.shareAnalyticsChanged(newState: sender.state)
    }
    
    @IBAction func autoUpgradeChanged(_ sender: NSButton) {
        os_log("Update auto upgrade: %s", type: .info, sender.state == .on ? "on" : "off")
        UserDefaults.standard.set(sender.state == .on, forKey: "autoUpgrade")
    }
    
    @IBAction func notifyChanged(_ sender: NSButton) {
        os_log("Update don't notify: %s", type: .info, sender.state == .on ? "on" : "off")
        UserDefaults.standard.set(sender.state == .on, forKey: "dontNotify")
    }
    
    @IBAction func updateIntervalChanged(_ sender: NSSlider) {
        
        var seconds: TimeInterval? = nil
        if sender.intValue == 10 {
            sender.toolTip = "Never"
        } else {
            let hours = sender.doubleValue * 0.5
            seconds = hours * 3600
            sender.toolTip = "\(hours) Hours"
        }
        
        delegate?.updateIntervalChanged(newInterval: seconds)
    }    
    
    override var windowNibName : String! {
        return "PreferencesController"
    }
    
}
