//
//  MenuBarController.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import AppKit

class MenuBarController: ObservableObject {
    init() {
        // Hide the dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
