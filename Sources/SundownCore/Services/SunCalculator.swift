import Foundation

public enum SunCalculator {
  public static func sunlightInterval(
    on date: Date,
    coordinate: GeographicCoordinate,
    calendar inputCalendar: Calendar = .current
  ) -> SunlightInterval? {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone

    guard
      let sunrise = sunEvent(on: date, coordinate: coordinate, kind: .sunrise, calendar: calendar),
      let sunset = sunEvent(on: date, coordinate: coordinate, kind: .sunset, calendar: calendar),
      sunrise < sunset
    else {
      return nil
    }

    return SunlightInterval(sunrise: sunrise, sunset: sunset)
  }

  private enum EventKind {
    case sunrise
    case sunset
  }

  private static func sunEvent(
    on date: Date,
    coordinate: GeographicCoordinate,
    kind: EventKind,
    calendar: Calendar
  ) -> Date? {
    guard abs(coordinate.latitude) <= 90, abs(coordinate.longitude) <= 180 else {
      return nil
    }

    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    let longitudeHour = coordinate.longitude / 15
    let approximateTime: Double

    switch kind {
    case .sunrise:
      approximateTime = Double(dayOfYear) + ((6 - longitudeHour) / 24)
    case .sunset:
      approximateTime = Double(dayOfYear) + ((18 - longitudeHour) / 24)
    }

    let meanAnomaly = (0.9856 * approximateTime) - 3.289
    var trueLongitude = meanAnomaly
      + (1.916 * sin(degreesToRadians(meanAnomaly)))
      + (0.020 * sin(degreesToRadians(2 * meanAnomaly)))
      + 282.634
    trueLongitude = normalizeDegrees(trueLongitude)

    var rightAscension = radiansToDegrees(atan(0.91764 * tan(degreesToRadians(trueLongitude))))
    rightAscension = normalizeDegrees(rightAscension)

    let longitudeQuadrant = floor(trueLongitude / 90) * 90
    let rightAscensionQuadrant = floor(rightAscension / 90) * 90
    rightAscension += longitudeQuadrant - rightAscensionQuadrant
    rightAscension /= 15

    let sinDeclination = 0.39782 * sin(degreesToRadians(trueLongitude))
    let cosDeclination = cos(asin(sinDeclination))
    let zenith = 90.833

    let cosHourAngle = (
      cos(degreesToRadians(zenith))
        - (sinDeclination * sin(degreesToRadians(coordinate.latitude)))
    ) / (cosDeclination * cos(degreesToRadians(coordinate.latitude)))

    guard cosHourAngle >= -1, cosHourAngle <= 1 else {
      return nil
    }

    let hourAngle: Double
    switch kind {
    case .sunrise:
      hourAngle = (360 - radiansToDegrees(acos(cosHourAngle))) / 15
    case .sunset:
      hourAngle = radiansToDegrees(acos(cosHourAngle)) / 15
    }

    let localMeanTime = hourAngle + rightAscension - (0.06571 * approximateTime) - 6.622
    let universalTime = normalizeHours(localMeanTime - longitudeHour)

    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let localComponents = calendar.dateComponents([.year, .month, .day], from: date)
    guard let utcMidnight = utcCalendar.date(from: DateComponents(
      timeZone: utcCalendar.timeZone,
      year: localComponents.year,
      month: localComponents.month,
      day: localComponents.day,
      hour: 0,
      minute: 0,
      second: 0
    )) else {
      return nil
    }

    let utcEvent = utcMidnight.addingTimeInterval(universalTime * 60 * 60)
    return align(utcEvent, toLocalDayContaining: date, calendar: calendar)
  }

  private static func align(
    _ event: Date,
    toLocalDayContaining date: Date,
    calendar: Calendar
  ) -> Date {
    let targetDay = calendar.startOfDay(for: date)
    var adjustedEvent = event

    for _ in 0..<2 {
      let eventDay = calendar.startOfDay(for: adjustedEvent)
      if eventDay == targetDay {
        return adjustedEvent
      }

      if eventDay < targetDay {
        adjustedEvent = calendar.date(byAdding: .day, value: 1, to: adjustedEvent)
          ?? adjustedEvent.addingTimeInterval(24 * 60 * 60)
      } else {
        adjustedEvent = calendar.date(byAdding: .day, value: -1, to: adjustedEvent)
          ?? adjustedEvent.addingTimeInterval(-24 * 60 * 60)
      }
    }

    return adjustedEvent
  }

  private static func normalizeDegrees(_ value: Double) -> Double {
    let result = value.truncatingRemainder(dividingBy: 360)
    return result >= 0 ? result : result + 360
  }

  private static func normalizeHours(_ value: Double) -> Double {
    let result = value.truncatingRemainder(dividingBy: 24)
    return result >= 0 ? result : result + 24
  }

  private static func degreesToRadians(_ degrees: Double) -> Double {
    degrees * .pi / 180
  }

  private static func radiansToDegrees(_ radians: Double) -> Double {
    radians * 180 / .pi
  }
}
