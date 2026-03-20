import SwiftUI
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoadingAuth = true

    let supabase = SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseAnonKey
    )

    init() {
        Task { await listenToAuth() }
    }

    private func listenToAuth() async {
        isLoadingAuth = true
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                currentUser = session?.user
                isAuthenticated = session != nil
            case .signedOut, .passwordRecovery, .userDeleted:
                currentUser = nil
                isAuthenticated = false
            default:
                break
            }
            isLoadingAuth = false
        }
    }

    var displayName: String {
        currentUser?.userMetadata["full_name"]?.stringValue
            ?? currentUser?.email
            ?? "Hiker"
    }
}
