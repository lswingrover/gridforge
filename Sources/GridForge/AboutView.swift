/// AboutView.swift — About GridForge window
///
/// Opened via openWindow(id: "about") from MenuBarView.
/// Shows version, links, and live update-checker status.
import SwiftUI

struct AboutView: View {
    @EnvironmentObject var updateChecker: UpdateChecker

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────────
            VStack(spacing: 8) {
                Image(systemName: "grid")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text("GridForge")
                    .font(.system(size: 20, weight: .semibold))

                Text("Version \(AppVersion.current)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Window management, Divvy-style.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }

            Divider()

            // ── Update status ─────────────────────────────────────────────────
            Group {
                if let info = updateChecker.updateInfo {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Version \(info.tagName) available")
                            .font(.subheadline)
                        Spacer()
                        Button("Download") { updateChecker.openReleasePage() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else {
                    Text("Up to date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }

            Spacer().frame(height: 14)

            // ── Links ─────────────────────────────────────────────────────────
            HStack(spacing: 24) {
                Link("GitHub",
                     destination: URL(string: "https://github.com/lswingrover/gridforge")!)
                    .font(.subheadline)
                Link("Releases",
                     destination: URL(string: "https://github.com/lswingrover/gridforge/releases")!)
                    .font(.subheadline)
            }
            .padding(.bottom, 22)
        }
        .frame(width: 300)
    }
}
