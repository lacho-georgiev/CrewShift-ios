import Foundation
import SwiftUI

import Foundation
import SwiftUI

// MARK: - Data Models

// Flight model
struct Flight: Identifiable, Codable, Equatable {
    var id: String { duty }
    var duty: String
    var departure: String
    var arrival: String
    var depTime: String
    var arrivalTime: String
    var checkIn: String?
    var checkOut: String?
    var aircraft: String
    var cockpit: String
    var cabin: String
    
    enum CodingKeys: String, CodingKey {
        case duty = "Duty"
        case departure = "Departure"
        case arrival = "Arrival"
        case depTime = "DepTime"
        case arrivalTime = "ArrivalTime"
        case checkIn = "CheckIn"
        case checkOut = "CheckOut"
        case aircraft = "Aircraft"
        case cockpit = "Cockpit"
        case cabin = "Cabin"
    }
    
    static func == (lhs: Flight, rhs: Flight) -> Bool {
        return lhs.duty == rhs.duty &&
               lhs.departure == rhs.departure &&
               lhs.arrival == rhs.arrival &&
               lhs.depTime == rhs.depTime &&
               lhs.arrivalTime == rhs.arrivalTime
    }
}

// Day model for individual days in the schedule
struct DayData: Identifiable, Codable, Equatable {
    var id: String { individualDay }
    var individualDay: String
    var date: String?
    var ftBlh: String?
    var fdt: String?
    var dt: String?
    var rp: String?
    var duty: String?  // Making duty optional since it's not always present
    var flights: [Flight]?
    
    enum CodingKeys: String, CodingKey {
        case individualDay = "IndividualDay"
        case duty = "Duty"
        case flights = "Flights"
        case date = "Date"
        case ftBlh = "FT_BLH"
        case fdt = "FDT"
        case dt = "DT"
        case rp = "RP"
    }
    
    static func == (lhs: DayData, rhs: DayData) -> Bool {
        return lhs.individualDay == rhs.individualDay
    }
    
    // Duty accessor that handles when duty isn't explicitly provided
    func getDutyType() -> String {
        if let explicitDuty = duty {
            return explicitDuty
        }
        
        if let flights = flights, !flights.isEmpty {
            return "Flight"
        }
        
        return "Unknown"
    }
}

// Calendar day model for UI
struct CalendarDay: Identifiable, Hashable {
    var id: String { "\(date)-\(month)-\(isCurrentMonth)" }
    var date: Int
    var month: Int
    var isCurrentMonth: Bool
    var flightStatus: FlightStatus = .none
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        return lhs.id == rhs.id
    }
}

// Flight status types for calendar
enum FlightStatus {
    case none
    case singleFlight
    case multipleFlights
    case dayOff
    case workNoFlight
}

// MARK: - Utilities

// Flag emoji mapping
struct FlagEmoji {
    static let flags: [String: String] = [
        "SOF": "🇧🇬",
        "WAW": "🇵🇱",
        "AYT": "🇹🇷",
        "FRA": "🇩🇪",
        "LHR": "🇬🇧",
        "CDG": "🇫🇷"
    ]
    
    static func flag(for code: String) -> String {
        return flags[code] ?? "🏳️"
    }
}

// Date formatting utilities
struct DateUtils {
    static func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd MMMM"
        return formatter.string(from: date)
    }
    
    static func formatTime(timeString: String?) -> String? {
        guard let timeString = timeString else { return nil }
        return timeString
    }
    
    static func calculateDuration(depTime: String, arrTime: String) -> String {
        let depComponents = depTime.split(separator: ":").map { Int($0) ?? 0 }
        let arrComponents = arrTime.split(separator: ":").map { Int($0) ?? 0 }
        
        var hours = arrComponents[0] - depComponents[0]
        var minutes = arrComponents[1] - depComponents[1]
        
        if minutes < 0 {
            hours -= 1
            minutes += 60
        }
        
        if hours < 0 {
            hours += 24 // Assuming flight doesn't span multiple days
        }
        
        return "\(hours) Hours \(minutes) minutes"
    }
}

// Extension for Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}






import Foundation
import SwiftUI
import Combine
import Firebase
import FirebaseFirestore

class FlightDataService: ObservableObject {
    @Published var flightData: [DayData] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var lastUpdated: Date = Date()
    
    // New properties for change detection
    @Published var changedFlights: [ChangedFlight] = []
    @Published var hasChanges: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    // Cache file URL
    private var cacheFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("cached_flight_data.json")
    }
    
    struct ChangedFlight: Identifiable {
        let id = UUID()
        let flight: Flight
        let oldDepTime: String?
        let oldArrivalTime: String?
        let isNewDepTime: Bool
        let isNewArrivalTime: Bool
    }
    
    init() {
        loadCachedData()
        fetchFlightData()
    }
    
    // MARK: - Caching Methods
    
    private func loadCachedData() {
        guard let cacheFileURL = cacheFileURL,
              FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            print("DEBUG: No cache file exists yet at \(cacheFileURL?.path ?? "unknown path")")
            return
        }
        
        do {
            print("DEBUG: Loading flight data from cache at \(cacheFileURL.path)")
            let cachedData = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            let cachedFlightData = try decoder.decode([DayData].self, from: cachedData)
            
            DispatchQueue.main.async {
                print("DEBUG: Successfully loaded \(cachedFlightData.count) days from cache")
                
                // Find and print April 1st data specifically
                if let april1 = cachedFlightData.first(where: { $0.individualDay == "Mon, 01Apr" }) {
                    print("DEBUG: April 1st cached data found")
                    if let flights = april1.flights {
                        print("DEBUG: Cached flights for April 1st:")
                        for (index, flight) in flights.enumerated() {
                            print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
                        }
                    } else {
                        print("DEBUG: No flights found for April 1st in cache")
                    }
                } else {
                    print("DEBUG: No April 1st data found in cache")
                }
                
                self.flightData = cachedFlightData
                self.lastUpdated = Date()
            }
        } catch {
            print("ERROR: Failed to load cached data: \(error.localizedDescription)")
        }
    }
    
    private func saveDataToCache() {
        guard let cacheFileURL = cacheFileURL, !flightData.isEmpty else {
            print("DEBUG: No data to cache or cache URL unavailable")
            return
        }
        
        do {
            print("DEBUG: Saving flight data to cache at \(cacheFileURL.path)")
            let encoder = JSONEncoder()
            let data = try encoder.encode(flightData)
            try data.write(to: cacheFileURL)
            print("DEBUG: Successfully saved \(flightData.count) days to cache")
            
            // Find and print April 1st data specifically
            if let april1 = flightData.first(where: { $0.individualDay == "Mon, 01Apr" }) {
                print("DEBUG: April 1st data saved to cache")
                if let flights = april1.flights {
                    print("DEBUG: Saved flights for April 1st:")
                    for (index, flight) in flights.enumerated() {
                        print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
                    }
                } else {
                    print("DEBUG: No flights found for April 1st in saved data")
                }
            } else {
                print("DEBUG: No April 1st data found in saved data")
            }
        } catch {
            print("ERROR: Failed to save data to cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - API and Data Methods
    
    func fetchFlightData() {
        isLoading = true
        error = nil
        
        let cachedFlightData = flightData // Store current data before fetching new data
        
        print("DEBUG: Fetching flight data from API")
        
        guard let url = URL(string: "https://crewshift.virtuslabs.lol/schedule") else {
            self.error = "Invalid URL"
            self.isLoading = false
            print("ERROR: Invalid URL for API request")
            return
        }
        
        print("DEBUG: Sending API request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = ["userId": "user123"]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            print("DEBUG: Request body: \(String(data: jsonData, encoding: .utf8) ?? "")")
        } catch {
            self.error = "Failed to create request: \(error.localizedDescription)"
            self.isLoading = false
            print("ERROR: Failed to serialize request body: \(error.localizedDescription)")
            
            // Fall back to mock data
            self.loadMockData()
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.error = "Network error: \(error.localizedDescription)"
                    print("ERROR: Network request failed: \(error.localizedDescription)")
                    // Fall back to mock data on network error
                    self.loadMockData()
                }
            } receiveValue: { data in
                print("DEBUG: Received response data of size: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Response preview: \(String(responseString.prefix(200)))...")
                }
                
                // Save the data for debugging
                if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileURL = documentsDirectory.appendingPathComponent("flight_response.json")
                    try? data.write(to: fileURL)
                    print("DEBUG: Saved response to \(fileURL.path)")
                }
                
                self.parseApiResponse(data: data, cachedData: cachedFlightData)
            }
            .store(in: &cancellables)
    }
    
    private func parseApiResponse(data: Data, cachedData: [DayData]) {
        print("DEBUG: Parsing API response")
        do {
            let decoder = JSONDecoder()
            
            // Try to decode as an array first
            do {
                print("DEBUG: Attempting to decode response as array")
                let decodedData = try decoder.decode([DayData].self, from: data)
                
                // Print specific information about April 1st
                if let april1 = decodedData.first(where: { $0.individualDay == "Mon, 01Apr" }) {
                    print("DEBUG: April 1st found in API response")
                    if let flights = april1.flights {
                        print("DEBUG: API response flights for April 1st:")
                        for (index, flight) in flights.enumerated() {
                            print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
                        }
                    } else {
                        print("DEBUG: No flights found for April 1st in API response")
                    }
                } else {
                    print("DEBUG: No April 1st data found in API response")
                }
                
                // Detect changes before updating the published data
                self.detectChanges(oldData: cachedData, newData: decodedData)
                
                self.flightData = decodedData
                self.lastUpdated = Date()
                self.isLoading = false
                print("DEBUG: Successfully decoded \(self.flightData.count) days of flight data as array")
                self.printDecodedData()
                
                // Cache the new data
                self.saveDataToCache()
                
            } catch let arrayError {
                print("DEBUG: Failed to decode as array: \(arrayError)")
                
                // If that fails, try as a wrapper object
                do {
                    print("DEBUG: Attempting to decode response as wrapper object")
                    struct ScheduleResponse: Decodable {
                        let schedule: [DayData]
                    }
                    
                    let response = try decoder.decode(ScheduleResponse.self, from: data)
                    
                    // Print specific information about April 1st
                    if let april1 = response.schedule.first(where: { $0.individualDay == "Mon, 01Apr" }) {
                        print("DEBUG: April 1st found in wrapped API response")
                        if let flights = april1.flights {
                            print("DEBUG: API response (wrapped) flights for April 1st:")
                            for (index, flight) in flights.enumerated() {
                                print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
                            }
                        } else {
                            print("DEBUG: No flights found for April 1st in wrapped API response")
                        }
                    } else {
                        print("DEBUG: No April 1st data found in wrapped API response")
                    }
                    
                    // Detect changes before updating the published data
                    self.detectChanges(oldData: cachedData, newData: response.schedule)
                    
                    self.flightData = response.schedule
                    self.lastUpdated = Date()
                    self.isLoading = false
                    print("DEBUG: Successfully decoded \(self.flightData.count) days from schedule wrapper")
                    self.printDecodedData()
                    
                    // Cache the new data
                    self.saveDataToCache()
                    
                } catch let objectError {
                    self.error = "Failed to decode data"
                    self.isLoading = false
                    print("ERROR: Failed to decode as object: \(arrayError)")
                    print("ERROR: Full error details - Array decode: \(arrayError), Object decode: \(objectError)")
                    
                    // Fall back to mock data on decode error
                    self.loadMockData()
                }
            }
        }
    }
    
    // MARK: - Change Detection
    
    private func detectChanges(oldData: [DayData], newData: [DayData]) {
        changedFlights.removeAll()
        hasChanges = false
        
        print("DEBUG: Detecting changes between cached and new flight data")
        
        // Specifically looking for April 1st
        let targetDate = "Mon, 01Apr"
        
        guard let oldDay = oldData.first(where: { $0.individualDay == targetDate }),
              let newDay = newData.first(where: { $0.individualDay == targetDate }),
              let oldFlights = oldDay.flights,
              let newFlights = newDay.flights else {
            print("DEBUG: Could not find flight data for April 1st to compare")
            return
        }
        
        print("DEBUG: Found \(oldFlights.count) flights in old data and \(newFlights.count) flights in new data for \(targetDate)")
        
        // Map flights by duty to easily find corresponding flights
        let oldFlightMap = Dictionary(uniqueKeysWithValues: oldFlights.map { ($0.duty, $0) })
        
        for newFlight in newFlights {
            if let oldFlight = oldFlightMap[newFlight.duty] {
                let depTimeChanged = newFlight.depTime != oldFlight.depTime
                let arrivalTimeChanged = newFlight.arrivalTime != oldFlight.arrivalTime
                
                print("DEBUG: Comparing flight \(newFlight.duty)")
                print("DEBUG:   Old departure: \(oldFlight.depTime), New departure: \(newFlight.depTime)")
                print("DEBUG:   Old arrival: \(oldFlight.arrivalTime), New arrival: \(newFlight.arrivalTime)")
                
                if depTimeChanged || arrivalTimeChanged {
                    changedFlights.append(ChangedFlight(
                        flight: newFlight,
                        oldDepTime: depTimeChanged ? oldFlight.depTime : nil,
                        oldArrivalTime: arrivalTimeChanged ? oldFlight.arrivalTime : nil,
                        isNewDepTime: depTimeChanged,
                        isNewArrivalTime: arrivalTimeChanged
                    ))
                    hasChanges = true
                    
                    print("DEBUG: ✅ Detected change in flight \(newFlight.duty)")
                    if depTimeChanged {
                        print("DEBUG: ⏰ Departure time changed from \(oldFlight.depTime) to \(newFlight.depTime)")
                    }
                    if arrivalTimeChanged {
                        print("DEBUG: ⏰ Arrival time changed from \(oldFlight.arrivalTime) to \(newFlight.arrivalTime)")
                    }
                } else {
                    print("DEBUG: ✓ No changes detected for flight \(newFlight.duty)")
                }
            } else {
                // This is a new flight that wasn't in the old data
                changedFlights.append(ChangedFlight(
                    flight: newFlight,
                    oldDepTime: nil,
                    oldArrivalTime: nil,
                    isNewDepTime: true,
                    isNewArrivalTime: true
                ))
                hasChanges = true
                print("DEBUG: ➕ Detected new flight \(newFlight.duty) that wasn't in previous data")
            }
        }
        
        print("DEBUG: Found \(changedFlights.count) changed flights in total")
        
        if hasChanges {
            // Send a local notification about the changes
            sendFlightChangeNotification()
        } else {
            print("DEBUG: No changes detected for April 1st flights")
        }
    }
    
    // MARK: - Notifications
    
    private func sendFlightChangeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Flight Schedule Updated"
        content.body = "Your flight times for April 1st have been updated."
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "flightUpdate", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func printDecodedData() {
        print("DEBUG: === DECODED DATA SUMMARY ===")
        for (index, day) in flightData.enumerated() {
            print("DEBUG: Day \(index + 1): \(day.individualDay)")
            print("DEBUG: - Duty: \(day.duty ?? "Not specified")")
            if let flights = day.flights {
                print("DEBUG: - Flights: \(flights.count)")
                for (flightIndex, flight) in flights.enumerated() {
                    print("DEBUG:   Flight \(flightIndex + 1): \(flight.duty) - \(flight.departure) to \(flight.arrival)")
                }
            } else {
                print("DEBUG: - No flights")
            }
        }
    }
    
    // MARK: - Mock Data
    
    // For testing purposes, we'll modify the mock data to simulate time changes
    private func loadMockData() {
        print("DEBUG: 📱 Loading mock flight data with simulated changes")
        
        // Create mock flight data with different times to simulate changes
        let flight1 = Flight(
            duty: "CAI8001",
            departure: "SOF",
            arrival: "WAW",
            depTime: "05:15", // Changed from 04:45
            arrivalTime: "07:45",
            checkIn: "04:15", // Changed from 03:45
            checkOut: nil,
            aircraft: "A320/BHL",
            cockpit: "TRI G.GOSPODINOV; COP US R. BERNARDO",
            cabin: "SEN CCM S.ZHEKOVA; INS CCM A.IVANOVA; CCM K.KALOYANOV"
        )
        
        let flight2 = Flight(
            duty: "CAI8002",
            departure: "WAW",
            arrival: "AYT",
            depTime: "08:30",
            arrivalTime: "11:15", // Changed from 10:45
            checkIn: nil,
            checkOut: "12:40", // Changed from 12:10
            aircraft: "A320/BHL",
            cockpit: "TRI G.GOSPODINOV; COP US R. BERNARDO",
            cabin: "SEN CCM S.ZHEKOVA; CCM 2 Y.BOEVA; CCM M.ANDREEV"
        )
        
        let day1 = DayData(
            individualDay: "Mon, 01Apr",
            date: "2025-04-01",
            ftBlh: "05:55",
            fdt: "07:55",
            dt: "08:25",
            rp: "17:30",
            flights: [flight1, flight2]
        )
        
        let dayOff = DayData(
            individualDay: "Wed, 03Apr",
            date: "2025-04-03",
            duty: "Day Off"
        )
        
        self.flightData = [day1, dayOff]
        print("DEBUG: Using mock data with \(self.flightData.count) days")
        self.lastUpdated = Date()
        self.isLoading = false
        
        // Save the mock data to cache
        self.saveDataToCache()
        
        // If we're running for the first time or we're forcing regeneration of changes
        if changedFlights.isEmpty {
            print("DEBUG: Generating simulated changes for testing")
            
            // Create simulated old flights for comparison - THIS IS THE "CACHED" DATA
            let oldFlight1 = Flight(
                duty: "CAI8001",
                departure: "SOF",
                arrival: "WAW",
                depTime: "04:45", // Original time
                arrivalTime: "07:45",
                checkIn: "03:45",
                checkOut: nil,
                aircraft: "A320/BHL",
                cockpit: "TRI G.GOSPODINOV; COP US R. BERNARDO",
                cabin: "SEN CCM S.ZHEKOVA; INS CCM A.IVANOVA; CCM K.KALOYANOV"
            )
            
            let oldFlight2 = Flight(
                duty: "CAI8002",
                departure: "WAW",
                arrival: "AYT",
                depTime: "08:30",
                arrivalTime: "10:45", // Original time
                checkIn: nil,
                checkOut: "12:10",
                aircraft: "A320/BHL",
                cockpit: "TRI G.GOSPODINOV; COP US R. BERNARDO",
                cabin: "SEN CCM S.ZHEKOVA; CCM 2 Y.BOEVA; CCM M.ANDREEV"
            )
            
            // Create a fake cached version with the old times
            let oldDay1 = DayData(
                individualDay: "Mon, 01Apr",
                date: "2025-04-01",
                ftBlh: "05:55",
                fdt: "07:55",
                dt: "08:25",
                rp: "17:30",
                flights: [oldFlight1, oldFlight2]
            )
            
            let oldCachedData = [oldDay1, dayOff]
            
            print("DEBUG: Simulated OLD cached data:")
            for (index, flight) in oldDay1.flights!.enumerated() {
                print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
            }
            
            print("DEBUG: Simulated NEW data:")
            for (index, flight) in day1.flights!.enumerated() {
                print("DEBUG:   Flight \(index+1): \(flight.duty) - \(flight.departure) (\(flight.depTime)) to \(flight.arrival) (\(flight.arrivalTime))")
            }
            
            // Detect changes between the fake old data and the new mock data
            detectChanges(oldData: oldCachedData, newData: self.flightData)
            
            print("DEBUG: Simulated \(changedFlights.count) changed flights for testing")
        }
    }
    
    // MARK: - Helper Methods (unchanged)
    
    func getFlightStatus(date: Int, month: Int) -> FlightStatus {
        guard !flightData.isEmpty else { return .none }
        
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let dateStr = date < 10 ? "0\(date)" : "\(date)"
        let monthStr = months[month]
        
        guard let dayData = flightData.first(where: { $0.individualDay.contains("\(dateStr)\(monthStr)") }) else {
            return .none
        }
        
        if dayData.duty == "Day Off" { return .dayOff }
        
        if let flights = dayData.flights, !flights.isEmpty {
            return flights.count > 1 ? .multipleFlights : .singleFlight
        }
        
        return .workNoFlight
    }
    
    func getDayData(date: Int, month: Int) -> DayData? {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let dateStr = date < 10 ? "0\(date)" : "\(date)"
        let monthStr = months[month]
        
        return flightData.first(where: { $0.individualDay.contains("\(dateStr)\(monthStr)") })
    }
    
    func getDutyTimes(for dayData: DayData?) -> (start: String, end: String) {
        guard let dayData = dayData, let flights = dayData.flights, !flights.isEmpty else {
            return (start: "", end: "")
        }
        
        let firstFlight = flights.first!
        let lastFlight = flights.last!
        
        let startTime = firstFlight.checkIn ?? firstFlight.depTime
        let endTime = lastFlight.checkOut ?? lastFlight.arrivalTime
        
        return (start: startTime, end: endTime)
    }
}
