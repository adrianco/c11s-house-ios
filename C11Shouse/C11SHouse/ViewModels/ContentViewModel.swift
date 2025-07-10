/*
 * CONTEXT & PURPOSE:
 * ContentViewModel manages the main screen's state including weather data, house emotions,
 * and location information. It coordinates between LocationService and WeatherKitService
 * to provide real-time weather updates and emotion-based house responses.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - ObservableObject for SwiftUI integration
 *   - Combines publishers for reactive updates
 *   - Weather-based emotion mapping for house personality
 *   - House name generation from street address
 *   - Auto-refresh weather every 30 minutes
 *   - Comprehensive error handling
 *   - WeatherKit integration for Apple ecosystem
 *
 * - 2025-01-09: Refactored to use coordinators
 *   - Delegated weather logic to WeatherCoordinator
 *   - Delegated address parsing to AddressManager
 *   - Removed direct weather service dependency
 *   - Weather state now accessed through coordinator
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import Combine
import CoreLocation

@MainActor
class ContentViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var houseName: String = "Your House"
    @Published var houseThought: HouseThought?
    @Published var currentAddress: Address?
    @Published var hasLocationPermission = false
    
    // Weather state (delegated to coordinator)
    var currentWeather: Weather? { weatherCoordinator.currentWeather }
    var isLoadingWeather: Bool { weatherCoordinator.isLoadingWeather }
    var weatherError: Error? { weatherCoordinator.weatherError }
    
    // Services and Coordinators
    private let locationService: LocationServiceProtocol
    private let notesService: NotesServiceProtocol
    private let weatherCoordinator: WeatherCoordinator
    private let addressManager: AddressManager
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var weatherTimer: Timer?
    
    init(
        locationService: LocationServiceProtocol,
        weatherCoordinator: WeatherCoordinator,
        notesService: NotesServiceProtocol,
        addressManager: AddressManager
    ) {
        self.locationService = locationService
        self.weatherCoordinator = weatherCoordinator
        self.notesService = notesService
        self.addressManager = addressManager
        
        setupBindings()
        loadSavedData()
    }
    
    private func setupBindings() {
        // Monitor location authorization
        locationService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
                if self?.hasLocationPermission == true {
                    Task { await self?.loadAddressAndWeather() }
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to weather updates from coordinator
        weatherCoordinator.$currentWeather
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] weather in
                self?.updateHouseEmotionForWeather(weather)
            }
            .store(in: &cancellables)
        
        // Monitor for address changes in UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkForAddressUpdate()
            }
            .store(in: &cancellables)
        
        // Monitor for all questions complete notification
        NotificationCenter.default.publisher(for: Notification.Name("AllQuestionsComplete"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload everything when questions are complete
                self?.loadSavedData()
            }
            .store(in: &cancellables)
        
        // Setup weather refresh timer (30 minutes)
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task { [weak self] in
                await self?.refreshWeather()
            }
        }
    }
    
    private func loadSavedData() {
        // Load saved address
        if let addressData = UserDefaults.standard.data(forKey: "confirmedHomeAddress"),
           let address = try? JSONDecoder().decode(Address.self, from: addressData) {
            currentAddress = address
            
            // If we have an address, fetch weather
            Task {
                await refreshWeather()
            }
        }
        
        // Load saved house name from notes
        Task {
            if let savedName = await notesService.getHouseName() {
                houseName = savedName
            }
        }
    }
    
    func requestLocationPermission() async {
        await locationService.requestLocationPermission()
    }
    
    func loadAddressAndWeather() async {
        // First check if we already have a saved address
        if currentAddress != nil {
            // We have an address, fetch weather
            await refreshWeather()
            return
        }
        
        // No saved address, prompt user to set it via conversation
        updateHouseEmotionForNoAddress()
    }
    
    func refreshWeather() async {
        guard let address = currentAddress else { return }
        
        do {
            _ = try await weatherCoordinator.fetchWeather(for: address)
        } catch {
            updateHouseEmotionForError()
        }
    }
    
    func confirmAddress(_ address: Address) async {
        do {
            try await locationService.confirmAddress(address)
            currentAddress = address
            await refreshWeather()
        } catch {
            print("Failed to confirm address: \(error)")
        }
    }
    
    private func generateHouseNameFromAddress(_ address: Address) {
        houseName = AddressParser.generateHouseName(from: address.street)
        
        if houseName != "My House" {
            // Save to notes
            Task {
                await notesService.saveHouseName(houseName)
            }
        }
    }
    
    private func updateHouseEmotionForWeather(_ weather: Weather?) {
        guard let weather = weather else { return }
        
        let emotion: HouseEmotion
        let thought: String
        let intensity: Double
        
        switch weather.condition {
        case .thunderstorms, .strongStorms, .isolatedThunderstorms, .scatteredThunderstorms:
            emotion = .worried
            thought = "Those thunderstorms sound intense. I hope everyone stays safe inside."
            intensity = 0.8
            
        case .hurricane, .tropicalStorm:
            emotion = .worried
            thought = "This storm is really serious. Let's make sure everything is secure."
            intensity = 1.0
            
        case .blizzard, .heavySnow:
            emotion = .worried
            thought = "That's a lot of snow! I hope the heating is working well."
            intensity = 0.7
            
        case .freezingRain, .freezingDrizzle, .hail, .wintryMix:
            emotion = .concerned
            thought = "The ice could be dangerous. Please be careful if you go outside."
            intensity = 0.6
            
        case .heavyRain:
            emotion = .concerned
            thought = "It's really pouring out there. Good thing we're cozy inside."
            intensity = 0.5
            
        case .rain, .drizzle, .sunShowers:
            emotion = .thoughtful
            thought = "I love the sound of rain on the roof. Very peaceful."
            intensity = 0.3
            
        case .hot:
            emotion = .tired
            thought = "It's quite warm today. Let me help keep things cool inside."
            intensity = 0.4
            
        case .frigid:
            emotion = .concerned
            thought = "Brrr, it's freezing! I'll make sure to keep everyone warm."
            intensity = 0.6
            
        case .clear, .mostlyClear:
            emotion = .happy
            thought = "What a beautiful day! Perfect weather to enjoy."
            intensity = 0.2
            
        case .partlyCloudy, .mostlyCloudy:
            emotion = .content
            thought = "Nice mild weather today. Very comfortable."
            intensity = 0.2
            
        case .foggy:
            emotion = .curious
            thought = "The fog makes everything look mysterious outside."
            intensity = 0.3
            
        case .windy, .breezy:
            emotion = .neutral
            thought = "Feeling the breeze through the windows. Fresh air is nice."
            intensity = 0.2
            
        default:
            emotion = .neutral
            thought = "Monitoring the weather to keep everyone comfortable."
            intensity = 0.1
        }
        
        // Add temperature context
        var finalThought = thought
        let temp = weather.temperature.value
        if weather.temperature.unit == .celsius {
            if temp > 30 {
                finalThought += " It's \(weather.temperature.formatted) outside."
            } else if temp < 0 {
                finalThought += " It's \(weather.temperature.formatted) - quite cold!"
            }
        } else { // Fahrenheit
            if temp > 86 {
                finalThought += " It's \(weather.temperature.formatted) outside."
            } else if temp < 32 {
                finalThought += " It's \(weather.temperature.formatted) - quite cold!"
            }
        }
        
        houseThought = HouseThought(
            thought: finalThought,
            emotion: emotion,
            category: .observation,
            confidence: 1.0 - intensity, // Higher intensity = lower confidence
            context: "Weather observation"
        )
    }
    
    private func updateHouseEmotionForError() {
        // Check if this is a sandbox error
        if let error = weatherError as? WeatherError, case .sandboxRestriction = error {
            houseThought = HouseThought(
                thought: "Weather service isn't available in the simulator. It works great on real devices!",
                emotion: .neutral,
                category: .observation,
                confidence: 0.8,
                context: "Simulator limitation"
            )
        } else {
            houseThought = HouseThought(
                thought: "I'm having trouble checking the weather right now. I'll try again soon.",
                emotion: .confused,
                category: .observation,
                confidence: 0.5,
                context: "Weather service error"
            )
        }
    }
    
    private func updateHouseEmotionForNoAddress() {
        houseThought = HouseThought(
            thought: "Hi! Let's have a conversation so I can learn about your home and help you better.",
            emotion: .curious,
            category: .suggestion,
            confidence: 0.9,
            context: "Setup needed"
        )
    }
    
    
    private func checkForAddressUpdate() {
        // Check if we have a new address that we haven't loaded yet
        if let addressData = UserDefaults.standard.data(forKey: "confirmedHomeAddress"),
           let address = try? JSONDecoder().decode(Address.self, from: addressData) {
            
            // Only update if the address is different
            if currentAddress?.fullAddress != address.fullAddress {
                currentAddress = address
                
                // Fetch weather for the new address
                Task {
                    await refreshWeather()
                }
            }
        }
    }
}