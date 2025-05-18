import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = UVDataManager()
    @State private var currentTime = Date() // For live clock, if needed

    // Define arc properties for unified use
    private let arcStartAngle: Angle = .degrees(135) // 12 AM at top-left
    private let arcEndAngle: Angle = .degrees(135 + 270) // Sweeps 270 degrees clockwise
    private let arcTrimStart: CGFloat = 0.0
    private let arcTrimEnd: CGFloat = 0.75 // (135 + 270 - 135) / 360 = 270/360 = 0.75

    // Labels to be positioned along the arc (12AM to 6PM)
    private let arcTimeLabels: [TimeLabelInfo] = [
        TimeLabelInfo(hour: 0, label: "12AM"),
        TimeLabelInfo(hour: 3, label: "3AM"),
        TimeLabelInfo(hour: 6, label: "6AM"),
        TimeLabelInfo(hour: 9, label: "9AM"),
        TimeLabelInfo(hour: 12, label: "12PM"),
        TimeLabelInfo(hour: 15, label: "3PM"),
        TimeLabelInfo(hour: 18, label: "6PM") // Ends at top-right
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) { // Use ZStack for easier layering and positioning of 9PM label
                VStack { // Keep existing VStack for primary content if needed, or simplify
                    // Temperature Display (example, adjust as needed)
                    Text(dataManager.currentUVData?.temperature ?? " --°F")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : 20) // Adjust top padding

                    Spacer() // Pushes arc and text to center vertically
                }

                // Arc and its labels group
                ZStack {
                    // Background Arc
                    Circle()
                        .trim(from: arcTrimStart, to: arcTrimEnd)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                        .rotationEffect(arcStartAngle)
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)

                    // Colored UV Forecast Arc
                    Circle()
                        .trim(from: arcTrimStart, to: arcTrimEnd)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: generateGradientStops(for: dataManager.forecastData?.hourly ?? [], geometry: geometry)),
                                center: .center,
                                angle: arcStartAngle
                            ),
                            style: StrokeStyle(lineWidth: 15, lineCap: .butt)
                        )
                        .rotationEffect(arcStartAngle)
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)

                    // Central UV Display
                    VStack {
                        Text("\(Int(dataManager.currentUVData?.uvIndex.rounded() ?? 0))")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(uvColor(for: dataManager.currentUVData?.uvIndex ?? 0))
                        Text(dataManager.currentUVData?.uvDescription ?? "Low")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(uvColor(for: dataManager.currentUVData?.uvIndex ?? 0))
                        if let uvIndex = dataManager.currentUVData?.uvIndex, uvIndex >= 3 {
                            Text("Apply sunscreen now")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.top, 2)
                        }
                    }
                    .offset(y: geometry.size.height * 0.01) // Slight adjustment if needed

                    // Time Labels along the arc (12AM - 6PM)
                    ForEach(arcTimeLabels) { labelInfo in
                        Text(labelInfo.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .position(positionOnArc(forHour: labelInfo.hour, in: geometry.size, radius: geometry.size.width * 0.35 + 25))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height * 0.7) // Constrain arc group size

                // Manually Positioned "9PM" Label
                Text("9PM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .position(
                        x: geometry.size.width / 2 - (geometry.size.width * 0.08), // Adjusted for "bottom-center-ish, but a bit left"
                        y: geometry.size.height * 0.80 // Lower part of the screen
                    )
                
                // Manually Positioned "9AM" Label to match image more closely
                // This overrides the one from arcTimeLabels if its positioning isn't quite right.
                // For simplicity, I'll adjust its definition in arcTimeLabels and positionOnArc first.
                // If still needed, one could do:
                // Text("9AM")
                //     .font(.system(size: 10, weight: .medium))
                //     .foregroundColor(.gray)
                //     .position(
                //         x: geometry.size.width / 2, // Centered
                //         y: geometry.size.height * 0.5 + (geometry.size.width * 0.35 + 10) // Below arc bottom
                //     )


            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .onAppear {
                // dataManager.loadData() // If you have a load function
            }
        }
    }

    private func generateGradientStops(for hourlyData: [HourlyUVForecast], geometry: GeometryProxy) -> [Gradient.Stop] {
        guard !hourlyData.isEmpty else {
            return [Gradient.Stop(color: .green, location: 0.0), Gradient.Stop(color: .green, location: 1.0)]
        }

        var stops: [Gradient.Stop] = []
        // This maps the 24-hour forecast data to the 0.0-1.0 range of the arc.
        let totalHoursInDataCycle = 24.0

        for (index, forecast) in hourlyData.enumerated() {
            let forecastHour = Calendar.current.component(.hour, from: forecast.time)
            let forecastMinute = Calendar.current.component(.minute, from: forecast.time)
            let hourAsDecimal = CGFloat(forecastHour) + CGFloat(forecastMinute) / 60.0

            let locationInArc = hourAsDecimal / totalHoursInDataCycle // Map 24h data to 0-1 gradient
            let color = uvColor(for: forecast.uvIndex)
            
            // Ensure sharp transitions by adding previous color stop if color changes
            if index > 0 {
                let prevColor = uvColor(for: hourlyData[index-1].uvIndex)
                if color != prevColor {
                    let prevForecastHour = Calendar.current.component(.hour, from: hourlyData[index-1].time)
                    let prevForecastMinute = Calendar.current.component(.minute, from: hourlyData[index-1].time)
                    let prevHourAsDecimal = CGFloat(prevForecastHour) + CGFloat(prevForecastMinute) / 60.0
                    // Add previous color stop just before the new color starts
                    stops.append(Gradient.Stop(color: prevColor, location: max(0, locationInArc - 0.0001)))
                }
            } else { // For the very first stop
                 stops.append(Gradient.Stop(color: color, location: 0.0))
            }
            stops.append(Gradient.Stop(color: color, location: locationInArc))
        }
        
        // Ensure the gradient starts at 0.0 and ends at 1.0
        if stops.first?.location != 0.0 {
            stops.insert(Gradient.Stop(color: stops.first?.color ?? .green, location: 0.0), at: 0)
        }
        if let lastStop = stops.last, lastStop.location < 1.0 {
            stops.append(Gradient.Stop(color: lastStop.color, location: 1.0))
        }
        
        // Deduplicate and sort
        var uniqueStops: [Gradient.Stop] = []
        if !stops.isEmpty {
            uniqueStops.append(stops[0])
            for i in 1..<stops.count {
                if stops[i].location > uniqueStops.last!.location { // Ensure location strictly increases
                    uniqueStops.append(stops[i])
                } else if stops[i].location == uniqueStops.last!.location { // Same location, replace
                    uniqueStops[uniqueStops.count - 1] = stops[i]
                }
                // else, if stops[i].location < uniqueStops.last!.location, it's a disorder, could happen from tiny negative offset, filter by sorting later
            }
        }
        // Final sort to handle any misordering from adding prevColor stops precisely
        uniqueStops.sort { $0.location < $1.location }
        // Another pass to remove duplicates that might have been created by sorting
        var finalStops: [Gradient.Stop] = []
        if !uniqueStops.isEmpty {
            finalStops.append(uniqueStops[0])
            for i in 1..<uniqueStops.count {
                if uniqueStops[i].location > finalStops.last!.location {
                     finalStops.append(uniqueStops[i])
                } else { // if same, overwrite with current one.
                    finalStops[finalStops.count-1] = uniqueStops[i]
                }
            }
        }

        return finalStops.isEmpty ? [Gradient.Stop(color: .gray, location: 0.0), Gradient.Stop(color: .gray, location: 1.0)] : finalStops
    }

    // Calculates position for labels 12AM (hour 0) to 6PM (hour 18) along the arc
    private func positionOnArc(forHour hour: Int, in size: CGSize, radius: CGFloat) -> CGPoint {
        // The arc visually represents 18 hours (12AM to 6PM)
        let totalHoursOnArcVisual = 18.0
        
        // Ensure hour is within the expected 0-18 range for this function
        let hourOn18HourScale = CGFloat(max(0, min(hour, Int(totalHoursOnArcVisual))))

        // Proportion of the 18-hour visual arc
        let proportionOfArc = hourOn18HourScale / totalHoursOnArcVisual

        // Calculate the angle for this hour along the 270-degree sweep, starting from arcStartAngle
        let angleInDegrees = arcStartAngle.degrees + proportionOfArc * 270.0
        let angleInRadians = Angle(degrees: angleInDegrees).radians

        let centerX = size.width / 2
        let centerY = size.height / 2 // Assuming arc group is centered

        let x = centerX + radius * cos(CGFloat(angleInRadians))
        let y = centerY + radius * sin(CGFloat(angleInRadians))
        return CGPoint(x: x, y: y)
    }

    private func uvColor(for index: Double) -> Color {
        let uv = Int(index.rounded())
        switch uv {
        case 0...2:
            return .green
        case 3...5:
            return .yellow
        case 6...7:
            return .orange
        case 8...10:
            return .red
        case 11...:
            return .purple
        default:
            return .gray
        }
    }
}

struct TimeLabelInfo: Identifiable {
    let id = UUID()
    let hour: Int // Hour (0-23 for data, 0-18 for arc label context)
    let label: String
}

// Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif 