import Foundation

public enum DaylightTimeFormatter {
  public static func compactRemaining(_ interval: TimeInterval) -> String {
    let totalMinutes = max(0, Int(interval / 60))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 {
      return "\(hours)h\(minutes)m"
    }

    return "\(minutes)m"
  }
}
