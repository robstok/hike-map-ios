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

    // MARK: — Auth actions (update state directly, don't wait for stream)

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
    }

    func signUp(email: String, password: String, fullName: String) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        // Don't set isAuthenticated — user must confirm email first
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    // MARK: — Stream listener (handles token refresh, remote sign-out, app relaunch)

    private func listenToAuth() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                currentUser = session?.user
                isAuthenticated = session != nil
                isLoadingAuth = false
            case .tokenRefreshed, .userUpdated:
                currentUser = session?.user
            case .signedOut, .userDeleted:
                currentUser = nil
                isAuthenticated = false
            default:
                break
            }
        }
    }

    var displayName: String {
        currentUser?.userMetadata["full_name"]?.stringValue
            ?? currentUser?.email
            ?? "Hiker"
    }
}
