//
//  PreferencesController.swift
//  Brewlet
//
//  Created by zzada on 2/23/20.
//  Copyright © 2020 zzada. All rights reserved.
//

import Cocoa

protocol PreferencesDelegate {
    func updateIntervalChanged(newInterval: TimeInterval?) // if nil, then don't update
    func includeDependenciesChanged(newState: NSControl.StateValue)
}

class PreferencesController: NSWindowController {

    @IBOutlet weak var includeDependencies: NSButton!
    @IBOutlet weak var updateInterval: NSSlider!
    
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
    }
    
    @IBAction func includeDependenciesPressed(_ sender: NSButton) {
        delegate?.includeDependenciesChanged(newState: sender.state)
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
