import SwiftUI

struct EmptyLibraryView: View {
    var body: some View {
        ContentUnavailableView(
            "No Covers Found",
            systemImage: "books.vertical",
            description: Text("Add cover images to your selected folder, then refresh covers.")
        )
    }
}
