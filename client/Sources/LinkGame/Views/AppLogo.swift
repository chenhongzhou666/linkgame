import SwiftUI

struct AppLogo: View {
    let size: CGFloat

    var body: some View {
        if let logo = NSImage(contentsOfFile: Bundle.main.resourcePath! + "/logo.png") {
            Image(nsImage: logo)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            Text("🎮")
                .font(.system(size: size * 0.78))
        }
    }
}
