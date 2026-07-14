import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 挂件数据变更通知（主 App 修改皮肤/购买后发出，Widget 立即刷新）
extension Notification.Name {
    static let widgetDataChanged = Notification.Name("widgetDataChanged")
}

/// 共享数据读取 — Widget 和主 App 通过 App Groups 共享 UserDefaults
struct WidgetDataProvider {
    static let suiteName = "group.com.chenhongzhou.linkgame"
    static let purchasedSkinsKey = "purchasedSkins"
    static let activeSkinIDKey = "activeSkinID"
    static let currencyBalanceKey = "currencyBalance"
    static let usernameKey = "widgetUsername"
    static let nicknameKey = "widgetNickname"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// 已购买的皮肤 ID 列表
    static var purchasedSkinIDs: [String] {
        sharedDefaults.stringArray(forKey: purchasedSkinsKey) ?? ["default"]
    }

    /// 已拥有的皮肤对象
    static var purchasedSkins: [WidgetSkin] {
        let ids = Set(purchasedSkinIDs)
        return WidgetSkin.all.filter { ids.contains($0.id) }
    }

    /// 当前激活的皮肤（Widget 显示的皮肤）
    static var activeSkin: WidgetSkin {
        let activeID = sharedDefaults.string(forKey: activeSkinIDKey) ?? "default"
        return WidgetSkin.all.first(where: { $0.id == activeID }) ?? .defaultSkin
    }

    /// 金币余额
    static var currencyBalance: Int {
        sharedDefaults.integer(forKey: currencyBalanceKey)
    }

    /// 判断皮肤是否已拥有
    static func ownsSkin(_ skinID: String) -> Bool {
        purchasedSkinIDs.contains(skinID)
    }

    /// 清除所有挂件数据（退出登录时调用）
    static func clear() {
        sharedDefaults.removeObject(forKey: purchasedSkinsKey)
        sharedDefaults.removeObject(forKey: activeSkinIDKey)
        sharedDefaults.removeObject(forKey: currencyBalanceKey)
        sharedDefaults.removeObject(forKey: usernameKey)
        sharedDefaults.removeObject(forKey: nicknameKey)
    }

    /// 写入端（主 App 调用）
    struct Writer {
        /// 添加已购买皮肤
        static func addPurchasedSkin(_ skinID: String) {
            var skins = sharedDefaults.stringArray(forKey: purchasedSkinsKey) ?? ["default"]
            if !skins.contains(skinID) {
                skins.append(skinID)
                sharedDefaults.set(skins, forKey: purchasedSkinsKey)
            }
            postChangeNotification()
        }

        /// 设置当前皮肤
        static func setActiveSkin(_ skinID: String) {
            sharedDefaults.set(skinID, forKey: activeSkinIDKey)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            postChangeNotification()
        }

        /// 更新金币余额
        static func setCurrencyBalance(_ balance: Int) {
            sharedDefaults.set(balance, forKey: currencyBalanceKey)
            postChangeNotification()
        }

        /// 设置用户信息
        static func setUserInfo(username: String, nickname: String) {
            sharedDefaults.set(username, forKey: usernameKey)
            let displayName = nickname.isEmpty ? username : nickname
            sharedDefaults.set(displayName, forKey: nicknameKey)
            postChangeNotification()
        }

        /// 同步所有数据
        static func sync(currency: Int, purchasedSkins: [String], activeSkinID: String, username: String = "", nickname: String = "") {
            sharedDefaults.set(currency, forKey: currencyBalanceKey)
            sharedDefaults.set(purchasedSkins, forKey: purchasedSkinsKey)
            sharedDefaults.set(activeSkinID, forKey: activeSkinIDKey)
            if !username.isEmpty {
                sharedDefaults.set(username, forKey: usernameKey)
                let displayName = nickname.isEmpty ? username : nickname
                sharedDefaults.set(displayName, forKey: nicknameKey)
            }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            postChangeNotification()
        }

        private static func postChangeNotification() {
            NotificationCenter.default.post(name: .widgetDataChanged, object: nil)
        }
    }
}
