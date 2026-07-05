import Foundation

public struct SunlightInterval: Equatable, Sendable {
  public let sunrise: Date
  public let sunset: Date

  public init(sunrise: Date, sunset: Date) {
    self.sunrise = sunrise
    self.sunset = sunset
  }

  public var duration: TimeInterval {
    sunset.timeIntervalSince(sunrise)
  }

  public func remaining(at date: Date) -> TimeInterval {
    max(0, sunset.timeIntervalSince(date))
  }

  public func consumedFraction(at date: Date) -> Double {
    guard duration > 0 else { return 1 }
    let elapsed = date.timeIntervalSince(sunrise)
    return min(1, max(0, elapsed / duration))
  }

  public func daylightMessage(at date: Date) -> String {
    if date < sunrise {
      return "The daylight is still getting ready."
    }

    if date >= sunset {
      return "That's it. You're on artificial light now."
    }

    let fraction = consumedFraction(at: date)
    switch fraction {
    case ..<0.25:
      return "You still have daylight. Do not pawn it off."
    case ..<0.50:
      return "The day is still on your side."
    case ..<0.75:
      return "Half the daylight is already gone."
    case ..<0.90:
      return "You should probably go outside now."
    default:
      return "The last minutes do not negotiate."
    }
  }
}
