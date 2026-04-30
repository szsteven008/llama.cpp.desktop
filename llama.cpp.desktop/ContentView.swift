//
//  ContentView.swift
//  llama.cpp.desktop
//
//  Created by steve.tang on 2026/4/28.
//

import SwiftUI
import Combine

struct ContentView: View {
    var body: some View {
        VStack {
            HeaderView()
            Divider()
            MainView()
        }
        .padding()
    }
}

struct HeaderView: View {
    @EnvironmentObject var state: AppState
    let log = LogViewModel.shared
    
    var body: some View {
        HStack {
            Text("LLAMA.CPP.SERVER")
                .fontWeight(.bold)
                .foregroundStyle(state.isActived ? .green : .gray)
            Spacer()
            Button(state.isActived ? "Stop" : "Start") {
                if (state.isActived) {
                    stop()
                    state.isActived = false
                    log.polling_stop()
                } else {
                    start()
                    state.isActived = true
                    log.polling_start()
                }
            }
            
            Button(state.hideChat ? "Open Chat" : "Hide Chat") {
                state.hideChat = !state.hideChat
            }
            .disabled(!state.isActived)
            
            Button("Quit") {
                stop()
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct MainView: View {
    var body: some View {
        GeometryReader { geo in
            HStack {
                LogView()
                Divider()
                ModelView()
                    .frame(width: geo.size.width * 0.3)
            }
        }
    }
}

class LogViewModel: ObservableObject {
    static let shared = LogViewModel()
    
    @Published var messages: [String] = []
    
    private var pollingTask: Task<Void, Never>?

    deinit {
        polling_stop()
    }
    
    func polling_start(interval: Duration = .seconds(0.3)) {
        pollingTask?.cancel()
        self.messages = []
        
        pollingTask = Task {
            var messages: [String] = []
            while !Task.isCancelled {
                let log = log_get()
                if log.size() > 0 {
                    let message = String(log)
                    messages.append(message)
                } else {
                    if (!messages.isEmpty) {
                        await MainActor.run {
                            self.messages.append(contentsOf: messages)
                        }
                        messages = []
                    }
                    try? await Task.sleep(for: interval)
                }
            }
        }
    }
    
    func polling_stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

struct LogView: View {
    @StateObject var data = LogViewModel.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(data.messages.indices, id: \.self) { index in
                            Text(data.messages[index])
                                .id(index)
                        }
                    }
                }
                .onChange(of: data.messages) {
                    scroll_to_bottom(using: proxy)
                }
                .onAppear() {
                    scroll_to_bottom(using: proxy)
                }
                
                Spacer()
            }
        }
    }
    
    private func scroll_to_bottom(using proxy: ScrollViewProxy) {
        guard !data.messages.isEmpty else { return }
        let last_index = data.messages.count - 1
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(last_index, anchor: .bottom)
        }
    }
}

struct ModelView: View {
    let installed: [String] = {
        var strings: [String] = []
        let cstrings = models()
        for cstr in cstrings {
            strings.append(String(cstr))
        }
        return strings
    }()
    
    var body: some View {
        VStack {
            ForEach(installed, id: \.self) { name in
                Text(name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(name)
            }
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
