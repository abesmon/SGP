//
//  ContentView.swift
//  Shared
//
//  Created by Алексей Лысенко on 05.08.2021.
//

import SwiftUI

struct ContentView: View {
    @State private var lastDate = Date()
    @State private var overallTime: TimeInterval = 0

    var count: Int = 10

    private let timer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()

    var body: some View {
        ZStack {
            ForEach(0..<count) { i in
                Ball(overallTime: overallTime, i: i, allCount: count)
            }
            .animation(.linear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yellow)
        .onReceive(timer, perform: {
            let deltaTime = $0.distance(to: lastDate)
            overallTime += deltaTime
            lastDate = $0
        })
    }
}

struct Ball: View {
    var overallTime: TimeInterval
    var pos: CGPoint {
        let timePos = overallTime - Double(i) * 100
        let x = CGFloat(sin(timePos)) * 100
        let y = CGFloat(cos(timePos)) * 100
        return CGPoint(x: x, y: y)
    }
    var i: Int
    let allCount: Int

    var body: some View {
        let alpha = 1 - (1 / Double(allCount)) * Double(i)
        Circle()
            .fill(Color.red.opacity(alpha))
            .frame(width: 50)
            .offset(x: pos.x, y: pos.y)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
