import SwiftUI

/// Shown when no data has been synced from the Mac yet.
struct ConnectionCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Waiting for Mac")
                .font(.headline)

            Text("Open Sonde on your Mac to sync usage data via iCloud.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
