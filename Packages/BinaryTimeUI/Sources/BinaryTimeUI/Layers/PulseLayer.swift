import AppKit

/// The location-source pulse dot: opacity 1 → 0.2 → 1 over `period` seconds (tokens `motion.locationPulse`).
public final class PulseLayer: CALayer {
    static let animationKey = "binarytime.pulse"

    public override init() {
        super.init()
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func setPulsing(_ pulsing: Bool, period: TimeInterval, minimumOpacity: Float) {
        if pulsing {
            guard animation(forKey: PulseLayer.animationKey) == nil else { return }
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = minimumOpacity
            animation.duration = period / 2
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            add(animation, forKey: PulseLayer.animationKey)
        } else {
            removeAnimation(forKey: PulseLayer.animationKey)
            opacity = 1
        }
    }
}
