import Foundation

enum LocationSource: String, CaseIterable, Identifiable {
  case current
  case manual

  var id: String { rawValue }

  var title: String {
    switch self {
    case .current:
      return "Current"
    case .manual:
      return "City"
    }
  }
}
