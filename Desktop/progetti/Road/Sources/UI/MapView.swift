import SwiftUI
import MapKit
import CoreLocation

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Route Info Model

struct RouteInfo {
    let placeName: String
    let distanceKm: Double
    let travelMinutes: Int
    let fuelLiters: Double  // ~4L/100km for a 125cc

    var distanceString: String {
        distanceKm < 1 ? "\(Int(distanceKm * 1000)) m" : String(format: "%.1f km", distanceKm)
    }
    var timeString: String {
        travelMinutes < 60 ? "\(travelMinutes) min" : "\(travelMinutes / 60)h \(travelMinutes % 60)min"
    }
    var fuelString: String { String(format: "%.1f L", fuelLiters) }
}

// MARK: - Search Result

struct PlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Map View

struct MapView: View {
    @StateObject private var locationManager = LocationManager()

    // Map camera
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Search
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchResults: [PlaceResult] = []
    @State private var isSearching = false

    // Selected destination & route
    @State private var selectedPlace: PlaceResult? = nil
    @State private var routePolyline: MKPolyline? = nil
    @State private var routeInfo: RouteInfo? = nil
    @State private var isRoutingLoading = false

    // Search debounce
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: Map
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let place = selectedPlace {
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(.red)
                }

                if let poly = routePolyline {
                    MapPolyline(poly)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls { }
            .ignoresSafeArea()

            // MARK: Top Glass Bar
            VStack(spacing: 0) {
                topBar
                    .padding(.top, topSafeArea)
                Spacer()
            }

            // MARK: Bottom Route Card
            if let info = routeInfo {
                VStack {
                    Spacer()
                    routeCard(info)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            locationManager.requestLocation()
            if let loc = locationManager.userLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    latitudinalMeters: 3000,
                    longitudinalMeters: 3000
                ))
            }
        }
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in
            if let loc = locationManager.userLocation, selectedPlace == nil {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    latitudinalMeters: 3000,
                    longitudinalMeters: 3000
                ))
            }
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack(spacing: 10) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                if isSearchActive {
                    TextField("Cerca città o indirizzo...", text: $searchText)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, val in
                            triggerSearch(val)
                        }
                        .onSubmit { triggerSearch(searchText) }
                } else {
                    Text(selectedPlace?.name ?? "Cerca destinazione...")
                        .font(.system(size: 15))
                        .foregroundStyle(selectedPlace == nil ? .secondary : .primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSearchActive && !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchActive = true
                }
            }
            .frame(maxWidth: isSearchActive ? .infinity : .infinity)

            if !isSearchActive {
                // Re-center button
                glassIconBtn("location.fill") {
                    if let loc = locationManager.userLocation {
                        withAnimation {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: loc,
                                latitudinalMeters: 2000,
                                longitudinalMeters: 2000
                            ))
                        }
                    }
                }

                // Settings shortcut (no-op here, tab handles it)
                glassIconBtn("gear") {
                    AppManager.shared.selectedTab = 2
                }
            } else {
                // Cancel
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchActive = false
                        searchText = ""
                        searchResults = []
                    }
                } label: {
                    Text("Annulla")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchActive)
        .overlay(alignment: .top) {
            // Search results dropdown
            if isSearchActive && !searchResults.isEmpty {
                searchDropdown
                    .offset(y: 56)
            }
        }
    }

    // MARK: - Search Dropdown

    var searchDropdown: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                Button {
                    selectPlace(result)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(result.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if result.id != searchResults.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }

    // MARK: - Route Card

    func routeCard(_ info: RouteInfo) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Destination name
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.placeName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text("Solo strade consentite per 125cc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPlace = nil
                        routeInfo = nil
                        routePolyline = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Stats row
            HStack(spacing: 0) {
                statCell(icon: "arrow.triangle.swap", value: info.distanceString, label: "Distanza", color: .blue)
                Divider().frame(height: 44)
                statCell(icon: "clock", value: info.timeString, label: "Tempo", color: .orange)
                Divider().frame(height: 44)
                statCell(icon: "fuelpump", value: info.fuelString, label: "Carburante", color: .green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            // Start button
            Button {
                // Future: launch turn-by-turn
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 18))
                    Text("Avvia navigazione")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: -4)
        .padding(.horizontal, 0)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routeInfo != nil)
    }

    func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Glass Icon Button

    func glassIconBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: Circle())
    }

    // MARK: - Search Logic

    func triggerSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    @MainActor
    func performSearch(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let loc = locationManager.userLocation {
            request.region = MKCoordinateRegion(
                center: loc,
                latitudinalMeters: 200_000,
                longitudinalMeters: 200_000
            )
        }

        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            searchResults = response.mapItems.prefix(5).map { item in
                PlaceResult(
                    name: item.name ?? "Luogo",
                    subtitle: [item.placemark.locality, item.placemark.administrativeArea]
                        .compactMap { $0 }.joined(separator: ", "),
                    coordinate: item.placemark.coordinate
                )
            }
        }
    }

    func selectPlace(_ place: PlaceResult) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSearchActive = false
            searchText = ""
            searchResults = []
            selectedPlace = place
        }

        // Focus map on destination
        cameraPosition = .region(MKCoordinateRegion(
            center: place.coordinate,
            latitudinalMeters: 6000,
            longitudinalMeters: 6000
        ))

        // Calculate route
        calculateRoute(to: place)
    }

    func calculateRoute(to place: PlaceResult) {
        isRoutingLoading = true

        let destination = MKPlacemark(coordinate: place.coordinate)
        let request = MKDirections.Request()
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        // Exclude highways (tollways) — approximate for 125cc
        request.requestsAlternateRoutes = false

        if let loc = locationManager.userLocation {
            let origin = MKPlacemark(coordinate: loc)
            request.source = MKMapItem(placemark: origin)
        } else {
            request.source = MKMapItem.forCurrentLocation()
        }

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                self.isRoutingLoading = false
                guard let route = response?.routes.first else { return }

                self.routePolyline = route.polyline

                let distKm = route.distance / 1000
                let mins = Int(route.expectedTravelTime / 60)
                let fuel = distKm * 0.04 // 4L/100km

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.routeInfo = RouteInfo(
                        placeName: place.name,
                        distanceKm: distKm,
                        travelMinutes: mins,
                        fuelLiters: fuel
                    )
                }

                // Fit camera to route
                self.cameraPosition = .rect(route.polyline.boundingMapRect.insetBy(dx: -5000, dy: -5000))
            }
        }
    }

    // MARK: - Safe Area helper

    var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44
    }
}
