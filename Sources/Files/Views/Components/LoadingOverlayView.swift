import SwiftUI

struct LoadingOverlayView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(FilesColor.background.color.opacity(0.8)))
            .shadow(radius: 10)
    }
} 