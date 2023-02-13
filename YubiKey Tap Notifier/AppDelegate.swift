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
    var defaultImage: NSImage {
        NSImage(named: "status_icon_default")!
    }
    var activeImage: NSImage {
        NSImage(named: "status_icon_active")!
    }
    var touchImage: NSImage {
        NSImage(named: "status_icon_touch")!
    }
    let center = UNUserNotificationCenter.current()
    let title = "YubiKey Tap Notifier"
    let desc = "Please tap the YubiKey"
    var checkTime = "Didn't check"
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the status item's button image
        if let button = statusItem.button {
            button.image = defaultImage
        }

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
        checkForYubiKeyTap()
    }
    
    @objc func checkForYubiKeyTap() {
        if (timer != nil) {
            timer = nil
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            do {
                try self.exec()
                self.printCheck()
                semaphore.signal()
                DispatchQueue.main.async {
                    self.statusItem.button?.image = self.defaultImage
                    self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(Self.checkForYubiKeyTap), userInfo: nil, repeats: false)
                    self.center.removeAllDeliveredNotifications()
                }
            } catch let error as NSError {
                print("Error: \(error)")
                semaphore.signal()
            }
        }
        
        if semaphore.wait(timeout: .now() + 0.3) == .timedOut {
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.touchImage
                self.displayNotification()
            }
        }
    }

    
    func printCheck() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        checkTime = "Last check: \(dateString)"
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
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let button = statusItem.button {
            button.image = activeImage
        }
        checkTimeItem.title = checkTime
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if let button = statusItem.button {
            button.image = defaultImage
        }
    }
}
