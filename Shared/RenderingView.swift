//
//  RenderingView.swift
//  GenartPlayground
//
//  Created by Алексей Лысенко on 06.08.2021.
//

import SwiftUI
import Combine

enum ControlEvent {
    case startRendering
    case stopRendering
}

struct RenderingView<Content: View>: View {
    @Binding var isRecording: ControlEvent
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    init(isRecording: Binding<ControlEvent>, width: CGFloat = 512, height: CGFloat = 512, @ViewBuilder content: @escaping () -> Content) {
        self._isRecording = isRecording
        self.width = width
        self.height = height
        self.content = content
    }

    var body: some View {
        _RenderingView(isRecording: $isRecording, content: content)
            .frame(width: width, height: height, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
    }
}

private struct _RenderingView<Content: View>: UIViewControllerRepresentable {
    @Binding var isRecording: ControlEvent
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        return _RenderingViewController(rootView: content())
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        guard let vc = uiViewController as? _RenderingViewController<Content> else {
            return
        }
        context.coordinator.update(vc: vc, withEvent: isRecording)
    }

    // MARK: - coordinator
    struct Coordinator {
        fileprivate func update(vc: _RenderingViewController<Content>, withEvent event: ControlEvent) {
            switch event {
            case .startRendering:
                vc.startRendering()
            case .stopRendering:
                vc.stopRecording()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}

private class _RenderingViewController<Content: View>: UIHostingController<Content> {
    private let renderer = RealtimeRenderer()
    private var displayLink: CADisplayLink?
    private var counter = 0

    func startRendering() {
        guard displayLink == nil else { return }
        guard renderer.prepare() else { return }
        tick()

        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .default)
    }

    func stopRecording() {
        guard displayLink != nil else { return }
        displayLink?.invalidate()
        displayLink = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [renderer] in
            renderer.startRender {
                print($0)
            } onFail: {
                print($0)
            }
            renderer.endRender()
        }
    }

    @objc private func tick() {
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)

        let image = renderer.image { (ctx) in
            view.layer.presentation()?.render(in: ctx.cgContext)
        }
        self.renderer.enqueue(image: image)
    }
}
