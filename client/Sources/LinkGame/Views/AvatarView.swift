import SwiftUI

struct AvatarView: View {
    let avatar: String?
    let size: CGFloat

    init(avatar: String?, size: CGFloat = 48) {
        self.avatar = avatar
        self.size = size
    }

    var body: some View {
        if let avatar = avatar, avatar.hasPrefix("img:") {
            let filename = String(avatar.dropFirst(4))
            AsyncImage(url: URL(string: "\(APIClient.baseURL)/api/avatars/\(filename)")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: size, height: size)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.15))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.45))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(width: size, height: size)
    }
}
