//
//  GenartPlaygroundApp.swift
//  Shared
//
//  Created by Алексей Лысенко on 05.08.2021.
//

import SwiftUI

@main
struct GenartPlaygroundApp: App {
    @State var isRecording = ControlEvent.stopRendering
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Spacer()
                Button {
                    record()
                } label: {
                    Text("записать")
                }
            }
            .background(
                RenderingView(
                    isRecording: $isRecording,
                    width: 1024,
                    height: 1024
                ) {
                    ContentView()
                }
            )
            .padding()
        }
    }

    func record() {
        isRecording = .startRendering

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isRecording = .stopRendering
        }
    }
}
