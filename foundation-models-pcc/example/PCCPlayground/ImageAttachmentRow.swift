import PhotosUI
import SwiftUI
import UIKit

struct ImageAttachmentRow: View {
    @Binding var image: CGImage?
    @State private var item: PhotosPickerItem?

    var body: some View {
        let pickerTitle = image == nil ? "Attach photo" : "Replace photo"
        HStack {
            PhotosPicker(selection: $item, matching: .images) {
                Label(pickerTitle, systemImage: "photo")
            }
            .buttonStyle(.borderless)

            Spacer()

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 8))
                Button("Remove photo", systemImage: "xmark.circle.fill", role: .destructive) {
                    self.image = nil
                    item = nil
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .task(id: item) { await load() }
    }

    private func load() async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data)
        else { return }
        image = uiImage.normalizedCGImage(maxDimension: 1536)
    }
}

private extension UIImage {
    /// Redraws upright (baking in EXIF orientation) and caps the size to keep prompts small.
    func normalizedCGImage(maxDimension: CGFloat) -> CGImage? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in draw(in: CGRect(origin: .zero, size: target)) }
            .cgImage
    }
}
