/*
 * CONTEXT & PURPOSE:
 * AddressConfirmationView allows users to confirm or edit their detected home address.
 * This view is presented when the app first detects the user's location, ensuring
 * accurate address information for weather services and house naming.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Modal presentation with sheet
 *   - Editable text fields for address components
 *   - Map preview showing the location
 *   - Confirm and cancel actions
 *   - Validation to ensure all fields are filled
 *   - Automatic dismissal after confirmation
 *   - Uses ContentViewModel for address management
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
import MapKit

struct AddressConfirmationView: View {
    @EnvironmentObject private var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var street: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var postalCode: String = ""
    @State private var country: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let detectedAddress: Address
    
    init(address: Address) {
        self.detectedAddress = address
        _street = State(initialValue: address.street)
        _city = State(initialValue: address.city)
        _state = State(initialValue: address.state)
        _postalCode = State(initialValue: address.postalCode)
        _country = State(initialValue: address.country)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map preview
                Map(coordinateRegion: .constant(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: detectedAddress.coordinate.latitude,
                            longitude: detectedAddress.coordinate.longitude
                        ),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                ), annotationItems: [detectedAddress]) { address in
                    MapPin(
                        coordinate: CLLocationCoordinate2D(
                            latitude: address.coordinate.latitude,
                            longitude: address.coordinate.longitude
                        ),
                        tint: .blue
                    )
                }
                .frame(height: 200)
                .cornerRadius(12)
                .padding()
                
                // Address form
                Form {
                    Section("Confirm Your Home Address") {
                        TextField("Street", text: $street)
                            .textContentType(.streetAddressLine1)
                        
                        TextField("City", text: $city)
                            .textContentType(.addressCity)
                        
                        HStack {
                            TextField("State", text: $state)
                                .textContentType(.addressState)
                            
                            TextField("Postal Code", text: $postalCode)
                                .textContentType(.postalCode)
                                .frame(maxWidth: 120)
                        }
                        
                        TextField("Country", text: $country)
                            .textContentType(.countryName)
                    }
                    
                    Section {
                        Text("Your house will be named based on the street name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                    
                    Button("Confirm Address") {
                        confirmAddress()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidAddress)
                }
                .padding()
            }
            .navigationTitle("Confirm Address")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Address Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isValidAddress: Bool {
        !street.isEmpty && !city.isEmpty && !state.isEmpty && !postalCode.isEmpty && !country.isEmpty
    }
    
    private func confirmAddress() {
        guard isValidAddress else {
            alertMessage = "Please fill in all address fields"
            showingAlert = true
            return
        }
        
        let confirmedAddress = Address(
            street: street,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country,
            coordinate: detectedAddress.coordinate
        )
        
        Task {
            await viewModel.confirmAddress(confirmedAddress)
            dismiss()
        }
    }
}

// MARK: - Address MapItem Conformance

extension Address: Identifiable {
    var id: String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}

#Preview {
    AddressConfirmationView(
        address: Address(
            street: "123 Main Street",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105",
            country: "United States",
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
        )
    )
    .environmentObject(ContentViewModel(
        locationService: LocationServiceImpl(),
        weatherService: WeatherKitServiceImpl(),
        notesService: NotesServiceImpl()
    ))
}