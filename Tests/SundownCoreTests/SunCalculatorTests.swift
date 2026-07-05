import XCTest
@testable import SundownCore

final class SunCalculatorTests: XCTestCase {
  func testBucharestSummerSunsetIsInExpectedRange() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!

    let date = try XCTUnwrap(calendar.date(from: DateComponents(
      timeZone: calendar.timeZone,
      year: 2026,
      month: 7,
      day: 4,
      hour: 12
    )))

    let interval = try XCTUnwrap(SunCalculator.sunlightInterval(
      on: date,
      coordinate: GeographicCoordinate(latitude: 44.4268, longitude: 26.1025),
      calendar: calendar
    ))

    let sunsetComponents = calendar.dateComponents([.hour, .minute], from: interval.sunset)
    let sunsetHour = try XCTUnwrap(sunsetComponents.hour)

    XCTAssertTrue((20...21).contains(sunsetHour))
  }

  func testMiamiSunsetAcrossUTCDateBoundary() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!

    let date = try XCTUnwrap(calendar.date(from: DateComponents(
      timeZone: calendar.timeZone,
      year: 2026,
      month: 7,
      day: 4,
      hour: 12
    )))

    let interval = try XCTUnwrap(SunCalculator.sunlightInterval(
      on: date,
      coordinate: GeographicCoordinate(latitude: 25.7617, longitude: -80.1918),
      calendar: calendar
    ))

    XCTAssertLessThan(interval.sunrise, interval.sunset)
    XCTAssertEqual(calendar.component(.day, from: interval.sunrise), 4)
    XCTAssertEqual(calendar.component(.day, from: interval.sunset), 4)

    let sunsetHour = calendar.component(.hour, from: interval.sunset)
    XCTAssertEqual(sunsetHour, 20)
  }

  func testTokyoSunriseAcrossUTCDateBoundary() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

    let date = try XCTUnwrap(calendar.date(from: DateComponents(
      timeZone: calendar.timeZone,
      year: 2026,
      month: 7,
      day: 4,
      hour: 12
    )))

    let interval = try XCTUnwrap(SunCalculator.sunlightInterval(
      on: date,
      coordinate: GeographicCoordinate(latitude: 35.6762, longitude: 139.6503),
      calendar: calendar
    ))

    XCTAssertLessThan(interval.sunrise, interval.sunset)
    XCTAssertEqual(calendar.component(.day, from: interval.sunrise), 4)
    XCTAssertEqual(calendar.component(.day, from: interval.sunset), 4)

    let sunriseHour = calendar.component(.hour, from: interval.sunrise)
    let sunsetHour = calendar.component(.hour, from: interval.sunset)
    XCTAssertEqual(sunriseHour, 4)
    XCTAssertEqual(sunsetHour, 19)
  }

  func testRemainingFormatterUsesCompactMenuBarShape() {
    XCTAssertEqual(DaylightTimeFormatter.compactRemaining(12_420), "3h27m")
    XCTAssertEqual(DaylightTimeFormatter.compactRemaining(1_500), "25m")
    XCTAssertEqual(DaylightTimeFormatter.compactRemaining(-10), "0m")
  }
}
