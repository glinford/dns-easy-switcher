//
//  CustomSheet.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import SwiftUI
import AppKit

class CustomSheetWindowController: NSWindowController, NSWindowDelegate {

    convenience init(view: some View, title: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false

        if let frameString = UserDefaults.standard.string(forKey: "CustomDNSManagerWindowFrame") {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: false)
        } else if let screen = NSScreen.main {
            let vis = screen.visibleFrame
            let w = window.frame.size.width
            let h = window.frame.size.height
            let origin = NSPoint(x: vis.origin.x + vis.size.width - w - 16,
                                 y: vis.origin.y + vis.size.height - h - 24)
            window.setFrameOrigin(origin)
        }
        self.init(window: window)
        window.delegate = self
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        if let window = self.window {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: "CustomDNSManagerWindowFrame")
        }
    }
}
