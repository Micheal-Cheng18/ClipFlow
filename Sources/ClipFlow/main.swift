import SwiftUI
import AppKit
import Carbon
import QuartzCore
import Combine

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = Delegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
