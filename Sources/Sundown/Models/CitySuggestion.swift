import Foundation

struct CitySuggestion: Identifiable, Equatable {
  let title: String
  let subtitle: String

  var id: String {
    "\(title)|\(subtitle)"
  }

  var displayTitle: String {
    guard !subtitle.isEmpty else {
      return title
    }

    return "\(title), \(subtitle)"
  }
}
