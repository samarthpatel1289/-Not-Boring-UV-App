import SwiftUI

// MARK: - Simplified Models for API Data
struct SimplifiedUVData: Codable {
    let uv: Double
    let uvTime: String // ISO Date string for current reading
}

struct SimplifiedHourlyUVForecast: Codable {
    let uv: Double
    let uvTime: String // ISO Date string for forecast point
}

// MARK: - Data Manager (Singleton)
class UVDataManager {
    static let shared = UVDataManager()

    let currentUVData: SimplifiedUVData
    let forecastData: [SimplifiedHourlyUVForecast]

    private init() {
        currentUVData = SimplifiedUVData(
            uv: 6.4984, // Current UV is 6 (High) - for central display
            uvTime: "2025-05-13T16:30:00.000Z" // Current time for display: 4:30 PM
        )

        // Full 24-hour forecast data
        forecastData = [
            .init(uv: 0.0, uvTime: "2025-05-13T00:00:00.000Z"), // 12 AM (Green)
            .init(uv: 0.0, uvTime: "2025-05-13T03:00:00.000Z"), // 3 AM  (Green)
            .init(uv: 0.5, uvTime: "2025-05-13T06:00:00.000Z"), // 6 AM  (Green)
ca            .init(uv: 5.5, uvTime: "2025-05-13T12:00:00.000Z"), // 12 PM (Orange)
            .init(uv: 7.5, uvTime: "2025-05-13T13:30:00.000Z"), // 1:30 PM (Orange/Red cusp)
            .init(uv: 8.5, uvTime: "2025-05-13T14:30:00.000Z"), // 2:30 PM (Red)
            .init(uv: 6.0, uvTime: "2025-05-13T16:30:00.000Z"), // 4:30 PM (Orange) - current time in example
            .init(uv: 3.0, uvTime: "2025-05-13T18:30:00.000Z"), // 6:30 PM (Yellow)
            .init(uv: 0.8, uvTime: "2025-05-13T21:00:00.000Z"), // 9 PM  (Green)
            .init(uv: 0.0, uvTime: "2025-05-13T23:59:00.000Z")  // 11:59 PM (Green)
        ].sorted { (UVDataManager.getFractionalHour(from: $0.uvTime) ?? 0) < (UVDataManager.getFractionalHour(from: $1.uvTime) ?? 0) }
    }

    // Static helper, as it's used in init for sorting
    static func getFractionalHour(from isoDateString: String) -> Double? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDateString) {
            return Double(Calendar.current.component(.hour, from: date)) + Double(Calendar.current.component(.minute, from: date)) / 60.0
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoDateString) {
            return Double(Calendar.current.component(.hour, from: date)) + Double(Calendar.current.component(.minute, from: date)) / 60.0
        }
        print("Failed to parse date: \(isoDateString)")
        return nil
    }
}

// Data structure for time labels around the dial
struct TimeLabelInfo: Identifiable {
    let id = UUID()
    let text: String
    let hour: Double // Hour value (0-23) for positioning
}

struct ContentView: View {
    private let dataManager = UVDataManager.shared
    @State private var temperature = "91°F"
    
    private let dialRadius: CGFloat = 160 // Half of 320 frame
    private let labelOffsetRadius: CGFloat = 190 // Distance from center to labels

    private let timeLabels: [TimeLabelInfo] = [
        TimeLabelInfo(text: "12AM", hour: 0),
        TimeLabelInfo(text: "3AM", hour: 3),
        TimeLabelInfo(text: "6AM", hour: 6),
        TimeLabelInfo(text: "9AM", hour: 9),
        TimeLabelInfo(text: "12PM", hour: 12),
        TimeLabelInfo(text: "3PM", hour: 15),
        TimeLabelInfo(text: "6PM", hour: 18),
        TimeLabelInfo(text: "9PM", hour: 21)
    ]

    private var currentDisplayUV: Int {
        Int(dataManager.currentUVData.uv.rounded())
    }

    private func uvColor(for uvValue: Double) -> Color {
        switch Int(uvValue.rounded()) {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple // Added purple for UV 11+
        }
    }

    private func uvSeverityText(for uvValue: Double) -> String {
        switch Int(uvValue.rounded()) {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    private func generateGradientStops() -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        let arcPhysicalStart = 0.125 // Corresponds to 12:00 AM on the rotated C arc
        let arcPhysicalEnd = 0.875   // Corresponds to 11:59 PM on the rotated C arc
        let arcPhysicalSpan = arcPhysicalEnd - arcPhysicalStart

        guard !dataManager.forecastData.isEmpty else { return [] }

        // Process each forecast entry to create a stop
        for entry in dataManager.forecastData {
            guard let forecastHour = UVDataManager.getFractionalHour(from: entry.uvTime) else { continue }
            
            let locationOnArc = arcPhysicalStart + (forecastHour / 24.0) * arcPhysicalSpan
            let clampedLocation = max(arcPhysicalStart, min(arcPhysicalEnd, locationOnArc))
            let color = uvColor(for: entry.uv)
            
            stops.append(Gradient.Stop(color: color, location: clampedLocation))
        }

        // Ensure the gradient visually starts at arcPhysicalStart and ends at arcPhysicalEnd
        // by adding/adjusting stops at these exact boundaries if not already present.
        let firstForecastUV = dataManager.forecastData.first?.uv ?? 0
        let firstColor = uvColor(for: firstForecastUV)
        if stops.first?.location ?? (arcPhysicalStart + 0.01) > arcPhysicalStart {
            stops.insert(Gradient.Stop(color: firstColor, location: arcPhysicalStart), at: 0)
        } else if let first = stops.first, first.location == arcPhysicalStart, first.color != firstColor {
             stops[0] = Gradient.Stop(color: firstColor, location: arcPhysicalStart) // Correct color if location exists
        }

        let lastForecastUV = dataManager.forecastData.last?.uv ?? 0
        let lastColor = uvColor(for: lastForecastUV)
        if stops.last?.location ?? (arcPhysicalEnd - 0.01) < arcPhysicalEnd {
            stops.append(Gradient.Stop(color: lastColor, location: arcPhysicalEnd))
        } else if let last = stops.last, last.location == arcPhysicalEnd, last.color != lastColor {
            stops[stops.count-1] = Gradient.Stop(color: lastColor, location: arcPhysicalEnd) // Correct color
        }
        
        // Deduplicate based on location (keeping the color of the later entry if locations are nearly identical)
        // and sort. AngularGradient requires sorted locations.
        var uniqueStops: [Gradient.Stop] = []
        if !stops.isEmpty {
            uniqueStops.append(stops.first!)
            for i in 1..<stops.count {
                // If current stop is at a new location, add it.
                // If at same location as last unique stop, only add if color differs (preferring the new color).
                if abs(stops[i].location - uniqueStops.last!.location) > 0.0001 {
                    uniqueStops.append(stops[i])
                } else if stops[i].color != uniqueStops.last!.color {
                    uniqueStops[uniqueStops.count-1] = stops[i] // Update to new color at same micro-location
                }
            }
        }
        return uniqueStops.sorted { $0.location < $1.location }
    }

    // Calculate position for a time label
    private func position(for hour: Double, radius: CGFloat) -> CGPoint {
        // Map hour (0-23.99) to an angle on the C-arc.
        // Arc starts at 135 degrees (for 00:00) and goes CCW to 45 degrees (for 24:00).
        // Total visual arc span is 270 degrees.
        // Angle for layout: 0 is right, 90 is top (standard math).
        let proportionOfDay = hour / 24.0
        // Angle decreases from 135 as hour increases.
        let angleDegrees = 135.0 - (proportionOfDay * 270.0)
        let angleRadians = angleDegrees * .pi / 180.0
        
        return CGPoint(x: radius * cos(angleRadians),
                       y: -radius * sin(angleRadians)) // Negative Y for SwiftUI top-positive coordinates
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 40) {
                Text(temperature)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                Spacer()
                ZStack {
                    // Background full-day arc (12 AM to 11:59 PM)
                    Circle()
                        .trim(from: 0.125, to: 0.875)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: dialRadius * 2, height: dialRadius * 2)
                        .rotationEffect(.degrees(90))

                    // Colored arc: Full day forecast
                    Circle()
                        .trim(from: 0.125, to: 0.875) 
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: generateGradientStops()),
                                center: .center,
                                startAngle: .degrees(0), // Gradient starts at the right (3 o'clock)
                                endAngle: .degrees(360)   // Gradient ends at the right (3 o'clock)
                            ),
                            style: StrokeStyle(lineWidth: 25, lineCap: .butt) 
                        )
                        .frame(width: dialRadius * 2, height: dialRadius * 2)
                        .rotationEffect(.degrees(90)) // Aligns arc start to bottom-left

                    // Time Labels around the dial
                    ForEach(timeLabels) { labelInfo in
                        let pos = position(for: labelInfo.hour, radius: labelOffsetRadius)
                        Text(labelInfo.text)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .position(x: (dialRadius * 2 / 2) + pos.x, y: (dialRadius * 2 / 2) + pos.y)
                    }
                    .frame(width: dialRadius * 2, height: dialRadius * 2) // ForEach positioning context

                    // Center UV information (shows CURRENT UV)
                    VStack(spacing: 12) {
                        Text("\(currentDisplayUV)")
                            .font(.system(size: 100, weight: .bold)).foregroundColor(.white)
                        Text(uvSeverityText(for: Double(currentDisplayUV)))
                            .font(.system(size: 36, weight: .medium)).foregroundColor(uvColor(for: Double(currentDisplayUV)))
                        if currentDisplayUV > 3 {
                            Text("Apply sunscreen now")
                                .font(.system(size: 20)).foregroundColor(.white.opacity(0.7)).padding(.top, 10)
                        }
                    }
                }
                .frame(width: dialRadius * 2, height: dialRadius * 2) // Ensure ZStack has a defined size for .position
                
                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
