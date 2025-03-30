import SwiftUI

struct ContentView: View {
    // User data
    let userName = "Dimitar"
    
    // State variables
    @State private var currentDate = Date()
    @State private var displayDate = Date()
    @State private var selectedMonth = 3 // April (0-indexed)
    @State private var selectedDate = 1 // Default to first day
    @State private var isDateSelected = false
    @State private var calendarExpanded = true
    
    // Animation related states
    @State private var dateSelectionScale: CGFloat = 1.0
    
    // Flight data
    @StateObject private var flightService = FlightDataService()
    @State private var selectedDayData: DayData? = nil
    @State private var dutyTimes: (start: String, end: String) = ("", "")
    
    private let abbreviatedMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background color
            Color(hex: "080808")
                .edgesIgnoringSafeArea(.all)
        
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top section
                    topHeader
                    
                    ZStack{

                        // Calendar
                        tinyCalendar
                            .padding(.horizontal, 15)
                            .padding(.top, 15)
                            .background(
                                Circle()
                                .fill(Color(hex: "F8F7FA"))
                                .frame(width: UIScreen.main.bounds.width * 2)
                                .offset(y: 140)
                                .scaleEffect(2)
                                .ignoresSafeArea())

                    }
                    
                    // Flights section
                    flightsSection
                        .padding(.top, 12)
                }
            }
        }
        .onAppear {
            updateSelectedDayData()
        }
        .onChange(of: selectedDate) { _ in
            updateSelectedDayData()
            animateSelection()
        }
        .onChange(of: selectedMonth) { _ in
            updateSelectedDayData()
        }
        .onChange(of: flightService.lastUpdated) { _ in
            updateSelectedDayData()
        }
    }
    
    // MARK: - Top Header
    private var topHeader: some View {
        VStack(spacing: 0) {
            // Header with bell icon, date, and profile
            HStack {
                Button(action: {}) {
                    BellIcon()
                }
                
                Spacer()
                
                Text(DateUtils.formatDate(date: displayDate))
                    .foregroundColor(Color.gray)
                    .font(.system(size: 16))
                
                Spacer()
                
                Button(action: {}) {
                    ProfileImage(size: 40)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 30)
            .padding(.bottom, 10)
            
            // Time display
            // Time display
            HStack(spacing: 15) {
                Text(dutyTimes.start.isEmpty ? "--:--" : dutyTimes.start)
                    .font(.system(size: 40, weight: .semibold))  // Reduced from 65
                    .foregroundColor(.white)
                
                Text("•")
                    .font(.system(size: 34))  // Reduced from 65
                    .foregroundColor(.white.opacity(0.2))
                
                Text(dutyTimes.end.isEmpty ? "--:--" : dutyTimes.end)
                    .font(.system(size: 40, weight: .semibold))  // Reduced from 65
                    .foregroundColor(.white)
            }
            .padding(.vertical, 15)
            
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.horizontal, 15)
            
            // Welcome message
            VStack(alignment: .leading, spacing: 5) {
                Text("Hello, \(userName)")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("What's on today's agenda?")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
        }
        .background(Color(hex: "080808"))
    }
    
    // MARK: - Calendar (Enhanced version)
    private var tinyCalendar: some View {
        VStack(spacing: 0) {
            // Month selector and expand/collapse button
            HStack(spacing: 0) {
                // Month selector with minimal width
                ScrollViewReader { scrollView in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(0..<months.count, id: \.self) { index in
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = index
                                    }
                                }) {
                                    Text(months[index])
                                        .font(.system(size: 15))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(selectedMonth == index ? Color(hex: "1a237e") : Color.clear)
                                        .foregroundColor(selectedMonth == index ? .white : .gray)
                                        .clipShape(Capsule())
                                }
                                .id(index)
                            }
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                    .onAppear {
                        DispatchQueue.main.async {
                            scrollView.scrollTo(selectedMonth, anchor: .center)
                        }
                    }
                    .onChange(of: selectedMonth) { newValue in
                        scrollView.scrollTo(newValue, anchor: .center)
                    }
                }
                
                Spacer(minLength: 0)
                
                Button(action: {
                    withAnimation(.spring()) {
                        calendarExpanded.toggle()
                    }
                }) {
                    Image(systemName: calendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .padding(5)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .frame(width: 22, height: 22)
                .padding(.leading, 2)
            }
            .padding(.horizontal, 2)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            // Calendar grid
            VStack(spacing: 8) {
                // Day headers
                HStack {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.1)),
                    alignment: .bottom
                )
                
                // Days grid
                let calendarDays = generateCalendarData()
                let days = calendarExpanded ? calendarDays : getCurrentWeekDays(calendarDays: calendarDays)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(days) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal, 5)
                
                // Legend
                if calendarExpanded {
                    HStack(spacing: 15) {
                        legendItem(color: Color(hex: "4ECCA3"), text: "Single Flight")
                        legendItem(color: Color(hex: "6A5ACD"), text: "Multiple")
                        legendItem(color: Color(hex: "FF6B6B"), text: "Day Off")
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    .transition(.opacity)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "E4E5E9").opacity(0.9),
                            Color(hex: "E4E5E9").opacity(1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
    // MARK: - Day Cell
    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = day.isCurrentMonth && day.date == selectedDate && day.month == selectedMonth
        
        return Button(action: {
            if day.isCurrentMonth {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedDate = day.date
                    selectedMonth = day.month
                    isDateSelected = true
                }
            }
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(getBackgroundColor(for: day, isSelected: isSelected))
                    .frame(height: 32)
                
                // Date number
                Text("\(day.date)")
                    .font(.system(size: 15))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(getTextColor(for: day, isSelected: isSelected))
                
                // Status indicator
                if day.isCurrentMonth && day.flightStatus != .none && !isSelected {
                    Circle()
                        .fill(getIndicatorColor(for: day))
                        .frame(width: 4, height: 4)
                        .offset(y: 10)
                }
            }
            .opacity(day.isCurrentMonth ? 1 : 0.4)
        }
    }
    
    // MARK: - Legend Item
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Flights Section
    private var flightsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Text("Today's Plan")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(hex: "080808"))

                
                Spacer()
                
                Button(action: {}) {
                    Text("view all")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "080808").opacity(0.2))
                }
            }
            .padding(.horizontal, 15)
            
            // Content
            Group {
                if flightService.isLoading {
                    loadingView
                } else if flightService.error != nil {
                    errorView
                } else if selectedDayData == nil {
                    noFlightsView(message: "No flight information available for this date.")
                } else if selectedDayData?.duty == "Day Off" {
                    noFlightsView(message: "Day Off - Enjoy your rest!")
                } else if let flights = selectedDayData?.flights, !flights.isEmpty {
                    flightsList(flights)
                } else {
                    noFlightsView(message: "No flight details available for this day.")
                }
            }
            .padding(.horizontal, 15)
            
            // Bottom spacer
            Spacer(minLength: 50)
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
        .background(Color(hex: "F8F7FA"))
    }
    
    // MARK: - Flight List
    private func flightsList(_ flights: [Flight]) -> some View {
        VStack(spacing: 15) {
            ForEach(Array(flights.enumerated()), id: \.element.id) { index, flight in
                FlightCard(flight: flight, index: index)
            }
        }
    }
    
    // MARK: - Loading, Error and No Flights Views
    private var loadingView: some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading flight data...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(25)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
    
    private var errorView: some View {
        VStack(spacing: 15) {
            Text("Failed to load flight data.")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "FF6B6B"))
            
            Button(action: { flightService.fetchFlightData() }) {
                Text("Retry")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "1a237e"))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
    
    private func noFlightsView(message: String) -> some View {
        VStack {
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
        .scaleEffect(dateSelectionScale)
    }
    
    // MARK: - Helper Methods
    private func updateSelectedDayData() {
        selectedDayData = flightService.getDayData(date: selectedDate, month: selectedMonth)
        dutyTimes = flightService.getDutyTimes(for: selectedDayData)
        
        if isDateSelected {
            var dateComponents = DateComponents()
            dateComponents.year = 2025
            dateComponents.month = selectedMonth + 1
            dateComponents.day = selectedDate
            
            if let date = Calendar.current.date(from: dateComponents) {
                displayDate = date
            }
        }
    }
    
    private func animateSelection() {
        withAnimation(.spring()) {
            dateSelectionScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                dateSelectionScale = 1.0
            }
        }
    }
    
    // MARK: - Calendar Helpers
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let daysOfWeek = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    private func generateCalendarData() -> [CalendarDay] {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = selectedMonth + 1
        dateComponents.day = 1
        
        guard let firstDayOfMonth = calendar.date(from: dateComponents),
              let lastDayOfMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth)?.addingTimeInterval(-1) else {
            return []
        }
        
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 2
        if firstWeekday < 0 { firstWeekday = 6 }
        
        let daysInMonth = calendar.component(.day, from: lastDayOfMonth)
        
        dateComponents.month = selectedMonth
        let daysInPreviousMonth = calendar.component(.day, from: calendar.date(from: dateComponents)?.addingTimeInterval(-1) ?? Date())
        
        var days: [CalendarDay] = []
        
        for i in 0..<firstWeekday {
            days.append(CalendarDay(date: daysInPreviousMonth - firstWeekday + i + 1, month: selectedMonth - 1, isCurrentMonth: false))
        }
        
        for i in 1...daysInMonth {
            var day = CalendarDay(date: i, month: selectedMonth, isCurrentMonth: true)
            day.flightStatus = flightService.getFlightStatus(date: i, month: selectedMonth)
            days.append(day)
        }
        
        let lastRowDays = (7 - (days.count % 7)) % 7
        for i in 1...lastRowDays {
            days.append(CalendarDay(date: i, month: selectedMonth + 1, isCurrentMonth: false))
        }
        
        return days
    }
    
    private func getCurrentWeekDays(calendarDays: [CalendarDay]) -> [CalendarDay] {
        guard let selectedIndex = calendarDays.firstIndex(where: { $0.isCurrentMonth && $0.date == selectedDate }) else {
            return Array(calendarDays.prefix(7))
        }
        
        let startOfWeekIndex = selectedIndex - (selectedIndex % 7)
        let endOfWeekIndex = min(startOfWeekIndex + 7, calendarDays.count)
        
        return Array(calendarDays[startOfWeekIndex..<endOfWeekIndex])
    }
    
    // MARK: - UI Helper Methods
    private func getBackgroundColor(for day: CalendarDay, isSelected: Bool) -> Color {
        if isSelected {
            return Color(hex: "1a237e")
        }
        
        switch day.flightStatus {
        case .multipleFlights: return Color(hex: "6A5ACD").opacity(0.2)
        case .singleFlight: return Color(hex: "4ECCA3").opacity(0.2)
        case .dayOff: return Color(hex: "FF6B6B").opacity(0.2)
        case .workNoFlight: return Color(hex: "FFC107").opacity(0.2)
        case .none: return Color.clear
        }
    }
    
    private func getTextColor(for day: CalendarDay, isSelected: Bool) -> Color {
        if isSelected {
            return .white
        }
        
        if !day.isCurrentMonth {
            return Color.gray
        }
        
        if day.flightStatus == .dayOff {
            return Color(hex: "FF6B6B")
        }
        
        return Color.black
    }
    
    private func getIndicatorColor(for day: CalendarDay) -> Color {
        switch day.flightStatus {
        case .multipleFlights: return Color(hex: "6A5ACD")
        case .singleFlight: return Color(hex: "4ECCA3")
        case .dayOff: return Color(hex: "FF6B6B")
        case .workNoFlight: return Color(hex: "FFC107")
        case .none: return Color.clear
        }
    }
}

// MARK: - Bell Icon
struct BellIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 0.8)
                .frame(width: 40, height: 40)
            
            VStack(spacing: 0) {
                
                // Bell shape
                ZStack {
                    Text("🔔")
                    
                    // Bell clapper
                    Circle()
                        .fill(Color.white)
                        .frame(width: 2, height: 2)
                        .offset(y: 10)
                }
                .frame(width: 12, height: 13)
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.4)
                                .repeatCount(3, autoreverses: true)
                                .delay(2)) {
                    isAnimating = true
                }
                
                // Reset animation after completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    isAnimating = false
                    // Restart animation after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(Animation.easeInOut(duration: 0.4)
                                        .repeatCount(3, autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Profile Image
struct ProfileImage: View {
    var size: CGFloat = 40
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size + 4, height: size + 4)
                .shadow(color: .white.opacity(0.3), radius: 2)
            
            Image("ProfilePicture1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .scaleEffect(isAnimating ? 0.9 : 1.0)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    isAnimating = false
                }
            }
        }
    }
}

struct FlightCard: View {
    let flight: Flight
    let index: Int
    
    @State private var showCrewDetails = false
    @State private var appear = false
    @State private var chevronRotation: Double = 0
    
    // Sample crew images - in a real app, this would come from the flight data
    let crewImages = ["crew1", "crew2", "crew3", "crew4", "crew5"]
    
    var body: some View {
        VStack(spacing: 15) {
            // Flight header - Origin, Flight number, Destination
            HStack {
                // Origin
                VStack(alignment: .leading) {
                    Text("\(flight.departure) \(FlagEmoji.flag(for: flight.departure))")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "E4E5E9"))

                    Text(flight.depTime)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "080808"))

                }
                .frame(maxWidth: .infinity)
                
                // Flight number
                VStack {
                    Text(flight.duty)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "E4E5E9"))
                        .padding(.top, 15)
                }
                .frame(width: 80)
                
                // Destination
                VStack(alignment: .leading) {
                    Text("\(flight.arrival) \(FlagEmoji.flag(for: flight.arrival))")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "E4E5E9"))

                    Text(flight.arrivalTime)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "080808"))

                }
                .frame(maxWidth: .infinity)
            }
            
            // Flight progress
            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 5, height: 5)
                    
                    ZStack(alignment: .center) {
                        Image("DottedLines")
                            .resizable()
                            .frame(height: 24)
                    }
                    
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 5, height: 5)
                }
                
                Text(DateUtils.calculateDuration(depTime: flight.depTime, arrTime: flight.arrivalTime))
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "E4E5E9"))
            }
            .padding(.top, -22)
            
            // Flight footer - Aircraft and Crew
            HStack {
                // Aircraft
                VStack(alignment: .leading, spacing: 2) {
                    Text("A/C")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(flight.aircraft)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "080808"))

                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color(hex: "F0F4F8"))
                .cornerRadius(15)
                
                Spacer()
                
                // Crew button with chevron BEFORE stacked photos
                Button(action: {
                    withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.7)) {
                        showCrewDetails.toggle()
                        chevronRotation = showCrewDetails ? 180 : 0
                    }
                }) {
                    HStack(spacing: 5) { // Reduced spacing to bring elements closer
                        // Chevron (BEFORE the photos)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "1a237e"))
                            .rotationEffect(.degrees(chevronRotation))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "1a237e").opacity(0.1))
                            .clipShape(Circle())
                        
                        // Stacked crew images - Made bigger and closer to chevron
                        ZStack(alignment: .leading) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(crewImages[i])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 34, height: 34) // Bigger images
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .offset(x: CGFloat(i) * 16) // Reduced offset to bring closer to chevron
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        
                        
                    }
                }
                .padding(.trailing, 25) // Added trailing padding

            }
            
            // Expandable Crew Details
            if showCrewDetails {
                VStack(spacing: 10) {
                    Divider()
                    
                    // Cockpit section with crew images
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cockpit:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                        
                        // Cockpit crew images
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { i in
                                Image(crewImages[i])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Text(flight.cockpit)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Cabin section with crew images
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cabin:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                        
                        // Cabin crew images
                        HStack(spacing: 8) {
                            ForEach(2..<5, id: \.self) { i in
                                Image(crewImages[min(i, crewImages.count-1)])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Text(flight.cabin)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(15)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.95)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring().delay(Double(index) * 0.15)) {
                appear = true
            }
        }
    }
}

// For dashed lines in flight progress bar
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let day: CalendarDay
    @Binding var selectedDate: Int
    @Binding var selectedMonth: Int
    @Binding var isDateSelected: Bool
    
    var isSelected: Bool {
        day.isCurrentMonth && day.date == selectedDate && day.month == selectedMonth
    }
    
    var body: some View {
        Button(action: {
            if day.isCurrentMonth {
                selectedDate = day.date
                selectedMonth = day.month
                isDateSelected = true
            }
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    .frame(height: 34) // Smaller cell height
                    .opacity(day.isCurrentMonth ? 1 : 0.4)
                
                // Date text
                Text("\(day.date)")
                    .font(.system(size: 15)) // Smaller font
                    .fontWeight(isSelected || day.flightStatus != .none ? .medium : .regular)
                    .foregroundColor(textColor)
                
                // Status indicator
                if day.isCurrentMonth && day.flightStatus != .none && !isSelected {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 4, height: 4) // Smaller indicator
                        .offset(y: 12)
                }
            }
        }
        .opacity(day.isCurrentMonth ? 1 : 0.4)
    }
    
    var backgroundColor: Color {
        if isSelected {
            return Color(hex: "1a237e")
        }
        
        switch day.flightStatus {
        case .multipleFlights:
            return Color(hex: "6A5ACD").opacity(0.2)
        case .singleFlight:
            return Color(hex: "4ECCA3").opacity(0.2)
        case .dayOff:
            return Color(hex: "FF6B6B").opacity(0.2)
        case .workNoFlight:
            return Color(hex: "FFC107").opacity(0.2)
        case .none:
            return Color.clear
        }
    }
    
    var textColor: Color {
        if isSelected {
            return .white
        }
        
        if !day.isCurrentMonth {
            return Color.gray
        }
        
        if day.flightStatus == .dayOff {
            return Color(hex: "FF6B6B")
        }
        
        return Color.black
    }
    
    var indicatorColor: Color {
        switch day.flightStatus {
        case .multipleFlights:
            return Color(hex: "6A5ACD")
        case .singleFlight:
            return Color(hex: "4ECCA3")
        case .dayOff:
            return Color(hex: "FF6B6B")
        case .workNoFlight:
            return Color(hex: "FFC107")
        case .none:
            return Color.clear
        }
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Color.gray)
        }
    }
}




struct NoFlightsView: View {
    let message: String
    
    var body: some View {
        VStack {
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
            Text("Loading flight data...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(25)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
}

struct ErrorView: View {
    let errorMessage: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text(errorMessage)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "FF6B6B"))
            
            Button(action: retryAction) {
                Text("Retry")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "1a237e"))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 4)
    }
}






// MARK: - Calendar View
struct CalendarView: View {
    @Binding var selectedDate: Int
    @Binding var selectedMonth: Int
    @Binding var isDateSelected: Bool
    @Binding var calendarExpanded: Bool
    let flightData: [DayData]
    
    let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    let daysOfWeek = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month selector and expand/collapse toggle
            HStack {
                // Month selector with auto-centering
                // Month selector with proper auto-centering
                ScrollViewReader { scrollView in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(0..<months.count, id: \.self) { index in
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = index
                                    }
                                }) {
                                    Text(months[index])
                                        .font(.system(size: 16))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(selectedMonth == index ? Color(hex: "1a237e") : Color.clear)
                                        .foregroundColor(selectedMonth == index ? .white : .gray)
                                        .clipShape(Capsule())
                                }
                                .id(index)
                            }
                        }
                        .padding(.trailing, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width - 70)
                }

                
                Button(action: {
                    withAnimation(.spring()) {
                        calendarExpanded.toggle()
                    }
                }) {
                    Image(systemName: calendarExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 8)
            
            // Calendar grid
            VStack(spacing: 5) {
                // Day headers
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 5)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.1)),
                    alignment: .bottom
                )
                
                // Calendar days
                let calendarDays = generateCalendarData(month: selectedMonth)
                let days = calendarExpanded ? calendarDays : getCurrentWeekDays(calendarDays: calendarDays, selectedDate: selectedDate)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days) { day in
                        DayCell(
                            day: day,
                            selectedDate: $selectedDate,
                            selectedMonth: $selectedMonth,
                            isDateSelected: $isDateSelected
                        )
                    }
                }
                
                // Legend
                HStack(spacing: 20) {
                    LegendItem(color: Color(hex: "4ECCA3"), text: "Single Flight")
                    LegendItem(color: Color(hex: "6A5ACD"), text: "Multiple")
                    LegendItem(color: Color(hex: "FF6B6B"), text: "Day Off")
                }
                .padding(.top, 10)
                .padding(.bottom, 5)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.1)),
                    alignment: .top
                )
                .opacity(calendarExpanded ? 1 : 0)
            }
            .padding(.horizontal, 15)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        
    }
    
    // Generate calendar data for a month
    func generateCalendarData(month: Int) -> [CalendarDay] {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = month + 1
        dateComponents.day = 1
        
        guard let firstDayOfMonth = calendar.date(from: dateComponents) else { return [] }
        guard let lastDayOfMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth)?.addingTimeInterval(-1) else { return [] }
        
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 2
        if firstWeekday < 0 { firstWeekday = 6 } // Adjust for Monday start
        
        let daysInMonth = calendar.component(.day, from: lastDayOfMonth)
        
        dateComponents.month = month
        guard let lastDayOfPreviousMonth = calendar.date(from: dateComponents)?.addingTimeInterval(-1) else { return [] }
        let daysInPreviousMonth = calendar.component(.day, from: lastDayOfPreviousMonth)
        
        var days: [CalendarDay] = []
        
        // Previous month days
        for i in 0..<firstWeekday {
            let day = CalendarDay(
                date: daysInPreviousMonth - firstWeekday + i + 1,
                month: month - 1,
                isCurrentMonth: false
            )
            days.append(day)
        }
        
        // Current month days
        for i in 1...daysInMonth {
            var day = CalendarDay(
                date: i,
                month: month,
                isCurrentMonth: true
            )
            day.flightStatus = getFlightStatus(date: i, month: month, flightData: flightData)
            days.append(day)
        }
        
        // Next month days
        let lastRowDays = (7 - (days.count % 7)) % 7
        for i in 1...lastRowDays {
            let day = CalendarDay(
                date: i,
                month: month + 1,
                isCurrentMonth: false
            )
            days.append(day)
        }
        
        return days
    }
    
    // Get current week days from calendar data
    func getCurrentWeekDays(calendarDays: [CalendarDay], selectedDate: Int) -> [CalendarDay] {
        guard let selectedIndex = calendarDays.firstIndex(where: { $0.isCurrentMonth && $0.date == selectedDate }) else {
            return Array(calendarDays.prefix(7))
        }
        
        let startOfWeekIndex = selectedIndex - (selectedIndex % 7)
        let endOfWeekIndex = min(startOfWeekIndex + 7, calendarDays.count)
        
        return Array(calendarDays[startOfWeekIndex..<endOfWeekIndex])
    }
    
    // Check flight status for a date
    func getFlightStatus(date: Int, month: Int, flightData: [DayData]) -> FlightStatus {
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
}










import SwiftUI
import MapKit

// Stay model definition
struct Stay {
    var hotel: String
    var address: String
    var mapUrl: String
    var checkIn: String
    var checkOut: String
    var roomNumber: String
    var confirmationCode: String
    var amenities: [String]
    var contact: String
    var distance: String
}

struct StayView: View {
    @State private var expandedSection: String? = nil
    
    // Hardcoded stay information
    let stayInfo = Stay(
        hotel: "Grand Sheraton Sofia",
        address: "5 Sveta Nedelya Square, 1000 Sofia, Bulgaria",
        mapUrl: "https://maps.google.com/?q=5+Sveta+Nedelya+Square+Sofia",
        checkIn: "14:00",
        checkOut: "12:00",
        roomNumber: "724",
        confirmationCode: "SH39275",
        amenities: [
            "Free Wi-Fi",
            "Breakfast included",
            "Fitness center",
            "Airport shuttle",
            "24h room service"
        ],
        contact: "+359 2 981 6541",
        distance: "1.2km from Sofia Airport (SOF)"
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Hotel Header
                VStack(alignment: .leading, spacing: 5) {
                    Text(stayInfo.hotel)
                        .font(.system(size: 24, weight: .semibold))
                    
                    Text(stayInfo.address)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.bottom, 10)
                    
                    Button(action: openMaps) {
                        Text("Open in Maps")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color(hex: "1a237e"))
                            .cornerRadius(20)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                
                // Image Gallery
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach([
                            Color(hex: "4285F4"),
                            Color(hex: "EA4335"),
                            Color(hex: "FBBC05"),
                            Color(hex: "34A853"),
                            Color(hex: "8A2BE2")
                        ], id: \.self) { color in
                            RoundedRectangle(cornerRadius: 15)
                                .fill(color)
                                .frame(width: UIScreen.main.bounds.width * 0.7, height: 180)
                        }
                    }
                    .padding(15)
                }
                
                // Stay Details Card
                VStack(spacing: 15) {
                    // Card header
                    HStack {
                        Text("Your Stay")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Spacer()
                    }
                    .padding(.bottom, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    // Check-in/Check-out
                    HStack {
                        VStack(spacing: 5) {
                            Text("Check-in")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text(stayInfo.checkIn)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        
                        Rectangle()
                            .frame(width: 1, height: 40)
                            .foregroundColor(Color.gray.opacity(0.2))
                        
                        VStack(spacing: 5) {
                            Text("Check-out")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text(stayInfo.checkOut)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 5)
                    
                    // Room details
                    VStack(spacing: 5) {
                        Text("Room Number")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(stayInfo.roomNumber)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "1a237e"))
                            .padding(.vertical, 5)
                        
                        Text("Confirmation: \(stayInfo.confirmationCode)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        VStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.gray.opacity(0.1))
                                .padding(.bottom, 15)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.gray.opacity(0.1))
                                .padding(.top, 15)
                        },
                        alignment: .center
                    )
                    
                    // Amenities section
                    Button(action: {
                        withAnimation {
                            expandedSection = expandedSection == "amenities" ? nil : "amenities"
                        }
                    }) {
                        HStack {
                            Text("Amenities")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Text(expandedSection == "amenities" ? "−" : "+")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 15)
                        .foregroundColor(.primary)
                    }
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    if expandedSection == "amenities" {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(stayInfo.amenities, id: \.self) { amenity in
                                Text("• \(amenity)")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 5)
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }
                    
                    // Contact & Location section
                    Button(action: {
                        withAnimation {
                            expandedSection = expandedSection == "contact" ? nil : "contact"
                        }
                    }) {
                        HStack {
                            Text("Contact & Location")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Text(expandedSection == "contact" ? "−" : "+")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 15)
                        .foregroundColor(.primary)
                    }
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    if expandedSection == "contact" {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("📞 \(stayInfo.contact)")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                                .padding(.vertical, 5)
                            
                            Text("✈️ \(stayInfo.distance)")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                                .padding(.vertical, 5)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }
                }
                .padding(15)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 15)
                
                // Map placeholder
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(15)
                    
                    VStack(spacing: 5) {
                        Text("Map View")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Use actual MapView component in production")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                .padding(.horizontal, 15)
                
                // Bottom spacer
                Spacer(minLength: 80)
            }
        }
        .background(Color(hex: "F8F7FA"))
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Function to open maps
    func openMaps() {
        let coordinates = "42.6954108,23.3212612" // Sofia coordinates
        let name = stayInfo.hotel.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        
        var mapString = ""
        
        #if os(iOS)
        if UIApplication.shared.canOpenURL(URL(string: "maps:")!) {
            mapString = "maps:?q=\(name)&ll=\(coordinates)"
        } else {
            mapString = "https://maps.google.com/?q=\(coordinates)"
        }
        #else
        mapString = "https://maps.google.com/?q=\(coordinates)"
        #endif
        
        guard let url = URL(string: mapString) else { return }
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}

// To display a real map in production you would use:
struct MapViewPlaceholder: View {
    let latitude: Double = 42.6954108
    let longitude: Double = 23.3212612
    let name: String = "Grand Sheraton Sofia"
    
    var body: some View {
        // In a real app, this would be a MapKit implementation
        ZStack {
            Color.gray.opacity(0.2)
            Text("Map View")
                .foregroundColor(.gray)
        }
        .frame(height: 200)
        .cornerRadius(15)
    }
}

#Preview {
    StayView()
}



import SwiftUI

struct CustomTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case stay
        case messages
        case profile
    }
    
    var body: some View {
        ZStack {
            // Main content
            TabView(selection: $selectedTab) {
                ContentView()
                    .tag(Tab.home)
                
                StayView()
                    .tag(Tab.stay)
                
                Text("Messages")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "F8F7FA"))
                    .tag(Tab.messages)
                
                Text("Profile")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "F8F7FA"))
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom tab bar at the bottom
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
                    .frame(width: UIScreen.main.bounds.width) // Explicitly set width to screen width
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: CustomTabView.Tab
    @Namespace private var animation
    
    var body: some View {
        HStack {
            ForEach([
                (tab: CustomTabView.Tab.home, icon: "airplane", title: "Flights"),
                (tab: CustomTabView.Tab.stay, icon: "house.fill", title: "Stay"),
                (tab: CustomTabView.Tab.messages, icon: "message.fill", title: "Messages"),
                (tab: CustomTabView.Tab.profile, icon: "person.fill", title: "Profile")
            ], id: \.tab) { item in
                TabBarButton(
                    tab: item.tab,
                    icon: item.icon,
                    title: item.title,
                    selectedTab: $selectedTab,
                    animation: animation
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: -2)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: CustomTabView.Tab
    let icon: String
    let title: String
    @Binding var selectedTab: CustomTabView.Tab
    var animation: Namespace.ID
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedTab == tab ? Color(hex: "1a237e") : .gray)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(selectedTab == tab ? Color(hex: "1a237e") : .gray)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(hex: "1a237e").opacity(0.1))
                            .matchedGeometryEffect(id: "TAB", in: animation)
                    }
                }
            )
        }
    }
}



