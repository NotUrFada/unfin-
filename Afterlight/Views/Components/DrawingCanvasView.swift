//
//  DrawingCanvasView.swift
//  Unfin
//

import SwiftUI
import PencilKit

/// PencilKit canvas for starting or continuing a drawing. Bind to a PKDrawing to load/save.
struct DrawingCanvasView: View {
    @Binding var drawing: PKDrawing
    var readOnly: Bool = false
    var backgroundColor: Color = Color.white.opacity(0.05)
    
    var body: some View {
        DrawingCanvasRepresentable(drawing: $drawing, readOnly: readOnly, backgroundColor: backgroundColor)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct DrawingCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var readOnly: Bool
    var backgroundColor: Color
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.drawingPolicy = readOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = !readOnly
        canvas.drawing = drawing
        canvas.tool = PKInkingTool(.pen, color: .white, width: 2)
        return canvas
    }
    
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        canvas.isUserInteractionEnabled = !readOnly
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasRepresentable
        init(_ parent: DrawingCanvasRepresentable) {
            self.parent = parent
        }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

/// Renders a PKDrawing as an image (read-only display).
struct DrawingThumbnailView: View {
    let drawing: PKDrawing
    var maxSize: CGFloat = 400
    
    private var drawingImage: UIImage? {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }
        return drawing.image(from: bounds, scale: 2)
    }
    
    var body: some View {
        Group {
            if let img = drawingImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.white.opacity(0.05)
                    .overlay(Text("No strokes yet").font(.caption).foregroundStyle(.white.opacity(0.5)))
            }
        }
        .frame(maxWidth: maxSize, maxHeight: maxSize)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
