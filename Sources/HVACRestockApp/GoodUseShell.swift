import SwiftUI

public struct GUPalette: Sendable {
    let canvas: Color, surface: Color, raised: Color, primary: Color, onPrimary: Color
    let text: Color, secondary: Color, border: Color, success: Color, warning: Color, error: Color
}

public enum GUPalettes {
    static let light = GUPalette(
        canvas: Color(hex: "#F5F7F8"), surface: .white, raised: Color(hex: "#EDF3F5"),
        primary: Color(hex: "#215B7A"), onPrimary: .white, text: Color(hex: "#13232D"),
        secondary: Color(hex: "#51636D"), border: Color(hex: "#CDD9DE"), success: Color(hex: "#2E7259"),
        warning: Color(hex: "#9A6508"), error: Color(hex: "#A74343")
    )
    static let dark = GUPalette(
        canvas: Color(hex: "#0E1519"), surface: Color(hex: "#162128"), raised: Color(hex: "#1D2B33"),
        primary: Color(hex: "#8FC8E8"), onPrimary: Color(hex: "#08202D"), text: Color(hex: "#EDF4F7"),
        secondary: Color(hex: "#B8C7CE"), border: Color(hex: "#40515B"), success: Color(hex: "#72C19A"),
        warning: Color(hex: "#E4B65E"), error: Color(hex: "#E08C8C")
    )
}

public struct GURuntime: Sendable {
    let palette: GUPalette
    let width: CGFloat
    let gutter: CGFloat
    let wideBoard: Bool
}

private struct GURuntimeKey: EnvironmentKey { static let defaultValue: GURuntime? = nil }

extension EnvironmentValues {
    var guRuntime: GURuntime? {
        get { self[GURuntimeKey.self] }
        set { self[GURuntimeKey.self] = newValue }
    }
}

public struct GoodUseFrame<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: (GURuntime) -> Content

    public init(@ViewBuilder content: @escaping (GURuntime) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let palette = scheme == .dark ? GUPalettes.dark : GUPalettes.light
            let width = proxy.size.width
            let gutter: CGFloat = width < 360 ? 12 : width < 600 ? 16 : width < 900 ? 24 : width < 1200 ? 32 : 40
            let runtime = GURuntime(palette: palette, width: width, gutter: gutter, wideBoard: width >= 900)
            ZStack(alignment: .top) {
                palette.canvas.ignoresSafeArea()
                content(runtime)
                    .padding(.horizontal, gutter)
                    .frame(maxWidth: width >= 1200 ? 1360 : .infinity, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .environment(\.guRuntime, runtime)
        }
    }
}

public struct GUSection<Content: View>: View {
    @Environment(\.guRuntime) private var runtime
    let title: String?
    let emphasis: Bool
    let content: Content

    public init(_ title: String? = nil, emphasis: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.emphasis = emphasis
        self.content = content()
    }

    public var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.system(size: 21, weight: .semibold)) }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(emphasis ? palette.raised : palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.border.opacity(0.65), lineWidth: 1))
    }
}

public struct GUPrimary: View {
    @Environment(\.guRuntime) private var runtime
    let text: String
    let icon: String?
    let action: () -> Void

    public init(_ text: String, icon: String? = nil, action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { GoodUseVectorIcon(key: icon).frame(width: 20, height: 20) }
                Text(text).font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.onPrimary)
        .background(palette.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

public struct GUSecondary: View {
    @Environment(\.guRuntime) private var runtime
    let text: String
    let icon: String?
    let action: () -> Void

    public init(_ text: String, icon: String? = nil, action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { GoodUseVectorIcon(key: icon).frame(width: 20, height: 20) }
                Text(text).font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.text)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.border, lineWidth: 1))
    }
}

public struct GUStatus: View {
    @Environment(\.guRuntime) private var runtime
    let text: String
    let tone: String

    public init(_ text: String, tone: String = "neutral") {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        let color = tone == "warning" ? palette.warning : tone == "error" ? palette.error : tone == "success" ? palette.success : palette.secondary
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
    }
}

/** GOODUSE_ICON_REGISTRY 1.1.0 canonical 24x24 subset. */
public struct GoodUseVectorIcon: View {
    let key: String

    public init(key: String) { self.key = key }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let color = GraphicsContext.Shading.color(Color.primary)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
            func stroke(_ points: [CGPoint]) {
                var path = Path()
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: color, lineWidth: 1.8 * scale)
            }
            switch key {
            case "play", "resume":
                var path = Path()
                path.move(to: point(8, 5))
                path.addLine(to: point(19, 12))
                path.addLine(to: point(8, 19))
                path.closeSubpath()
                context.fill(path, with: color)
            case "pause":
                var first = Path()
                first.addRect(CGRect(x: 7 * scale, y: 5 * scale, width: 3.5 * scale, height: 14 * scale))
                context.fill(first, with: color)
                var second = Path()
                second.addRect(CGRect(x: 13.5 * scale, y: 5 * scale, width: 3.5 * scale, height: 14 * scale))
                context.fill(second, with: color)
            case "stop":
                var path = Path()
                path.addRect(CGRect(x: 6 * scale, y: 6 * scale, width: 12 * scale, height: 12 * scale))
                context.fill(path, with: color)
            case "complete", "check", "save":
                stroke([point(4, 12), point(9.5, 17.5), point(20, 6)])
            case "plus":
                stroke([point(12, 4), point(12, 20)])
                stroke([point(4, 12), point(20, 12)])
            case "settings":
                stroke([point(3, 6), point(21, 6)])
                stroke([point(3, 12), point(21, 12)])
                stroke([point(3, 18), point(21, 18)])
                context.stroke(Path(ellipseIn: CGRect(x: 6 * scale, y: 4 * scale, width: 4 * scale, height: 4 * scale)), with: color, lineWidth: 1.8 * scale)
                context.stroke(Path(ellipseIn: CGRect(x: 14 * scale, y: 10 * scale, width: 4 * scale, height: 4 * scale)), with: color, lineWidth: 1.8 * scale)
                context.stroke(Path(ellipseIn: CGRect(x: 9 * scale, y: 16 * scale, width: 4 * scale, height: 4 * scale)), with: color, lineWidth: 1.8 * scale)
            default:
                context.stroke(Path(ellipseIn: CGRect(x: 3 * scale, y: 3 * scale, width: 18 * scale, height: 18 * scale)), with: color, lineWidth: 1.8 * scale)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var raw: UInt64 = 0
        Scanner(string: value).scanHexInt64(&raw)
        let red = Double((raw & 0xFF0000) >> 16) / 255
        let green = Double((raw & 0x00FF00) >> 8) / 255
        let blue = Double(raw & 0x0000FF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
