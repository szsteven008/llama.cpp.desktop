//
//  ChatView.swift
//  llama.cpp.desktop
//
//  Created by steve.tang on 2026/4/28.
//

import SwiftUI
import WebKit

struct ChatView: View {
    var body: some View {
        VStack {
            HStack {
                Text("LLAMA.CPP.CHAT")
                    .fontWeight(.semibold)
                Spacer()
            }
            Divider()
            ChatMainView(url: URL(string: "http://127.0.0.1:8080"))
        }
        .padding()
    }
}

class Coordinator: NSObject, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        
        let result = panel.runModal()
        completionHandler((result == .OK) ? panel.urls : nil)
    }
}

struct ChatMainView: NSViewRepresentable {
    let url: URL?
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let nsView = WKWebView()
        nsView.uiDelegate = context.coordinator
        nsView.pageZoom = 0.6
        return nsView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: url!))
    }
}
