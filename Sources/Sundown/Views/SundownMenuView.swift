import SwiftUI

struct SundownMenuView: View {
  @ObservedObject var model: DaylightModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      remainingHero
      DaylightTimelineView(
        sunriseText: model.sunriseText,
        currentTimeText: model.currentTimeText,
        sunsetText: model.sunsetText,
        remainingText: model.remainingText,
        consumedFraction: model.consumedFraction
      )
      sunTimesSummary
      messageBlock
      Divider()
      locationSearch
      Divider()
      notificationControls
      Divider()
      footer
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.ultraThinMaterial)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Sundown")
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .lineLimit(1)

      Text(model.displayLocation)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private var remainingHero: some View {
    HStack(alignment: .center, spacing: 14) {
      Image(systemName: "sun.max.fill")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(.orange)
        .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: -2) {
        Text(model.remainingText)
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        Text("daylight left today")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity)
    .frame(minHeight: 86, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.thinMaterial)
        .overlay {
          LinearGradient(
            colors: [
              Color.orange.opacity(0.18),
              Color.yellow.opacity(0.08),
              Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.orange.opacity(0.22), lineWidth: 1)
    }
  }

  private var sunTimesSummary: some View {
    HStack(spacing: 10) {
      Label(model.sunriseText, systemImage: "sunrise.fill")
      Spacer()
      Label(model.sunsetText, systemImage: "sunset.fill")
    }
    .font(.system(size: 12, weight: .semibold, design: .rounded))
    .monospacedDigit()
    .foregroundStyle(.orange.opacity(0.78))
    .labelStyle(.titleAndIcon)
  }

  private var messageBlock: some View {
    Text(model.daylightMessage)
      .font(.system(size: 14, weight: .medium, design: .rounded))
      .fixedSize(horizontal: false, vertical: true)
  }

  private var locationSearch: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Location")
        .font(.system(size: 14, weight: .semibold, design: .rounded))

      HStack(spacing: 9) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        TextField("Search city", text: $model.manualCityInput)
          .textFieldStyle(.plain)
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .onSubmit {
            model.applyManualCity()
          }

        Button {
          model.applyManualCity()
        } label: {
          if model.isResolvingCity {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "arrow.right.circle.fill")
              .font(.system(size: 18, weight: .semibold))
          }
        }
        .buttonStyle(.borderless)
        .disabled(model.isResolvingCity)
        .help("Set city")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.thinMaterial)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.quaternary, lineWidth: 1)
      }

      if !model.citySuggestions.isEmpty {
        citySuggestionList
      }
    }
  }

  private var citySuggestionList: some View {
    VStack(alignment: .leading, spacing: 1) {
      ForEach(model.citySuggestions) { suggestion in
        Button {
          model.chooseCitySuggestion(suggestion)
        } label: {
          HStack(spacing: 9) {
            Image(systemName: "mappin.circle.fill")
              .foregroundStyle(.secondary)
              .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
              Text(suggestion.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)

              if !suggestion.subtitle.isEmpty {
                Text(suggestion.subtitle)
                  .font(.system(size: 11, weight: .semibold, design: .rounded))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }

            Spacer(minLength: 0)
          }
          .contentShape(Rectangle())
          .padding(.horizontal, 4)
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var notificationControls: some View {
    HStack(spacing: 10) {
      Image(systemName: "bell")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 20)

      Text("Reminder")
        .font(.system(size: 15, weight: .medium, design: .rounded))

      Spacer()

      Picker("", selection: notificationSelection) {
        Text("No reminder").tag(0)
        ForEach(model.thresholdOptions, id: \.self) { minutes in
          Text(thresholdLabel(minutes)).tag(minutes)
        }
      }
      .labelsHidden()
      .frame(width: 142)
    }
  }

  private var notificationSelection: Binding<Int> {
    Binding {
      model.notificationEnabled ? model.notificationThresholdMinutes : 0
    } set: { minutes in
      if minutes == 0 {
        model.notificationEnabled = false
      } else {
        model.notificationThresholdMinutes = minutes
        model.notificationEnabled = true
      }
    }
  }

  private var footer: some View {
    HStack {
      Spacer()

      Button(role: .destructive) {
        model.quit()
      } label: {
        Label("Quit", systemImage: "power")
          .font(.system(size: 14, weight: .semibold, design: .rounded))
      }
      .buttonStyle(.borderless)
    }
  }

  private func thresholdLabel(_ minutes: Int) -> String {
    switch minutes {
    case 60:
      return "1h before"
    case 90:
      return "1h30m before"
    case 120:
      return "2h before"
    default:
      return "\(minutes)m before"
    }
  }
}

private struct DaylightTimelineView: View {
  let sunriseText: String
  let currentTimeText: String
  let sunsetText: String
  let remainingText: String
  let consumedFraction: Double

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var displayedProgress = 0.0

  private var progress: Double {
    min(max(consumedFraction, 0), 1)
  }

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let markerX = width * displayedProgress
      let clampedMarkerX = min(max(markerX, 34), width - 34)

      ZStack(alignment: .topLeading) {
        timelineBar(width: width)
          .position(x: width / 2, y: 16)

        tickMarks(width: width)
          .position(x: width / 2, y: 31)

        marker
          .position(x: clampedMarkerX, y: 40)
      }
    }
    .frame(height: 78)
    .onAppear {
      displayedProgress = reduceMotion ? progress : 0
      guard !reduceMotion else { return }

      withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
        displayedProgress = progress
      }
    }
    .onChange(of: progress) { _, newProgress in
      if reduceMotion {
        displayedProgress = newProgress
      } else {
        withAnimation(.linear(duration: 0.2)) {
          displayedProgress = newProgress
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Daylight remaining \(remainingText), current time \(currentTimeText), sunrise \(sunriseText), sunset \(sunsetText)"
    )
  }

  private func timelineBar(width: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(.secondary.opacity(0.18))

      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(
          LinearGradient(
            colors: [.orange, .yellow.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: max(8, width * displayedProgress))
    }
    .frame(width: width, height: 9)
  }

  private func tickMarks(width: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0..<17, id: \.self) { index in
        Rectangle()
          .fill(.secondary.opacity(index % 4 == 0 ? 0.75 : 0.45))
          .frame(width: 1, height: index % 4 == 0 ? 12 : 6)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(width: width)
  }

  private var marker: some View {
    VStack(spacing: 4) {
      Circle()
        .fill(.primary.opacity(0.82))
        .frame(width: 5, height: 5)

      Rectangle()
        .fill(.primary.opacity(0.82))
        .frame(width: 1.5, height: 22)

      Text(currentTimeText)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.regularMaterial)
        }
        .overlay {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(.quaternary, lineWidth: 1)
        }
    }
  }

}
