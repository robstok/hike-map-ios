import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoadingAuth {
                SplashView()
            } else if appState.isAuthenticated {
                MainView(supabaseService: SupabaseService(client: appState.supabase))
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.isLoadingAuth)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0d1117").ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(colors: [Config.accent, Color(hex: "#FF9962")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Hitrekk")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Config.accent, Color(hex: "#FF9962")],
                                      startPoint: .leading, endPoint: .trailing)
                    )
                ProgressView()
                    .tint(Config.accent)
                    .padding(.top, 8)
            }
        }
    }
}
