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
 * - 2025-07-15: Refactored to use centralized AppState
 *   - Removed local state properties in favor of AppState
 *   - State changes now propagate through AppState
 *   - Simplified state management and reduced duplication
 *   - Weather and house emotions updated in AppState
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import Combine
import CoreLocation

@MainActor
class ContentViewModel: ObservableObject {
    // Reference to centralized app state
    private let appState: AppState
    
    // Published properties that mirror AppState for UI binding
    @Published var houseName: String = "Your House"
    @Published var houseThought: HouseThought?
    @Published var currentAddress: Address?
    @Published var hasLocationPermission: Bool = false
    
    // Weather state from AppState
    @Published var currentWeather: Weather?
    @Published var isLoadingWeather: Bool = false
    @Published var weatherError: Error?
    
    // Services and Coordinators
    private let locationService: LocationServiceProtocol
    private let notesService: NotesServiceProtocol
    private let weatherCoordinator: WeatherCoordinator
    private let addressManager: AddressManager
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var weatherTimer: Timer?
    
    // Debounce for UserDefaults changes
    private var addressUpdateWorkItem: DispatchWorkItem?
    private var lastCheckedAddressHash: String?
    
    // Prevent duplicate weather fetches
    private var isCurrentlyFetchingWeather = false
    private var lastWeatherFetchTime: Date?
    
    init(
        appState: AppState,
        locationService: LocationServiceProtocol,
        weatherCoordinator: WeatherCoordinator,
        notesService: NotesServiceProtocol,
        addressManager: AddressManager
    ) {
        self.appState = appState
        self.locationService = locationService
        self.weatherCoordinator = weatherCoordinator
        self.notesService = notesService
        self.addressManager = addressManager
        
        // Always setup bindings and load saved data
        setupBindings()
        loadSavedData()
        
        // Log initial state
        print("[ContentViewModel] Init complete - currentWeather: \(currentWeather != nil ? "exists" : "nil")")
        print("[ContentViewModel] Init complete - houseName: \(houseName)")
        print("[ContentViewModel] Init complete - address: \(currentAddress?.fullAddress ?? "nil")")
    }
    
    private func setupMinimalBindings() {
        // Only sync with AppState, don't subscribe to service publishers
        appState.$houseName
            .receive(on: DispatchQueue.main)
            .assign(to: &$houseName)
            
        appState.$currentHouseThought
            .receive(on: DispatchQueue.main)
            .assign(to: &$houseThought)
            
        appState.$homeAddress
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentAddress)
            
        appState.$hasLocationPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasLocationPermission)
            
        appState.$currentWeather
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentWeather)
            
        appState.$isLoadingWeather
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingWeather)
            
        appState.$weatherError
            .receive(on: DispatchQueue.main)
            .assign(to: &$weatherError)
    }
    
    private func setupBindings() {
        // Sync with AppState
        appState.$houseName
            .receive(on: DispatchQueue.main)
            .assign(to: &$houseName)
            
        appState.$currentHouseThought
            .receive(on: DispatchQueue.main)
            .assign(to: &$houseThought)
            
        appState.$homeAddress
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentAddress)
            
        appState.$hasLocationPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasLocationPermission)
            
        appState.$currentWeather
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentWeather)
            
        appState.$isLoadingWeather
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingWeather)
            
        appState.$weatherError
            .receive(on: DispatchQueue.main)
            .assign(to: &$weatherError)
        
        // Monitor location authorization
        locationService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                let hasPermission = status == .authorizedWhenInUse || status == .authorizedAlways
                self?.appState.updatePermissions(location: hasPermission)
                // Weather will be fetched when address is updated or by timer
            }
            .store(in: &cancellables)
        
        // Subscribe to weather updates from coordinator
        weatherCoordinator.$currentWeather
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather in
                guard let self = self else { return }
                
                print("[ContentViewModel] Weather update received: \(weather?.condition.rawValue ?? "nil")")
                
                // Update weather in AppState (always update, even if nil)
                self.appState.updateWeatherState(weather: weather, isLoading: false)
                
                // Only update weather-based emotions if setup is complete
                Task {
                    let requiredComplete = await self.notesService.areAllRequiredQuestionsAnswered()
                    if requiredComplete, let weather = weather {
                        await MainActor.run {
                            self.updateHouseEmotionForWeather(weather)
                        }
                    }
                    // Otherwise keep the curious emotion for setup
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to weather loading state
        weatherCoordinator.$isLoadingWeather
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.appState.updateWeatherState(isLoading: isLoading)
            }
            .store(in: &cancellables)
            
        // Subscribe to weather errors
        weatherCoordinator.$weatherError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.appState.updateWeatherState(error: error)
            }
            .store(in: &cancellables)
        
        // Monitor for address changes in UserDefaults with debouncing
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleAddressUpdateCheck()
            }
            .store(in: &cancellables)
        
        // Monitor for all questions complete notification
        NotificationCenter.default.publisher(for: Notification.Name("AllQuestionsComplete"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Weather will be fetched when address is updated or by timer
                // Just update the house emotion to reflect completion
                self?.updateHouseEmotionForKnownUser()
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
        // Load address from NotesService since we no longer use UserDefaults
        Task {
            if let address = await addressManager.loadSavedAddress() {
                await MainActor.run {
                    appState.homeAddress = address
                }
                // Fetch weather for the loaded address
                await refreshWeather()
            }
        }
    }
    
    
    
    func loadAddressAndWeather() async {
        // Check if required questions are answered
        let requiredComplete = await notesService.areAllRequiredQuestionsAnswered()
        
        if !requiredComplete {
            // Show curious emotion when required questions aren't answered
            updateHouseEmotionForUnansweredQuestions()
            return
        }
        
        // If required questions are answered, we should have an address
        // Load it from UserDefaults if not already loaded
        if currentAddress == nil {
            loadSavedData()
        }
        
        // Set appropriate house emotion based on setup status
        // Weather will be fetched by loadSavedData() or address update detection
        if currentAddress != nil {
            updateHouseEmotionForKnownUser()
        } else {
            // This shouldn't happen if required questions are truly answered
            // But show a friendly default state
            updateHouseEmotionForKnownUser()
        }
    }
    
    func refreshWeather() async {
        print("[ContentViewModel] 🌤️ refreshWeather() called")
        guard let address = appState.homeAddress else { 
            print("[ContentViewModel] ⚠️ No current address available for weather fetch")
            return 
        }
        
        print("[ContentViewModel] Fetching weather for: \(address.fullAddress)")
        print("[ContentViewModel] Current weather before fetch: \(currentWeather != nil ? "exists" : "nil")")
        do {
            let weather = try await weatherCoordinator.fetchWeather(for: address)
            print("[ContentViewModel] ✅ Weather fetch successful: \(weather.condition)")
            print("[ContentViewModel] Temperature: \(weather.temperature.formatted)")
            print("[ContentViewModel] Current weather after fetch: \(currentWeather != nil ? "exists" : "nil")")
        } catch {
            print("[ContentViewModel] ❌ Weather fetch failed: \(error)")
            // Only update emotion for error if all required questions are answered
            let requiredComplete = await notesService.areAllRequiredQuestionsAnswered()
            if requiredComplete {
                print("[ContentViewModel] All questions complete, updating emotion for error")
                updateHouseEmotionForError()
            } else {
                print("[ContentViewModel] Questions incomplete, keeping curious emotion")
            }
            // Otherwise keep the curious emotion for setup
        }
    }
    
    func confirmAddress(_ address: Address) async {
        do {
            try await locationService.confirmAddress(address)
            appState.homeAddress = address
            await refreshWeather()
        } catch {
            print("Failed to confirm address: \(error)")
        }
    }
    
    private func generateHouseNameFromAddress(_ address: Address) {
        let name = AddressParser.generateHouseName(from: address.street)
        appState.houseName = name
        
        if name != "My House" {
            // Save to notes
            Task {
                await notesService.saveHouseName(name)
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
        
        let houseThought = HouseThought(
            thought: finalThought,
            emotion: emotion,
            category: .observation,
            confidence: 1.0 - intensity, // Higher intensity = lower confidence
            context: "Weather observation"
        )
        appState.updateHouseEmotion(houseThought)
    }
    
    private func updateHouseEmotionForError() {
        // Check if this is a sandbox error
        let thought: HouseThought
        if let error = appState.weatherError as? WeatherError, case .sandboxRestriction = error {
            thought = HouseThought(
                thought: "Weather service isn't available in the simulator. It works great on real devices!",
                emotion: .neutral,
                category: .observation,
                confidence: 0.8,
                context: "Simulator limitation"
            )
        } else {
            thought = HouseThought(
                thought: "I'm having trouble checking the weather right now. I'll try again soon.",
                emotion: .confused,
                category: .observation,
                confidence: 0.5,
                context: "Weather service error"
            )
        }
        appState.updateHouseEmotion(thought)
    }
    
    private func updateHouseEmotionForNoAddress() {
        let thought = HouseThought(
            thought: "Hi! Let's have a conversation so I can learn about your home and help you better.",
            emotion: .curious,
            category: .suggestion,
            confidence: 0.9,
            context: "Setup needed"
        )
        appState.updateHouseEmotion(thought)
    }
    
    private func updateHouseEmotionForUnansweredQuestions() {
        let thought = HouseThought(
            thought: "I'm curious to learn more about you and your home. Let's chat!",
            emotion: .curious,
            category: .question,
            confidence: 0.9,
            context: "Questions pending"
        )
        appState.updateHouseEmotion(thought)
    }
    
    private func updateHouseEmotionForKnownUser() {
        let thought = HouseThought(
            thought: "Welcome back! I'm here to help you manage your home.",
            emotion: .happy,
            category: .greeting,
            confidence: 0.9,
            context: "User known"
        )
        appState.updateHouseEmotion(thought)
    }
    
    
    private func scheduleAddressUpdateCheck() {
        // Cancel any existing work item
        addressUpdateWorkItem?.cancel()
        
        // Create a new work item with a delay
        addressUpdateWorkItem = DispatchWorkItem { [weak self] in
            self?.checkForAddressUpdate()
        }
        
        // Schedule it with a 0.5 second delay to debounce rapid changes
        if let workItem = addressUpdateWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }
    
    private func checkForAddressUpdate() {
        // Check if we have a new address from NotesService
        Task {
            if let address = await addressManager.loadSavedAddress() {
                // Create a hash of the address to check if it's truly different
                let addressHash = "\(address.fullAddress)-\(address.coordinate.latitude)-\(address.coordinate.longitude)"
                
                // Only update if the address hash is different from last check
                if lastCheckedAddressHash != addressHash {
                    print("[ContentViewModel] 📍 Address update detected: \(address.fullAddress)")
                    lastCheckedAddressHash = addressHash
                    
                    // Only update if the address is different from current state
                    if appState.homeAddress?.fullAddress != address.fullAddress {
                        print("[ContentViewModel] ✅ New address, updating state and fetching weather")
                        await MainActor.run {
                            appState.homeAddress = address
                        }
                        
                        // Fetch weather for the new address
                        await refreshWeather()
                    }
                }
            } else if lastCheckedAddressHash != nil {
                // Address was removed
                print("[ContentViewModel] Address removed from NotesService")
                lastCheckedAddressHash = nil
            }
        }
    }
}