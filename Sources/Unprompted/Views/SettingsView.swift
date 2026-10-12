import ServiceManagement
import SwiftUI

struct CharacterOption {
    let id: String
    let name: String
    let movement: MovementStyle
}

/// The Settings window. Everything binds straight to `AppSettings`, which the assistant observes.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let characters: [CharacterOption]
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var ownMovement: String {
        characters.first { $0.id == settings.characterID }?.movement.title ?? MovementStyle.walk.title
    }

    var body: some View {
        Form {
            Section("Character") {
                Picker("Character", selection: $settings.characterID) {
                    ForEach(characters, id: \.id) { Text($0.name).tag($0.id) }
                }
                Picker("Movement", selection: $settings.movement) {
                    Text("Character's own (\(ownMovement))").tag("")
                    Divider()
                    ForEach(MovementStyle.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Wandering", selection: $settings.wandering) {
                    ForEach(Wandering.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Costume", selection: $settings.costume) {
                    Text("Seasonal").tag("auto")
                    Text("None").tag("none")
                    Divider()
                    ForEach(Costume.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                LabeledContent("Size") {
                    Slider(value: $settings.size, in: 0.5...1.8) { Text("Size") }
                        minimumValueLabel: { Text("🐜") } maximumValueLabel: { Text("🐘") }
                        .labelsHidden()
                }
                LabeledContent("Speed") {
                    Slider(value: $settings.speed, in: 0.5...2) { Text("Speed") }
                        minimumValueLabel: { Text("🐢") } maximumValueLabel: { Text("🐇") }
                        .labelsHidden()
                }
            }

            Section("Chattiness") {
                Picker("Annoyance level", selection: $settings.annoyance) {
                    ForEach(Annoyance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Unprompted remarks", isOn: $settings.unpromptedRemarks)
                Toggle("Comment when I switch apps", isOn: $settings.appRemarks)
                Toggle("Interrupt long typing sessions", isOn: $settings.typingRemarks)
                Toggle("Clippy-style Yes / No / Don't show again buttons", isOn: $settings.clippyButtons)
                Toggle("Hire interns when ignored", isOn: $settings.interns)
                Toggle("Leave sticky notes on the screen", isOn: $settings.stickyNotes)
                Toggle("Offer a daily report in the evening", isOn: $settings.eveningReport)
            }

            Section {
                Toggle("Day and night (nightcap late at night, coffee in the morning)", isOn: $settings.dayNight)
                Toggle("Sounds", isOn: $settings.sounds)
                Toggle("Use the real Trash in the Dock", isOn: $settings.useDockTrash)
            } header: {
                Text("Fun")
            } footer: {
                Text("The Dock's Trash can only be found with Accessibility permission. Without it, a trash can appears while you drag.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("During calls and full screen", selection: $settings.quietMode) {
                    ForEach(QuietMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Quiet hours", isOn: $settings.quietHours)
                if settings.quietHours {
                    Picker("From", selection: $settings.quietStart) { hours }
                    Picker("Until", selection: $settings.quietEnd) { hours }
                }
            } header: {
                Text("Quiet")
            } footer: {
                Text("Calls are Zoom, Teams, FaceTime and Webex. Full screen covers presentations and videos. During quiet hours it stays but doesn't speak unless you talk to it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 720)
    }

    private var hours: some View {
        ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
    }
}
