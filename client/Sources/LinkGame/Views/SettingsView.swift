import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var email = ""
    @State private var message: String?
    @State private var isError = false
    @ObservedObject private var music = MusicManager.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 16) {

                    if let msg = message {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(isError ? .red : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            )
                    }

                    if let user = auth.currentUser {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    AvatarView(avatar: user.avatar, size: 48)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("用户名：").foregroundStyle(.secondary)
                                            Text(user.username).bold()
                                        }
                                        HStack {
                                            Text("昵称：").foregroundStyle(.secondary)
                                            Text(user.displayName)
                                        }
                                    }
                                }
                                HStack {
                                    Text("邮箱：").foregroundStyle(.secondary)
                                    Text(user.email?.isEmpty == false ? user.email! : "未绑定")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }

                    GroupBox("修改昵称") {
                        VStack(spacing: 10) {
                            TextField("输入昵称（2-12字）", text: $nickname)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)

                            Button("保存昵称") {
                                saveNickname()
                            }
                            .disabled(nickname.count < 2 || nickname.count > 12)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    GroupBox("绑定 / 修改邮箱") {
                        VStack(spacing: 10) {
                            TextField("输入邮箱地址", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 260)

                            Button("绑定邮箱") {
                                bindEmail()
                            }
                            .disabled(email.isEmpty)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    GroupBox("声音") {
                        VStack(spacing: 10) {
                            HStack {
                                Text("音量")
                                    .frame(width: 40, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(music.outputVolume) },
                                    set: { music.setVolume(Float($0)) }
                                ), in: 0...1)
                                .frame(width: 200)
                                Text("\(Int(music.outputVolume * 100))%")
                                    .frame(width: 36, alignment: .trailing)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle("静音", isOn: Binding(
                                get: { music.outputMuted },
                                set: { _ in music.toggleMute() }
                            ))
                            .frame(width: 280)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    Text("绑定邮箱后即可使用找回密码功能")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 620)
    }

    private func showMsg(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }

    private func saveNickname() {
        let name = nickname.trimmingCharacters(in: .whitespaces)
        APIClient.token = auth.token
        Task {
            do {
                _ = try await APIClient.updateNickname(name)
                updateCurrentUser(nickname: name)
                AccountManager.shared.updateAccountInfo(
                    username: auth.currentUser?.username ?? "",
                    avatar: auth.currentUser?.avatar ?? "",
                    nickname: name
                )
                showMsg("昵称已更新")
            } catch {
                showMsg("昵称更新失败: \(error.localizedDescription)", error: true)
            }
        }
    }

    private func updateCurrentUser(nickname: String? = nil) {
        let user = auth.currentUser
        auth.currentUser = User(
            id: user?.id ?? 0,
            username: user?.username ?? "",
            nickname: nickname ?? user?.nickname,
            email: user?.email,
            avatar: user?.avatar,
            currency: user?.currency,
            dailyUnlocked: user?.dailyUnlocked,
            trophies: user?.trophies,
            createdAt: user?.createdAt
        )
    }

    private func bindEmail() {
        APIClient.token = auth.token
        Task {
            do {
                let resp = try await APIClient.bindEmail(email.trimmingCharacters(in: .whitespaces))
                showMsg(resp["message"] ?? "ok")
                auth.currentUser = User(id: auth.currentUser?.id ?? 0,
                                        username: auth.currentUser?.username ?? "",
                                        nickname: auth.currentUser?.nickname,
                                        email: email,
                                        avatar: auth.currentUser?.avatar,
                                        currency: auth.currentUser?.currency,
                                        dailyUnlocked: auth.currentUser?.dailyUnlocked,
                                        trophies: auth.currentUser?.trophies,
                                        createdAt: auth.currentUser?.createdAt)
            } catch {
                showMsg("绑定失败: \(error.localizedDescription)", error: true)
            }
        }
    }
}
