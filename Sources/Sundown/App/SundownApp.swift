import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}

@main
struct SundownApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = DaylightModel()

  var body: some Scene {
    MenuBarExtra {
      SundownMenuView(model: model)
        .frame(width: 360)
    } label: {
      Text(model.menuBarTitle)
        .monospacedDigit()
    }
    .menuBarExtraStyle(.window)
  }
}
