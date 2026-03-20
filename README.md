# Hitrekk iOS

Native iOS app for **Hitrekk – 3D Hiking Explorer**, built with SwiftUI.

## Features

- **3D Terrain Map** — MapLibre Native iOS with DEM hillshade and terrain pitch
- **GPX Import** — Drag-drop or file picker, multi-file support
- **Elevation Profile** — Interactive Swift Charts with chart↔map hover sync
- **Speed Analytics** — Moving/rest time detection, max speed (98th percentile), avg speed
- **Photo Geotagging** — Import photos from library, EXIF GPS extraction, matched to nearest route
- **Dashboard** — All-time stats: total distance, hike count, time breakdown, personal records
- **Authentication** — Supabase email/password with email confirmation
- **Route Persistence** — Saved to Supabase (PostgreSQL + Storage for photos)
- **iPad / iPhone adaptive** — NavigationSplitView on iPad, sheet-based on iPhone

## Requirements

- Xcode 16+
- iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to regenerate `.xcodeproj`)

## Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/robstok/hike-map-ios
   cd hike-map-ios
   ```

2. **Open the project**
   ```bash
   open HikeMap.xcodeproj
   ```
   Xcode will automatically resolve Swift Package dependencies (MapLibre + Supabase) on first open.

3. **Configure Supabase** (optional — already set for the existing project)
   Edit `HikeMap/App/Config.swift`:
   ```swift
   static let supabaseURL    = "https://your-project.supabase.co"
   static let supabaseAnonKey = "your-anon-key"
   ```

4. **Set your Development Team** in Xcode → HikeMap target → Signing & Capabilities, or add `DEVELOPMENT_TEAM` to `project.yml` and re-run `xcodegen`.

5. **Build & Run** on a device or simulator (iPhone or iPad).

## Regenerate Xcode project

If you change `project.yml`:
```bash
brew install xcodegen  # one-time
xcodegen generate
```

## Architecture

```
HikeMap/
  App/
    HikeMapApp.swift      # @main entry point
    AppState.swift        # Auth state (ObservableObject)
    Config.swift          # All constants (Supabase keys, colours, map URLs)
  Models/
    Route.swift           # Route + RouteData structs
    GPXPoint.swift        # Track point (coord, ele, time)
    SpeedAnalytics.swift  # Analytics results struct
    PhotoItem.swift       # Photo with GPS metadata
  Services/
    GPXParser.swift       # NSXMLParser-based GPX → [GPXPoint]
    AnalyticsService.swift# Speed analytics (port of analytics.js)
    RouteStore.swift      # In-memory store + Supabase persistence (@MainActor ObservableObject)
    SupabaseService.swift # DB/Storage operations
    PhotoService.swift    # EXIF extraction + route matching
  Views/
    ContentView.swift     # Auth gate (loading → auth → main)
    MainView.swift        # Root app view (iPad split / iPhone sheet)
    Auth/AuthView.swift   # Sign in, sign up, forgot password
    Map/
      MapLibreView.swift  # UIViewRepresentable wrapper
      MapCoordinator.swift# MLNMapViewDelegate + layer management
    Routes/
      RouteListView.swift # Route list with CRUD actions
      RouteStatsView.swift# Stats grid for active route
    Elevation/
      ElevationChartView.swift  # Swift Charts elevation profile
    Photos/
      PhotoPickerView.swift     # PhotosPicker + map markers + lightbox
    Dashboard/
      DashboardView.swift       # All-time stats modal
    Shared/
      ToastView.swift           # Toast notification system
```

## Key patterns

- **Event-free architecture** — SwiftUI `@Published` + `@ObservedObject` replaces the web app's custom event bus
- **@MainActor RouteStore** — All route mutations happen on the main actor; Supabase calls dispatched to background `Task`s
- **Adaptive layout** — `horizontalSizeClass` switches between iPad NavigationSplitView and iPhone sheet-based UI
- **Hover sync** — `@Binding var hoverCoordinate` passed between ElevationChartView and MapLibreView

## Web app

The original web app lives at [hike-map](https://github.com/robstok/hike-map).
