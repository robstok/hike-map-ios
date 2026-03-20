import SwiftUI

/// The Hitrekk mountain logo — matches the SVG in the web app.
/// ViewBox is 0 0 28 28; all coordinates are in that space.
struct HitrekkLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 28
        let sy = rect.height / 28
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: p(2, 22))
        path.addLine(to: p(10, 8))
        path.addLine(to: p(16, 16))
        path.addLine(to: p(20, 11))
        path.addLine(to: p(26, 22))
        path.closeSubpath()
        return path
    }
}

struct HitrekkLogoView: View {
    var size: CGFloat = 28
    var color: Color = Config.accent

    var body: some View {
        ZStack {
            // Mountain fill (opacity 0.2)
            HitrekkLogoShape()
                .fill(color.opacity(0.2))

            // Mountain stroke
            HitrekkLogoShape()
                .stroke(color, style: StrokeStyle(lineWidth: 2 * size / 28,
                                                   lineCap: .round, lineJoin: .round))

            // Sun circle at (23, 6), r=2.5 in 28x28 space
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 5 * size / 28, height: 5 * size / 28)
                .offset(x: (23 - 14) * size / 28, y: (6 - 14) * size / 28)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HitrekkLogoView(size: 60)
        .padding()
        .background(Color(hex: "#0d1117"))
}
