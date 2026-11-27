import UIKit

/// Light feedback for switching views, ticking tasks, snapping wheels and dropping entries.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notify = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred() }
    static func tick() { selection.selectionChanged() }
    static func success() { notify.notificationOccurred(.success) }
}
