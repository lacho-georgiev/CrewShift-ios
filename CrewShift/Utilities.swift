import Foundation
import SwiftUI

// MARK: - Data Models

// Flight model
struct Flight: Identifiable, Decodable, Equatable {
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
struct DayData: Identifiable, Decodable, Equatable {
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
    @Published var lastUpdated: Date = Date() // To track when data changes
    
    private var cancellables = Set<AnyCancellable>()
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    init() {
        fetchFlightData()
    }
    
    func fetchFlightData() {
        isLoading = true
        error = nil
        
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
                
                self.parseApiResponse(data: data)
            }
            .store(in: &cancellables)
    }
    
    private func parseApiResponse(data: Data) {
        do {
            let decoder = JSONDecoder()
            
            // Try to decode as an array first
            do {
                let decodedData = try decoder.decode([DayData].self, from: data)
                self.flightData = decodedData
                self.lastUpdated = Date()
                self.isLoading = false
                print("DEBUG: Successfully decoded \(self.flightData.count) days of flight data as array")
                self.printDecodedData()
            } catch let arrayError {
                print("DEBUG: Failed to decode as array: \(arrayError)")
                
                // If that fails, try as a wrapper object
                do {
                    struct ScheduleResponse: Decodable {
                        let schedule: [DayData]
                    }
                    
                    let response = try decoder.decode(ScheduleResponse.self, from: data)
                    self.flightData = response.schedule
                    self.lastUpdated = Date()
                    self.isLoading = false
                    print("DEBUG: Successfully decoded \(self.flightData.count) days from schedule wrapper")
                    self.printDecodedData()
                } catch let objectError {
                    self.error = "Failed to decode data"
                    self.isLoading = false
                    print("ERROR: Failed to decode as object: \(objectError)")
                    print("ERROR: Full error details - Array decode: \(arrayError), Object decode: \(objectError)")
                    
                    // Fall back to mock data on decode error
                    self.loadMockData()
                }
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
    
    // Mock data for development and testing
    private func loadMockData() {
        print("DEBUG: Loading mock flight data")
        
        // Create mock flight data
        let flight1 = Flight(
            duty: "CAI8001",
            departure: "SOF",
            arrival: "WAW",
            depTime: "04:45",
            arrivalTime: "07:45",
            checkIn: "03:45",
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
            arrivalTime: "10:45",
            checkIn: nil,
            checkOut: "12:10",
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
    }
    
    // Helper methods for the calendar view
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
