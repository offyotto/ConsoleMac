import SwiftUI

private struct OpenConsoleSettingsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var openConsoleSettings: @MainActor @Sendable () -> Void {
        get { self[OpenConsoleSettingsKey.self] }
        set { self[OpenConsoleSettingsKey.self] = newValue }
    }
}
