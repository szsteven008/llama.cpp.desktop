//
//  llama_cpp_desktopApp.swift
//  llama.cpp.desktop
//
//  Created by steve.tang on 2026/4/28.
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isActived = false
    @Published var hideChat = true
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGray])
            button.image = NSImage(
                systemSymbolName: "bolt.circle",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
            button.action = #selector(toggleApp)
            button.target = self
        }
    }
    
    @objc func toggleApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func updateIcon(isActived: Bool) {
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(paletteColors: [isActived ? .systemGreen : .systemGray])
            button.image = NSImage(
                systemSymbolName: "bolt.circle",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
        }
    }
}


@main
struct llama_cpp_desktopApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    @StateObject var state = AppState.shared
    private let width = 600.0
    private let height = 700.0
    private let minHeight = 700.0 * 0.3
    
    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView()
                    .frame(height: minHeight)
                    .environmentObject(state)
                if !state.hideChat {
                    Divider()
                    ChatView()
                }
            }
            .frame(width: width, height: state.hideChat ? minHeight : height)
            .font(.footnote)
            .controlSize(.small)
        }
        .windowResizability(.contentSize)
        .onChange(of: state.isActived) {
            appDelegate.updateIcon(isActived: state.isActived)
        }
    }
}
