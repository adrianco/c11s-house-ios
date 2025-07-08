# Location Services Implementation Plan

This document outlines the comprehensive strategy for integrating location-based features into the C11S House iOS application, including address lookup, confirmation, and weather integration for the home view.

## Architecture Overview

Location services will integrate with the existing ServiceContainer pattern and leverage Apple's Core Location framework while maintaining privacy-first principles.

## Feature Sets

### 1. Home Address Management
- [x] Address lookup via Core Location geocoding
- [x] Interactive address confirmation UI
- [x] Persistent address storage in UserDefaults
- [x] Address change detection and re-confirmation
- [ ] Multiple home support (future)

### 2. Weather Integration
- [x] Real-time weather data fetching
- [x] Weather display on home view
- [x] Location-based weather updates
- [x] Weather condition icons and descriptions
- [x] Temperature display (with unit preferences)
- [ ] Weather-based automation triggers (future)

### 3. Core Location Features
- [ ] Room detection and presence awareness
- [ ] Geofencing for home automation
- [ ] Location-based voice command context
- [ ] Indoor positioning for device proximity

### 4. Privacy & Security
- [x] Location permission management
- [x] On-device location processing
- [x] Minimal location data storage
- [ ] Location data encryption
- [ ] Granular permission controls

## Implementation Details

### Address Lookup Service

```swift
// LocationService.swift
protocol LocationServiceProtocol {
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    
    func requestLocationPermission() async
    func getCurrentLocation() async throws -> CLLocation
    func lookupAddress(for location: CLLocation) async throws -> Address
    func confirmAddress(_ address: Address) async throws
}

// Address model
struct Address: Codable, Equatable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let coordinate: Coordinate
    
    var fullAddress: String {
        "\(street), \(city), \(state) \(postalCode)"
    }
}

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}
```

### Address Confirmation Flow

```swift
// AddressConfirmationViewModel.swift
@MainActor
class AddressConfirmationViewModel: ObservableObject {
    @Published var suggestedAddress: Address?
    @Published var isLoading = false
    @Published var error: LocationError?
    @Published var confirmedAddress: Address?
    
    private let locationService: LocationServiceProtocol
    private let storageService: StorageServiceProtocol
    
    func lookupCurrentAddress() async {
        isLoading = true
        error = nil
        
        do {
            let location = try await locationService.getCurrentLocation()
            suggestedAddress = try await locationService.lookupAddress(for: location)
        } catch {
            self.error = LocationError.from(error)
        }
        
        isLoading = false
    }
    
    func confirmAddress() async {
        guard let address = suggestedAddress else { return }
        
        do {
            try await locationService.confirmAddress(address)
            confirmedAddress = address
            await storageService.saveHomeAddress(address)
            await fetchWeatherForAddress()
        } catch {
            self.error = LocationError.from(error)
        }
    }
}
```

### Weather Service Integration with WeatherKit

```swift
// WeatherService.swift
import WeatherKit
import CoreLocation

protocol WeatherServiceProtocol {
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> { get }
}

// Weather models adapted for WeatherKit
struct Weather: Codable {
    let temperature: Temperature
    let condition: WeatherCondition
    let humidity: Double
    let windSpeed: Double
    let feelsLike: Temperature
    let uvIndex: Int
    let pressure: Double
    let visibility: Double
    let dewPoint: Double
    let forecast: [DailyForecast]
    let hourlyForecast: [HourlyForecast]
    let lastUpdated: Date
}

struct Temperature: Codable {
    let value: Double
    let unit: TemperatureUnit
    
    var formatted: String {
        switch unit {
        case .celsius:
            return String(format: "%.0f°C", value)
        case .fahrenheit:
            return String(format: "%.0f°F", value)
        }
    }
    
    init(from measurement: Measurement<UnitTemperature>) {
        self.value = measurement.value
        self.unit = measurement.unit == .celsius ? .celsius : .fahrenheit
    }
}

enum WeatherCondition: String, Codable {
    case blowingDust
    case clear
    case cloudy
    case foggy
    case haze
    case mostlyClear
    case mostlyCloudy
    case partlyCloudy
    case smoky
    case breezy
    case windy
    case drizzle
    case heavyRain
    case rain
    case showers
    case flurries
    case heavySnow
    case sleet
    case snow
    case blizzard
    case blowingSnow
    case freezingDrizzle
    case freezingRain
    case frigid
    case hail
    case hot
    case isolatedThunderstorms
    case scatteredThunderstorms
    case strongStorms
    case thunderstorms
    case tropicalStorm
    case hurricane
    
    init(from weatherCondition: WeatherKit.WeatherCondition) {
        switch weatherCondition {
        case .blowingDust: self = .blowingDust
        case .clear: self = .clear
        case .cloudy: self = .cloudy
        case .foggy: self = .foggy
        case .haze: self = .haze
        case .mostlyClear: self = .mostlyClear
        case .mostlyCloudy: self = .mostlyCloudy
        case .partlyCloudy: self = .partlyCloudy
        case .smoky: self = .smoky
        case .breezy: self = .breezy
        case .windy: self = .windy
        case .drizzle: self = .drizzle
        case .heavyRain: self = .heavyRain
        case .rain: self = .rain
        case .showers: self = .showers
        case .flurries: self = .flurries
        case .heavySnow: self = .heavySnow
        case .sleet: self = .sleet
        case .snow: self = .snow
        case .blizzard: self = .blizzard
        case .blowingSnow: self = .blowingSnow
        case .freezingDrizzle: self = .freezingDrizzle
        case .freezingRain: self = .freezingRain
        case .frigid: self = .frigid
        case .hail: self = .hail
        case .hot: self = .hot
        case .isolatedThunderstorms: self = .isolatedThunderstorms
        case .scatteredThunderstorms: self = .scatteredThunderstorms
        case .strongStorms: self = .strongStorms
        case .thunderstorms: self = .thunderstorms
        case .tropicalStorm: self = .tropicalStorm
        case .hurricane: self = .hurricane
        @unknown default: self = .clear
        }
    }
    
    var icon: String {
        switch self {
        case .clear, .mostlyClear: return "sun.max.fill"
        case .cloudy, .mostlyCloudy: return "cloud.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .rain, .drizzle, .showers: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .snow, .flurries, .heavySnow: return "cloud.snow.fill"
        case .blizzard, .blowingSnow: return "wind.snow"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms: 
            return "cloud.bolt.rain.fill"
        case .foggy: return "cloud.fog.fill"
        case .haze, .smoky: return "sun.haze.fill"
        case .windy, .breezy: return "wind"
        case .sleet, .freezingRain, .freezingDrizzle: return "cloud.sleet.fill"
        case .hail: return "cloud.hail.fill"
        case .hot: return "thermometer.sun.fill"
        case .frigid: return "thermometer.snowflake"
        case .tropicalStorm, .hurricane: return "hurricane"
        case .blowingDust: return "sun.dust.fill"
        }
    }
}
```

### ContentView Weather Integration

```swift
// ContentViewModel.swift
@MainActor
class ContentViewModel: ObservableObject {
    @Published var homeAddress: Address?
    @Published var currentWeather: Weather?
    @Published var houseThought: HouseThought
    @Published var isLoadingWeather = false
    @Published var houseName: String = ""
    
    private let weatherService: WeatherServiceProtocol
    private let locationService: LocationServiceProtocol
    private let storageService: StorageServiceProtocol
    private let notesService: NotesServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    func loadHomeData() async {
        // Load saved address
        if let savedAddress = await storageService.loadHomeAddress() {
            homeAddress = savedAddress
            await refreshWeather()
            await loadHouseName()
        } else {
            // Prompt for address confirmation
            await promptForAddressConfirmation()
        }
        
        // Subscribe to weather updates
        weatherService.weatherUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather in
                self?.currentWeather = weather
                self?.updateHouseEmotionForWeather(weather)
            }
            .store(in: &cancellables)
    }
    
    func refreshWeather() async {
        guard let address = homeAddress else { return }
        
        isLoadingWeather = true
        do {
            currentWeather = try await weatherService.fetchWeatherForAddress(address)
            updateHouseEmotionForWeather(currentWeather)
            
            // Save weather summary to notes
            if let weather = currentWeather {
                try? await notesService.saveWeatherSummary(weather, address: address)
            }
        } catch {
            // Handle error appropriately
            print("Weather fetch error: \(error)")
        }
        isLoadingWeather = false
    }
    
    private func updateHouseEmotionForWeather(_ weather: Weather?) {
        guard let weather = weather else { return }
        
        // Make house react to various weather conditions
        switch weather.condition {
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .hurricane, .tropicalStorm, .blizzard:
            houseThought = HouseThought(
                emotion: .worried,
                thought: "I hope everyone stays safe in this severe weather...",
                intensity: 0.9
            )
        case .rain, .drizzle, .showers, .heavyRain:
            houseThought = HouseThought(
                emotion: .worried,
                thought: "It's raining. I'll keep everyone cozy and dry.",
                intensity: 0.5
            )
        case .snow, .flurries, .heavySnow, .blowingSnow:
            houseThought = HouseThought(
                emotion: .excited,
                thought: "Snow! How magical. Let's keep warm inside.",
                intensity: 0.7
            )
        case .clear, .mostlyClear:
            houseThought = HouseThought(
                emotion: .content,
                thought: "What a beautiful day! Perfect for opening the windows.",
                intensity: 0.7
            )
        case .hot:
            houseThought = HouseThought(
                emotion: .tired,
                thought: "It's quite hot. I'll keep the cool air circulating.",
                intensity: 0.6
            )
        case .frigid:
            houseThought = HouseThought(
                emotion: .worried,
                thought: "It's freezing outside! I'll work hard to keep you warm.",
                intensity: 0.7
            )
        case .windy, .breezy:
            houseThought = HouseThought(
                emotion: .neutral,
                thought: "The wind is whistling through. All secure here.",
                intensity: 0.4
            )
        case .cloudy, .mostlyCloudy, .partlyCloudy, .foggy, .haze, .smoky:
            houseThought = HouseThought(
                emotion: .neutral,
                thought: "A bit gloomy outside, but comfortable inside.",
                intensity: 0.3
            )
        case .hail, .sleet, .freezingRain, .freezingDrizzle:
            houseThought = HouseThought(
                emotion: .worried,
                thought: "Icy conditions outside. Please be careful!",
                intensity: 0.8
            )
        case .blowingDust:
            houseThought = HouseThought(
                emotion: .neutral,
                thought: "Dusty conditions. I'll keep the air filtered.",
                intensity: 0.5
            )
        }
    }
    
    private func loadHouseName() async {
        // Check if house name is already saved in notes
        if let savedName = await notesService.getHouseName() {
            houseName = savedName
        } else {
            // Suggest name based on street address
            houseName = suggestHouseName()
        }
    }
    
    private func suggestHouseName() -> String {
        guard let address = homeAddress else { return "" }
        
        // Extract street name without number and type
        let streetComponents = address.street.components(separatedBy: " ")
        
        // Filter out common components
        let filteredComponents = streetComponents.filter { component in
            // Remove numbers
            if component.rangeOfCharacter(from: .decimalDigits) != nil {
                return false
            }
            
            // Remove common street types
            let streetTypes = ["St", "St.", "Street", "Ave", "Ave.", "Avenue", 
                             "Rd", "Rd.", "Road", "Blvd", "Boulevard", "Dr", 
                             "Drive", "Ln", "Lane", "Way", "Ct", "Court", 
                             "Pl", "Place", "Circle", "Cir", "Square", "Sq"]
            
            return !streetTypes.contains(component)
        }
        
        // Join remaining components
        let suggestedName = filteredComponents.joined(separator: " ")
        
        // If we have a valid name, return it; otherwise use a default
        return suggestedName.isEmpty ? "My Home" : suggestedName
    }
}

// Updated HouseThought model to include weather reactions
extension HouseThought {
    enum Emotion: String, CaseIterable {
        case happy
        case content
        case neutral
        case worried
        case excited
        case tired
        
        var icon: String {
            switch self {
            case .happy: return "😊"
            case .content: return "😌"
            case .neutral: return "😐"
            case .worried: return "😟"
            case .excited: return "🤗"
            case .tired: return "😴"
            }
        }
    }
}
```

### UI Components

```swift
// AddressConfirmationView.swift
struct AddressConfirmationView: View {
    @StateObject private var viewModel: AddressConfirmationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Looking up your location...")
                        .padding()
                } else if let address = viewModel.suggestedAddress {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Is this your home address?")
                            .font(.headline)
                        
                        AddressCard(address: address)
                        
                        HStack {
                            Button("No, Edit") {
                                // Show address editor
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Yes, Confirm") {
                                Task {
                                    await viewModel.confirmAddress()
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
                
                if let error = viewModel.error {
                    ErrorView(error: error)
                }
            }
            .navigationTitle("Confirm Home Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.lookupCurrentAddress()
        }
    }
}

// Updated ContentView.swift
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @StateObject private var voiceViewModel: VoiceTranscriptionViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // House name and emotion
                    HouseHeaderView(
                        houseName: viewModel.houseName,
                        houseThought: viewModel.houseThought
                    )
                    
                    // Weather display
                    if let weather = viewModel.currentWeather,
                       let address = viewModel.homeAddress {
                        WeatherSummaryView(weather: weather, address: address)
                    }
                    
                    // Voice interface
                    ConversationView(viewModel: voiceViewModel)
                        .frame(height: 200)
                    
                    // Quick actions
                    QuickActionsView()
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await viewModel.loadHomeData()
            }
        }
    }
}

// HouseHeaderView.swift
struct HouseHeaderView: View {
    let houseName: String
    let houseThought: HouseThought
    
    var body: some View {
        VStack(spacing: 12) {
            // House name
            Text(houseName.isEmpty ? "Set House Name" : houseName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // House emotion and thought
            HStack(spacing: 8) {
                Text(houseThought.emotion.icon)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(houseThought.emotion.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(houseThought.thought)
                        .font(.body)
                        .italic()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// WeatherSummaryView.swift
struct WeatherSummaryView: View {
    let weather: Weather
    let address: Address
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Location header
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.secondary)
                Text(address.city)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Weather content
            HStack(alignment: .top, spacing: 16) {
                // Temperature
                VStack(alignment: .leading) {
                    Text(weather.temperature.formatted)
                        .font(.system(size: 48, weight: .light))
                    Text("Feels like \(weather.feelsLike.formatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Condition
                VStack(alignment: .trailing) {
                    Image(systemName: weather.condition.icon)
                        .font(.system(size: 40))
                        .symbolRenderingMode(.multicolor)
                    Text(weather.condition.rawValue.capitalized)
                        .font(.subheadline)
                }
            }
            
            // Additional details
            HStack(spacing: 20) {
                Label("\(Int(weather.humidity))%", systemImage: "humidity")
                Label("\(Int(weather.windSpeed)) mph", systemImage: "wind")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

### Service Container Integration

```swift
// ServiceContainer+Location.swift
extension ServiceContainer {
    private(set) lazy var locationService: LocationServiceProtocol = {
        LocationServiceImpl()
    }()
    
    private(set) lazy var weatherService: WeatherServiceProtocol = {
        WeatherKitServiceImpl()
    }()
    
    func makeAddressConfirmationViewModel() -> AddressConfirmationViewModel {
        AddressConfirmationViewModel(
            locationService: locationService,
            storageService: storageService
        )
    }
    
    func makeContentViewModel() -> ContentViewModel {
        ContentViewModel(
            weatherService: weatherService,
            locationService: locationService,
            storageService: storageService,
            notesService: notesService
        )
    }
}
```

### WeatherKit Service Implementation

```swift
// WeatherKitServiceImpl.swift
import WeatherKit
import CoreLocation
import Combine

@MainActor
class WeatherKitServiceImpl: WeatherServiceProtocol {
    private let weatherService = WeatherService.shared
    private let weatherUpdateSubject = PassthroughSubject<Weather, Never>()
    
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> {
        weatherUpdateSubject.eraseToAnyPublisher()
    }
    
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        // Fetch current weather and forecasts from WeatherKit
        let weather = try await weatherService.weather(for: location)
        
        // Convert WeatherKit data to our Weather model
        let currentWeather = weather.currentWeather
        let dailyForecast = weather.dailyForecast
        let hourlyForecast = weather.hourlyForecast
        
        let weatherData = Weather(
            temperature: Temperature(from: currentWeather.temperature),
            condition: WeatherCondition(from: currentWeather.condition),
            humidity: currentWeather.humidity,
            windSpeed: currentWeather.wind.speed.value,
            feelsLike: Temperature(from: currentWeather.apparentTemperature),
            uvIndex: currentWeather.uvIndex.value,
            pressure: currentWeather.pressure.value,
            visibility: currentWeather.visibility.value,
            dewPoint: currentWeather.dewPoint.value,
            forecast: dailyForecast.forecast.prefix(7).map { DailyForecast(from: $0) },
            hourlyForecast: hourlyForecast.forecast.prefix(24).map { HourlyForecast(from: $0) },
            lastUpdated: Date()
        )
        
        // Publish update
        weatherUpdateSubject.send(weatherData)
        
        return weatherData
    }
    
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather {
        let coordinate = address.coordinate
        return try await fetchWeather(for: coordinate)
    }
}

// Additional forecast models
struct DailyForecast: Codable {
    let date: Date
    let highTemperature: Temperature
    let lowTemperature: Temperature
    let condition: WeatherCondition
    let precipitationChance: Double
    
    init(from dayWeather: DayWeather) {
        self.date = dayWeather.date
        self.highTemperature = Temperature(from: dayWeather.highTemperature)
        self.lowTemperature = Temperature(from: dayWeather.lowTemperature)
        self.condition = WeatherCondition(from: dayWeather.condition)
        self.precipitationChance = dayWeather.precipitationChance
    }
}

struct HourlyForecast: Codable {
    let date: Date
    let temperature: Temperature
    let condition: WeatherCondition
    let precipitationChance: Double
    
    init(from hourWeather: HourWeather) {
        self.date = hourWeather.date
        self.temperature = Temperature(from: hourWeather.temperature)
        self.condition = WeatherCondition(from: hourWeather.condition)
        self.precipitationChance = hourWeather.precipitationChance
    }
}
```

### Required Capabilities and Entitlements

```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is needed to provide weather information for your home.</string>

<!-- Entitlements -->
<key>com.apple.developer.weatherkit</key>
<true/>
```

## House Name Management

### NotesService Extension
```swift
// NotesService+Extensions.swift
extension NotesServiceProtocol {
    // MARK: - House Name Management
    
    func getHouseName() async -> String? {
        let notesStore = try? await loadNotesStore()
        return notesStore?.questions.first { $0.text == "What is your house's name?" }
            .flatMap { questionId in
                notesStore?.notes.first { $0.questionId == questionId }?.content
            }
    }
    
    func saveHouseName(_ name: String) async throws {
        var notesStore = try await loadNotesStore()
        
        // Check if house name question exists
        if let existingQuestion = notesStore.questions.first(where: { $0.text == "What is your house's name?" }) {
            // Update existing note
            if let existingNote = notesStore.notes.first(where: { $0.questionId == existingQuestion.id }) {
                var updatedNote = existingNote
                updatedNote.content = name
                try await updateNote(updatedNote)
            } else {
                // Create new note for existing question
                let newNote = Note(
                    id: UUID(),
                    questionId: existingQuestion.id,
                    content: name,
                    createdAt: Date()
                )
                try await saveNote(newNote)
            }
        } else {
            // Create new question and note
            let newQuestion = Question(
                id: UUID(),
                text: "What is your house's name?",
                category: .general
            )
            try await addQuestion(newQuestion)
            
            let newNote = Note(
                id: UUID(),
                questionId: newQuestion.id,
                content: name,
                createdAt: Date()
            )
            try await saveNote(newNote)
        }
    }
    
    // MARK: - Weather Summary Management
    
    func getCurrentWeatherSummary() async -> String? {
        let notesStore = try? await loadNotesStore()
        return notesStore?.questions.first { $0.text == "What's the current weather like?" }
            .flatMap { question in
                notesStore?.notes.first { $0.questionId == question.id }?.content
            }
    }
    
    func saveWeatherSummary(_ weather: Weather, address: Address) async throws {
        var notesStore = try await loadNotesStore()
        
        // Format weather summary
        let summary = formatWeatherSummary(weather, address: address)
        
        // Check if weather question exists
        if let existingQuestion = notesStore.questions.first(where: { $0.text == "What's the current weather like?" }) {
            // Update existing note
            if let existingNote = notesStore.notes.first(where: { $0.questionId == existingQuestion.id }) {
                var updatedNote = existingNote
                updatedNote.content = summary
                updatedNote.lastModified = Date()
                try await updateNote(updatedNote)
            } else {
                // Create new note for existing question
                let newNote = Note(
                    id: UUID(),
                    questionId: existingQuestion.id,
                    content: summary,
                    createdAt: Date()
                )
                try await saveNote(newNote)
            }
        } else {
            // Create new question and note
            let newQuestion = Question(
                id: UUID(),
                text: "What's the current weather like?",
                category: .environment,
                displayOrder: 50
            )
            try await addQuestion(newQuestion)
            
            let newNote = Note(
                id: UUID(),
                questionId: newQuestion.id,
                content: summary,
                createdAt: Date()
            )
            try await saveNote(newNote)
        }
    }
    
    private func formatWeatherSummary(_ weather: Weather, address: Address) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var summary = "Weather in \(address.city) as of \(dateFormatter.string(from: weather.lastUpdated)):\n\n"
        
        summary += "🌡️ Temperature: \(weather.temperature.formatted) (feels like \(weather.feelsLike.formatted))\n"
        summary += "☁️ Condition: \(weather.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)\n"
        summary += "💧 Humidity: \(Int(weather.humidity * 100))%\n"
        summary += "💨 Wind: \(Int(weather.windSpeed)) mph\n"
        summary += "☀️ UV Index: \(weather.uvIndex)\n"
        summary += "🌡️ Pressure: \(Int(weather.pressure)) mb\n"
        summary += "👁️ Visibility: \(Int(weather.visibility)) miles\n"
        summary += "💦 Dew Point: \(Int(weather.dewPoint))°\n"
        
        if !weather.forecast.isEmpty {
            summary += "\n📅 Upcoming Forecast:\n"
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            
            for (index, day) in weather.forecast.prefix(3).enumerated() {
                let dayName = index == 0 ? "Today" : dayFormatter.string(from: day.date)
                summary += "\(dayName): \(day.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized), "
                summary += "High \(day.highTemperature.formatted), Low \(day.lowTemperature.formatted)"
                if day.precipitationChance > 0 {
                    summary += " (\(Int(day.precipitationChance * 100))% precipitation)"
                }
                summary += "\n"
            }
        }
        
        return summary
    }
}
```

### House Name UI
```swift
// HouseNameEditView.swift
struct HouseNameEditView: View {
    @Binding var houseName: String
    let suggestedName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("House Name")) {
                    TextField("Enter house name", text: $houseName)
                    
                    if !suggestedName.isEmpty && houseName != suggestedName {
                        Button("Use suggested: \(suggestedName)") {
                            houseName = suggestedName
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                
                Section(footer: Text("The house name is derived from your street address without the number and street type.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Set House Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveHouseName()
                            dismiss()
                        }
                    }
                    .disabled(houseName.isEmpty)
                }
            }
        }
    }
    
    private func saveHouseName() async {
        // Save to notes service
        try? await ServiceContainer.shared.notesService.saveHouseName(houseName)
    }
}
```

## Privacy Considerations

### Location Permission Flow
1. Request permission only when needed (lazy permission)
2. Explain why location is needed before requesting
3. Gracefully handle permission denial
4. Provide manual address entry as fallback

### Data Minimization
- Only store confirmed home address
- Don't track user movement
- Weather data cached for 15 minutes
- No location history maintained

## Testing Strategy

### Unit Tests
```swift
class LocationServiceTests: XCTestCase {
    func testAddressLookup() async throws {
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let address = try await locationService.lookupAddress(for: mockLocation)
        
        XCTAssertEqual(address.city, "San Francisco")
        XCTAssertEqual(address.state, "CA")
    }
    
    func testWeatherKitFetch() async throws {
        // Note: WeatherKit requires entitlements and active developer account
        // This test will only work with proper setup
        let coordinate = Coordinate(latitude: 37.7749, longitude: -122.4194)
        
        do {
            let weather = try await weatherService.fetchWeather(for: coordinate)
            
            XCTAssertNotNil(weather.temperature)
            XCTAssertNotNil(weather.condition)
            XCTAssertNotNil(weather.uvIndex)
            XCTAssertGreaterThan(weather.forecast.count, 0)
            XCTAssertGreaterThan(weather.hourlyForecast.count, 0)
        } catch {
            // Skip test if WeatherKit is not available (e.g., in CI)
            throw XCTSkip("WeatherKit not available in test environment")
        }
    }
}
```

### UI Tests
```swift
class AddressConfirmationUITests: XCTestCase {
    func testAddressConfirmationFlow() {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to address confirmation
        app.buttons["Set Home Address"].tap()
        
        // Wait for location lookup
        let confirmButton = app.buttons["Yes, Confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        
        // Confirm address
        confirmButton.tap()
        
        // Verify weather appears on home view
        XCTAssertTrue(app.staticTexts["°F"].exists)
    }
}
```

## Implementation Timeline

### Phase 1: Foundation (Week 1)
- Core Location integration
- Permission management
- Basic address lookup
- WeatherKit entitlement setup

### Phase 2: Address Confirmation (Week 2)
- Address confirmation UI
- Address storage
- Manual entry fallback

### Phase 3: Weather Integration (Week 3)
- WeatherKit service implementation
- Weather data models and conversions
- Native iOS weather integration

### Phase 4: Home View Integration (Week 4)
- Weather display on ContentView
- Automatic updates via WeatherKit
- Error handling and fallbacks

### Phase 5: Advanced Features (Weeks 5-6)
- Geofencing setup
- Location-based automation
- Room detection (if hardware supports)

## Requirements

- **iOS Version**: iOS 16.0+ (required for WeatherKit)
- **Apple Developer Account**: Required for WeatherKit entitlement
- **Capabilities**: WeatherKit, Location Services

## Success Metrics

- Location permission grant rate > 80%
- Address confirmation completion rate > 90%
- Weather data availability > 99.9% (via WeatherKit)
- Weather update latency < 500ms (native integration)
- User satisfaction with location features > 4.5/5

---

**Status**: In Planning  
**Priority**: High  
**Estimated Start**: Q1 2025  
**Estimated Completion**: Q2 2025