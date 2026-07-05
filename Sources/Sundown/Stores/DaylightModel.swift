import AppKit
import CoreLocation
import Foundation
import MapKit
import SundownCore
import UserNotifications

@MainActor
final class DaylightModel: NSObject, ObservableObject {
  @Published var locationSource: LocationSource = .manual {
    didSet {
      guard oldValue != locationSource else { return }
      defaults.set(locationSource.rawValue, forKey: DefaultsKey.locationSource)
      activateLocationSource()
    }
  }

  @Published var manualCityInput = "" {
    didSet {
      guard !isLoadingDefaults, !isApplyingCitySuggestion else { return }
      updateCitySuggestions(for: manualCityInput)
    }
  }

  @Published var displayLocation = "No location set"
  @Published var locationStatus = "Choose a location for sunset."
  @Published var isResolvingCity = false
  @Published var citySuggestions: [CitySuggestion] = []
  @Published var notificationEnabled = false {
    didSet {
      guard !isLoadingDefaults else { return }
      defaults.set(notificationEnabled, forKey: DefaultsKey.notificationEnabled)
      updateNotificationSchedule()
    }
  }

  @Published var notificationThresholdMinutes = 60 {
    didSet {
      guard !isLoadingDefaults else { return }
      defaults.set(notificationThresholdMinutes, forKey: DefaultsKey.notificationThresholdMinutes)
      updateNotificationSchedule()
    }
  }

  @Published private(set) var now = Date()
  @Published private(set) var sunlight: SunlightInterval?

  private let defaults: UserDefaults
  private let locationManager = CLLocationManager()
  private let cityGeocoder = CLGeocoder()
  private let reverseGeocoder = CLGeocoder()
  private let searchCompleter = MKLocalSearchCompleter()
  private var coordinate: GeographicCoordinate?
  private var locationTimeZone = TimeZone.current
  private var scheduledNotificationKey: String?
  private var timer: Timer?
  private var isLoadingDefaults = true
  private var isApplyingCitySuggestion = false

  private enum DefaultsKey {
    static let locationSource = "locationSource"
    static let manualCity = "manualCity"
    static let manualLatitude = "manualLatitude"
    static let manualLongitude = "manualLongitude"
    static let manualTimeZoneIdentifier = "manualTimeZoneIdentifier"
    static let notificationEnabled = "notificationEnabled"
    static let notificationThresholdMinutes = "notificationThresholdMinutes"
  }

  override init() {
    defaults = .standard
    super.init()

    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    searchCompleter.delegate = self
    searchCompleter.resultTypes = [.address]

    loadDefaults()
    isLoadingDefaults = false
    activateLocationSource()
    startClock()
  }

  deinit {
    timer?.invalidate()
  }

  var menuBarTitle: String {
    guard let sunlight else {
      return "☀️ Set"
    }

    let remaining = sunlight.remaining(at: now)
    let icon = remaining > 0 ? "☀️" : "🌙"
    return "\(icon) \(DaylightTimeFormatter.compactRemaining(remaining))"
  }

  var sunsetText: String {
    guard let sunlight else {
      return "--"
    }

    return formatTime(sunlight.sunset)
  }

  var sunriseText: String {
    guard let sunlight else {
      return "--"
    }

    return formatTime(sunlight.sunrise)
  }

  var currentTimeText: String {
    formatTime(now)
  }

  var remainingText: String {
    guard let sunlight else {
      return "--"
    }

    return DaylightTimeFormatter.compactRemaining(sunlight.remaining(at: now))
  }

  var consumedFraction: Double {
    sunlight?.consumedFraction(at: now) ?? 0
  }

  var daylightMessage: String {
    sunlight?.daylightMessage(at: now) ?? "Tell me where you are and I will tell you how much day is left."
  }

  var thresholdOptions: [Int] {
    [30, 60, 90, 120]
  }

  func requestCurrentLocation() {
    if locationSource != .current {
      locationSource = .current
      return
    }

    let status = locationManager.authorizationStatus

    switch status {
    case .notDetermined:
      locationStatus = "macOS will ask for location permission."
      locationManager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      locationStatus = "Finding sunset for your current location..."
      locationManager.requestLocation()
    case .denied, .restricted:
      locationStatus = "Location is blocked. Choose a city manually."
    @unknown default:
      locationStatus = "I cannot read the location permission."
    }
  }

  func applyManualCity() {
    let city = manualCityInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !city.isEmpty else {
      locationStatus = "Enter a city."
      return
    }

    if locationSource != .manual {
      locationSource = .manual
      return
    }

    isResolvingCity = true
    locationStatus = "Finding coordinates for \(city)..."

    cityGeocoder.cancelGeocode()
    cityGeocoder.geocodeAddressString(city) { [weak self] placemarks, error in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isResolvingCity = false

        if let error {
          self.locationStatus = "I could not find that city: \(error.localizedDescription)"
          return
        }

        guard let placemark = placemarks?.first, let location = placemark.location else {
          self.locationStatus = "I could not find that city."
          return
        }

        self.setCoordinate(
          GeographicCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
          ),
          displayName: self.displayName(for: placemark, fallback: city),
          timeZone: placemark.timeZone,
          persistManual: true
        )
      }
    }
  }

  func chooseCitySuggestion(_ suggestion: CitySuggestion) {
    isApplyingCitySuggestion = true
    manualCityInput = suggestion.displayTitle
    isApplyingCitySuggestion = false
    clearCitySuggestions()
    applyManualCity()
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func loadDefaults() {
    if let rawSource = defaults.string(forKey: DefaultsKey.locationSource),
       let source = LocationSource(rawValue: rawSource),
       source == .manual {
      locationSource = source
    } else {
      locationSource = .manual
    }

    manualCityInput = defaults.string(forKey: DefaultsKey.manualCity) ?? ""

    let savedTimeZone = defaults.string(forKey: DefaultsKey.manualTimeZoneIdentifier)
      .flatMap(TimeZone.init(identifier:))
    let savedLatitude = defaults.object(forKey: DefaultsKey.manualLatitude) as? Double
    let savedLongitude = defaults.object(forKey: DefaultsKey.manualLongitude) as? Double
    if let savedLatitude, let savedLongitude, let savedTimeZone, locationSource == .manual {
      coordinate = GeographicCoordinate(latitude: savedLatitude, longitude: savedLongitude)
      locationTimeZone = savedTimeZone
      displayLocation = manualCityInput.isEmpty ? "Saved city" : manualCityInput
      locationStatus = "Sunset calculated locally."
      refreshSunlight()
    } else if locationSource == .manual, !manualCityInput.isEmpty {
      displayLocation = manualCityInput
    }

    notificationEnabled = defaults.bool(forKey: DefaultsKey.notificationEnabled)
    let savedThreshold = defaults.integer(forKey: DefaultsKey.notificationThresholdMinutes)
    if savedThreshold > 0 {
      notificationThresholdMinutes = savedThreshold
    }
  }

  private func activateLocationSource() {
    guard !isLoadingDefaults else { return }

    switch locationSource {
    case .current:
      requestCurrentLocation()
    case .manual:
      updateCitySuggestions(for: manualCityInput)
      if let coordinate {
        setCoordinate(
          coordinate,
          displayName: displayLocation,
          timeZone: locationTimeZone,
          persistManual: false
        )
      } else if !manualCityInput.isEmpty {
        applyManualCity()
      } else {
        sunlight = nil
        locationStatus = "Enter a city for local calculation."
      }
    }
  }

  private func setCoordinate(
    _ coordinate: GeographicCoordinate,
    displayName: String,
    timeZone: TimeZone?,
    persistManual: Bool
  ) {
    self.coordinate = coordinate
    locationTimeZone = timeZone ?? .current
    displayLocation = displayName
    locationStatus = "Sunset calculated locally."

    if persistManual {
      isApplyingCitySuggestion = true
      manualCityInput = displayName
      isApplyingCitySuggestion = false
      defaults.set(displayName, forKey: DefaultsKey.manualCity)
      defaults.set(coordinate.latitude, forKey: DefaultsKey.manualLatitude)
      defaults.set(coordinate.longitude, forKey: DefaultsKey.manualLongitude)
      defaults.set(locationTimeZone.identifier, forKey: DefaultsKey.manualTimeZoneIdentifier)
    }

    clearCitySuggestions()
    refreshSunlight()
  }

  private func updateCitySuggestions(for query: String) {
    guard locationSource == .manual else {
      clearCitySuggestions()
      return
    }

    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedQuery.count >= 2 else {
      clearCitySuggestions()
      return
    }

    searchCompleter.queryFragment = trimmedQuery
  }

  private func displayName(for placemark: CLPlacemark, fallback: String) -> String {
    placemark.locality
      ?? placemark.administrativeArea
      ?? placemark.name
      ?? fallback
  }

  private func clearCitySuggestions() {
    citySuggestions = []
    searchCompleter.queryFragment = ""
  }

  private func refreshSunlight() {
    now = Date()

    guard let coordinate else {
      sunlight = nil
      return
    }

    sunlight = SunCalculator.sunlightInterval(
      on: now,
      coordinate: coordinate,
      calendar: calculationCalendar
    )
    if sunlight == nil {
      locationStatus = "The sun does not have a normal sunset here today."
    }
    updateNotificationSchedule()
  }

  private func startClock() {
    timer?.invalidate()

    let clockTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickClock()
      }
    }
    RunLoop.main.add(clockTimer, forMode: .common)
    timer = clockTimer
  }

  private func tickClock() {
    let previousDay = calculationCalendar.startOfDay(for: now)
    now = Date()

    if calculationCalendar.startOfDay(for: now) != previousDay {
      refreshSunlight()
    }
  }

  private func updateNotificationSchedule() {
    guard notificationEnabled, let coordinate else {
      scheduledNotificationKey = nil
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: [NotificationID.daylightWarning]
      )
      return
    }

    guard let target = nextNotificationTarget(coordinate: coordinate) else {
      return
    }

    let key = "\(notificationThresholdMinutes)-\(Int(target.timeIntervalSince1970 / 60))"
    guard key != scheduledNotificationKey else {
      return
    }

    scheduledNotificationKey = key
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [NotificationID.daylightWarning]
    )

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
      guard granted else { return }

      Task { @MainActor in
        self?.scheduleNotification(at: target)
      }
    }
  }

  private func scheduleNotification(at target: Date) {
    guard notificationEnabled else { return }

    let content = UNMutableNotificationContent()
    content.title = "\(notificationThresholdTitle) of daylight left"
    content.body = "Sundown thinks you should go outside now."
    content.sound = .default

    let interval = max(1, target.timeIntervalSinceNow)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(
      identifier: NotificationID.daylightWarning,
      content: content,
      trigger: trigger
    )

    UNUserNotificationCenter.current().add(request)
  }

  private func nextNotificationTarget(coordinate: GeographicCoordinate) -> Date? {
    let calendar = calculationCalendar
    let today = Date()
    let targetToday = notificationTarget(on: today, coordinate: coordinate, calendar: calendar)
    return targetToday.flatMap { $0 > today ? $0 : nil }
      ?? calendar.date(byAdding: .day, value: 1, to: today)
        .flatMap { notificationTarget(on: $0, coordinate: coordinate, calendar: calendar) }
  }

  private func notificationTarget(
    on date: Date,
    coordinate: GeographicCoordinate,
    calendar: Calendar
  ) -> Date? {
    SunCalculator.sunlightInterval(on: date, coordinate: coordinate, calendar: calendar)?
      .sunset
      .addingTimeInterval(TimeInterval(-notificationThresholdMinutes * 60))
  }

  private var notificationThresholdTitle: String {
    if notificationThresholdMinutes == 60 {
      return "1h"
    }

    return "\(notificationThresholdMinutes)m"
  }

  private var calculationCalendar: Calendar {
    var calendar = Calendar.current
    calendar.timeZone = locationTimeZone
    return calendar
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    formatter.timeZone = locationTimeZone
    return formatter.string(from: date)
  }

  private enum NotificationID {
    static let daylightWarning = "sundown.daylight-warning"
  }

}

extension DaylightModel: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      self.handleAuthorizationChange(status: manager.authorizationStatus)
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let latest = locations.last else { return }

    Task { @MainActor in
      self.handleLocation(latest)
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      self.locationStatus = "I cannot read your location: \(error.localizedDescription)"
    }
  }

  private func handleAuthorizationChange(status: CLAuthorizationStatus) {
    guard locationSource == .current else { return }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      locationStatus = "Finding sunset for your current location..."
      locationManager.requestLocation()
    case .denied, .restricted:
      locationStatus = "Location is blocked. Choose a city manually."
    case .notDetermined:
      break
    @unknown default:
      locationStatus = "I cannot read the location permission."
    }
  }

  private func handleLocation(_ location: CLLocation) {
    let coordinate = GeographicCoordinate(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude
    )
    setCoordinate(
      coordinate,
      displayName: "Current location",
      timeZone: .current,
      persistManual: false
    )
    reverseGeocodeLocation(location)
  }

  private func reverseGeocodeLocation(_ location: CLLocation) {
    reverseGeocoder.cancelGeocode()
    reverseGeocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
      DispatchQueue.main.async {
        guard let self else { return }
        let name = placemarks?.first?.locality
          ?? placemarks?.first?.administrativeArea
          ?? "Current location"
        self.displayLocation = name
        if let timeZone = placemarks?.first?.timeZone {
          self.locationTimeZone = timeZone
          self.refreshSunlight()
        }
      }
    }
  }
}

extension DaylightModel: MKLocalSearchCompleterDelegate {
  nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    let suggestions = completer.results.prefix(5).map {
      CitySuggestion(title: $0.title, subtitle: $0.subtitle)
    }

    Task { @MainActor in
      self.citySuggestions = suggestions
    }
  }

  nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    Task { @MainActor in
      self.citySuggestions = []
    }
  }
}
