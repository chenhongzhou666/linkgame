import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: ServerManager?

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        MusicManager.shared.stop()
    }
}

@main
struct LinkGameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthState()
    @StateObject private var server = ServerManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                PixelArtBackground()

                switch server.status {
                case .starting:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在启动服务器…")
                            .font(.headline)
                    }

                case .failed(let msg):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("服务器启动失败")
                            .font(.headline)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("重试") { server.start() }
                            .buttonStyle(.borderedProminent)
                    }

                case .stopped, .running:
                    if auth.isLoggedIn {
                        ContentView()
                            .environmentObject(auth)
                            .environmentObject(server)
                            .id(auth.currentUser?.id ?? 0)
                    } else {
                        LoginView()
                            .environmentObject(auth)
                            .environmentObject(server)
                    }
                }
            }
            .frame(minWidth: 560, minHeight: 600)
            .onChange(of: server.status) { status in
                if case .running = status { MusicManager.shared.start() }
            }
            .task {
                appDelegate.server = server
                server.start()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 520, height: 680)
    }
}
