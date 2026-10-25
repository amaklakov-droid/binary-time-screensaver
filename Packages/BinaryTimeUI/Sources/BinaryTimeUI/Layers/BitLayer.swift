import AppKit
import BinaryTimeCore

/// One cell of a bit grid (tokens `bit.states`, `bit.shape`).
public final class BitLayer: CALayer {
    public private(set) var state: BitState = .void

    public struct Appearance: Equatable {
        public var size: CGFloat
        public var shape: BitShape
        public var squareRadius: CGFloat
        public var outline: CGFloat
        public var voidScale: CGFloat
        public var lowOpacity: Float
        public var ghostOpacity: Float
        public var color: CGColor

        public init(size: CGFloat, shape: BitShape, squareRadius: CGFloat, outline: CGFloat, voidScale: CGFloat, lowOpacity: Float, ghostOpacity: Float, color: CGColor) {
            self.size = size
            self.shape = shape
            self.squareRadius = squareRadius
            self.outline = outline
            self.voidScale = voidScale
            self.lowOpacity = lowOpacity
            self.ghostOpacity = ghostOpacity
            self.color = color
        }
    }

    public override init() {
        super.init()
        allowsEdgeAntialiasing = true
    }

    public override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? BitLayer { state = other.state }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Sets geometry and colours for the current state. Call inside the caller's `CATransaction`.
    public func configure(_ appearance: Appearance) {
        bounds = CGRect(x: 0, y: 0, width: appearance.size, height: appearance.size)
        cornerRadius = appearance.shape == .dot ? appearance.size / 2 : appearance.squareRadius
        borderColor = appearance.color
        apply(state: state, appearance: appearance)
    }

    /// Changes the state. `CATransaction` duration and action settings decide whether it animates.
    public func apply(state newState: BitState, appearance: Appearance) {
        state = newState
        switch newState {
        case .on:
            backgroundColor = appearance.color
            borderWidth = 0
            opacity = 1
            transform = CATransform3DIdentity
        case .off:
            backgroundColor = nil
            borderWidth = appearance.outline
            opacity = appearance.lowOpacity
            transform = CATransform3DIdentity
        case .void:
            backgroundColor = appearance.color
            borderWidth = 0
            opacity = appearance.ghostOpacity
            transform = CATransform3DMakeScale(appearance.voidScale, appearance.voidScale, 1)
        }
    }
}
