//
//  AppDelegate.swift
//  YubiKey Tap Notifier
//
//  Created by n.nafranets on 11.02.2023.
//

import Cocoa
import UserNotifications
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let checkTimeItem = NSMenuItem(title: "Check Time: ", action: nil, keyEquivalent: "")
    let defaultImage = NSImage(named: "StatusIconDefault")
    let activeImage = NSImage(named: "StatusIconActive")
    let touchImage = NSImage(named: "StatusIconTouch")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the status item's button image
        if let button = statusItem.button {
            button.image = defaultImage
        }
        
        // Create a menu for the status item
        let menu = NSMenu()
        menu.addItem(checkTimeItem)
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        menu.delegate = self
        statusItem.menu = menu
        
        runBackgroundCode()
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func runBackgroundCode() {
        print("ask grand")
        askGrand()
        print("start timer")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
            self.checkForYubiKeyTap()
        })
    }
    
    let title = "YubiKey Tap Notifier"
    let desc = "Please tap the YubiKey"
    var checkTime = ""
    
    var isExecutionInProgress = false

    func checkForYubiKeyTap() {
        if isExecutionInProgress {
            return
        }
        
        isExecutionInProgress = true
        
        let group = DispatchGroup()
        group.enter()
        
        let timeoutWork = DispatchWorkItem {
            self.displayNotification()
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.touchImage
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3, execute: timeoutWork)
        
        DispatchQueue.global().async {
            do {
                try self.exec()
                self.printCheck()
            } catch let error as NSError {
                print("Error: \(error)")
            }
            group.leave()
        }
        
        group.notify(queue: .global()) {
            timeoutWork.cancel()
            self.isExecutionInProgress = false
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.defaultImage
            }
            
        }
    }
    
    func printCheck() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        checkTimeItem.title = "Last check: \(dateString)"
    }
    
    func exec() throws {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-I"]
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/pkcs11-tool")
        task.standardInput = nil
        try task.run()
        task.waitUntilExit()
    }
    
    let center = UNUserNotificationCenter.current()
    func askGrand() {
        let options: UNAuthorizationOptions = [.alert, .sound]
        
        center.requestAuthorization(options: options) { (granted, error) in
            if !granted {
                print("Something went wrong")
            }
        }
    }
    
    func displayNotification() {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = desc
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if error != nil {
                print("Error: \(error?.localizedDescription ?? "Unknown Error")")
            }
        }
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let button = statusItem.button {
            button.image = activeImage
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if let button = statusItem.button {
            button.image = defaultImage
        }
    }
}
