#if canImport(AppKit)
import AppKit

/// Dwell (hover-to-press) configuration shared by key and suggestion views.
struct DwellConfiguration {
    var enabled = false
    var time: TimeInterval = 0.9
}

/// Counts a hover up to the dwell time, reporting progress for the on-key
/// indicator. One instance per hoverable view.
final class DwellTimer {
    /// Progress in 0..<1 while counting, 0 once cancelled or completed.
    var onProgress: ((CGFloat) -> Void)?
    var onComplete: (() -> Void)?

    private var ticker: Timer?

    func start(duration: TimeInterval) {
        cancel()
        let start = Date()
        let ticker = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let progress = CGFloat(Date().timeIntervalSince(start) / duration)
            if progress >= 1 {
                self.cancel()
                self.onComplete?()
            } else {
                self.onProgress?(progress)
            }
        }
        // Common modes: the panel is dragged and menus are open while hovering.
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func cancel() {
        guard ticker != nil else { return }
        ticker?.invalidate()
        ticker = nil
        onProgress?(0)
    }
}
#endif
