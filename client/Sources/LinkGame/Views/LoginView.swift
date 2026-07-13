import SwiftUI
import AppKit

struct LoginView: View {
    @EnvironmentObject var auth: AuthState
    @StateObject private var accountManager = AccountManager.shared
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var rememberPassword = false
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var showForgot = false
    @State private var showNewLogin = false
    @State private var showMiniGame = false

    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        VStack {
            HStack {
                Spacer()
                WallpaperButton()
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 20) {
                Button {
                    showMiniGame = true
                } label: {
                    VStack(spacing: 4) {
                        AppLogo(size: 64)
                        Text("🎮 点我打发时间")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pointingHand.pop()
                    }
                }

                Text("泓泓看")
                    .font(.largeTitle.bold())

                if !showNewLogin && !accountManager.accounts.isEmpty {
                    savedAccountsView
                } else {
                    loginFormView
                }

                // Mute button — accessible before login
                Button {
                    music.toggleMute()
                } label: {
                    Label(music.outputMuted ? "已静音" : "背景音乐",
                          systemImage: music.outputMuted ? "speaker.slash" : "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .clickable()
            }
            .padding(36)
            .glassCard()
            .padding(.horizontal, 40)

            Spacer()
        }
        .sheet(isPresented: $showForgot) {
            ForgotPasswordView().environmentObject(auth)
        }
        .sheet(isPresented: $showMiniGame) {
            DinoRunnerView()
        }
    }

    private var savedAccountsView: some View {
        VStack(spacing: 16) {
            Text("选择账号")
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(accountManager.accounts) { account in
                    HStack {
                        Button {
                            quickLogin(account)
                        } label: {
                            HStack {
                                AvatarView(avatar: account.avatar.isEmpty ? nil : account.avatar, size: 28)
                                Text(account.displayName)
                                    .fontWeight(.medium)
                                if account.hasSavedPassword {
                                    Text("(密码已保存)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                        .clickable()

                        Button {
                            withAnimation {
                                accountManager.removeAccount(account)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .clickable()
                        .help("删除此账号")
                    }
                }
            }
            .frame(width: 260)

            Button("使用其他账号") {
                showNewLogin = true
            }
            .font(.caption)
            .clickable()
        }
    }

    private var loginFormView: some View {
        VStack(spacing: 12) {
            Text(isRegistering ? "注册新账号" : "登录游戏")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("用户名", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .disabled(isLoading)

                if isRegistering {
                    TextField("邮箱", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                        .disabled(isLoading)
                }

                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .disabled(isLoading)
                    .onSubmit { submit() }
            }

            if !isRegistering {
                Toggle("记住密码", isOn: $rememberPassword)
                    .font(.caption)
                    .frame(width: 260)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            VStack(spacing: 8) {
                Button(action: submit) {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(isRegistering ? "注册" : "登录")
                            .frame(width: 160)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isLoading)

                HStack(spacing: 16) {
                    if !accountManager.accounts.isEmpty {
                        Button("返回账号列表") {
                            showNewLogin = false
                            auth.errorMessage = nil
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .clickable()
                    }

                    Button(isRegistering ? "已有账号？去登录" : "没有账号？去注册") {
                        isRegistering.toggle()
                        auth.errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .clickable()

                    if !isRegistering {
                        Button("忘记密码？") {
                            showForgot = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .clickable()
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        if username.isEmpty || password.isEmpty { return false }
        if isRegistering && email.isEmpty { return false }
        return true
    }

    private func submit() {
        isLoading = true
        let savePwd = rememberPassword
        Task {
            if isRegistering {
                await auth.register(username: username, email: email, password: password)
                if auth.isLoggedIn {
                    accountManager.addAccount(username: username, password: password, savePassword: savePwd)
                }
            } else {
                await auth.login(username: username, password: password)
                if auth.isLoggedIn {
                    accountManager.addAccount(username: username, password: password, savePassword: savePwd)
                }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func quickLogin(_ account: SavedAccount) {
        if account.hasSavedPassword, let pwd = accountManager.getPassword(for: account.username) {
            isLoading = true
            Task {
                await auth.login(username: account.username, password: pwd)
                await MainActor.run { isLoading = false }
            }
        } else {
            username = account.username
            password = ""
            rememberPassword = false
            showNewLogin = true
        }
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var step = 0
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("找回密码")
                .font(.title2.bold())
                .padding(.top)

            if step == 0 {
                TextField("注册邮箱", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                if let msg = auth.forgotMessage {
                    Text(msg).foregroundStyle(.green).font(.caption)
                }
                if let error = auth.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("发送验证码") {
                    isLoading = true
                    Task {
                        await auth.forgotPassword(email: email)
                        await MainActor.run {
                            isLoading = false
                            if auth.errorMessage == nil { step = 1 }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || isLoading)
            } else {
                Text("验证码已发送到 \(email)")
                    .font(.caption).foregroundStyle(.secondary)

                TextField("6位数验证码", text: $code)
                    .textFieldStyle(.roundedBorder).frame(width: 260)

                SecureField("新密码（至少6位）", text: $newPassword)
                    .textFieldStyle(.roundedBorder).frame(width: 260)

                if let msg = auth.forgotMessage {
                    Text(msg).foregroundStyle(.green).font(.caption)
                }
                if let error = auth.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                HStack(spacing: 12) {
                    Button("上一步") { step = 0 }.buttonStyle(.bordered)
                    Button("重置密码") {
                        isLoading = true
                        Task {
                            await auth.resetPassword(email: email, code: code, newPassword: newPassword)
                            await MainActor.run {
                                isLoading = false
                                if auth.errorMessage == nil { dismiss() }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(code.isEmpty || newPassword.count < 6 || isLoading)
                }
            }

            Button("关闭") { dismiss() }
                .buttonStyle(.plain).font(.caption).padding(.top)
                .clickable()
        }
        .padding(30)
        .frame(width: 350, height: 320)
    }
}
