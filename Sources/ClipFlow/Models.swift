import SwiftUI
import AppKit
import Carbon
import QuartzCore
import Combine

struct Clip: Identifiable, Codable {
    var id = UUID()
    var text: String
    var pinned = false
    var imageData: Data? = nil
}
