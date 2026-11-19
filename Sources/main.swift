// BgSounds — menu bar control for macOS Background Sounds (sound, volume, on/off).
// Talks to Apple's own private HearingUtilities classes, the same ones System Settings uses.
// ponytail: private API, may break on a macOS update. Rebuild with ./build.sh.
import SwiftUI
import ServiceManagement
import ObjectiveC

// Swift globals are lazy, so the framework load must be forced before any class lookup.
let hearingLoaded = dlopen("/System/Library/PrivateFrameworks/HearingUtilities.framework/HearingUtilities", RTLD_NOW) != nil
let settings = !hearingLoaded ? nil : (NSClassFromString("HUComfortSoundsSettings") as? NSObject.Type)?
    .perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject

struct Sound: Identifiable, Hashable { let id: UInt; let label: String; let symbol: String }

// Sound groups 1...16 are the sounds bundled with macOS; ask Apple's class for each one's display name.
func makeSound(_ group: UInt) -> NSObject? {
    guard hearingLoaded, let cls: AnyClass = NSClassFromString("HUComfortSound"),
          let method = class_getClassMethod(cls, NSSelectorFromString("defaultComfortSoundForGroup:")) else { return nil }
    typealias Fn = @convention(c) (AnyClass, Selector, UInt) -> AnyObject?
    let fn = unsafeBitCast(method_getImplementation(method), to: Fn.self)
    return fn(cls, NSSelectorFromString("defaultComfortSoundForGroup:"), group) as? NSObject
}
let soundSymbols: [UInt: String] = [
    1: "circle.lefthalf.filled", 2: "sun.max.fill", 3: "moon.fill", 4: "water.waves",
    5: "cloud.rain.fill", 6: "drop.fill", 7: "moon.stars.fill", 8: "flame.fill",
    9: "bubble.left.and.bubble.right.fill", 10: "humidity.fill", 11: "airplane", 12: "sailboat.fill",
    13: "bus.fill", 14: "tram.fill", 15: "house.fill", 16: "moon.zzz.fill",
]
let allSounds: [Sound] = (UInt(1)...16).compactMap { (group: UInt) -> Sound? in
    guard let name = makeSound(group)?.value(forKey: "localizedName") as? String else { return nil }
    let wanted = soundSymbols[group] ?? "waveform"
    let symbol = NSImage(systemSymbolName: wanted, accessibilityDescription: nil) != nil ? wanted : "waveform"
    return Sound(id: group, label: name, symbol: symbol)
}

final class Model: ObservableObject {
    @Published var enabled = false
    @Published var volume = 0.5
    @Published var selected: UInt = 0
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var poll: Timer?

    init(live: Bool = true) {
        guard live else { return }
        // A menu bar app has no windows, so macOS would quietly quit it ("automatic termination"). Opt out.
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must keep running")
        refresh()
        // ponytail: 3s poll keeps the menu bar icon in step with changes made in System Settings;
        // switch to a change notification if Apple ever exposes one.
        poll = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func refresh() {  // only publish real changes, so an open panel doesn't redraw every poll
        let nowEnabled = (settings?.value(forKey: "comfortSoundsEnabled") as? Bool) ?? false
        let nowVolume = (settings?.value(forKey: "relativeVolume") as? Double) ?? 0.5
        let nowSelected = ((settings?.value(forKey: "selectedComfortSound") as? NSObject)?.value(forKey: "soundGroup") as? UInt) ?? 0
        if nowEnabled != enabled { enabled = nowEnabled }
        if abs(nowVolume - volume) > 0.001 { volume = nowVolume }
        if nowSelected != selected { selected = nowSelected }
    }
    var selectedLabel: String { allSounds.first { $0.id == selected }?.label ?? "No sound selected" }
    func setEnabled(_ on: Bool) { settings?.setValue(on, forKey: "comfortSoundsEnabled"); enabled = on }
    func setVolume(_ v: Double) { settings?.setValue(v, forKey: "relativeVolume"); volume = v }
    func select(_ sound: Sound) {
        guard let obj = makeSound(sound.id) else { return }
        settings?.perform(NSSelectorFromString("setSelectedComfortSound:"), with: obj)
        selected = sound.id
        if !enabled { setEnabled(true) }
    }
    func setLaunchAtLogin(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { NSLog("BgSounds: launch at login failed: \(error)") }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct SoundTile: View {
    let sound: Sound
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: sound.symbol).font(.system(size: 17, weight: .medium)).frame(height: 22)
                Text(sound.label).font(.system(size: 10.5, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 3)
            .foregroundStyle(isSelected && isPlaying ? Color.white : Color.primary)
            .background(shape.fill(isSelected && isPlaying ? AnyShapeStyle(Color.accentColor)
                                                           : AnyShapeStyle(Color.primary.opacity(hovering ? 0.14 : 0.07))))
            // Selected but switched off: keep an outline so you can see what will play.
            .overlay(shape.strokeBorder(Color.accentColor, lineWidth: isSelected && !isPlaying ? 1.5 : 0))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(sound.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct Panel: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Background Sounds").font(.headline)
                    Text(model.enabled ? model.selectedLabel : "Off").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Background Sounds", isOn: Binding(get: { model.enabled }, set: model.setEnabled))
                    .toggleStyle(.switch).labelsHidden()
            }
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                Slider(value: Binding(get: { model.volume }, set: model.setVolume), in: 0...1)
                    .accessibilityLabel("Volume")
                Text("\(Int((model.volume * 100).rounded()))%")
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing).accessibilityHidden(true)
            }
            if settings == nil || allSounds.isEmpty {
                Text("This macOS version changed how Background Sounds works, so the app needs an update.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(allSounds) { sound in
                        SoundTile(sound: sound, isSelected: model.selected == sound.id, isPlaying: model.enabled) {
                            model.select(sound)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .controlSize(.small)
        }
        .padding(14).frame(width: 336)
        .onAppear(perform: model.refresh)
    }
}

// Menu bar glyph: full strength while playing, faded while off.
func menuBarIcon(playing: Bool) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    guard let base = NSImage(systemSymbolName: "music.quarternote.3", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return NSImage() }
    guard !playing else { return base }
    let faded = NSImage(size: base.size, flipped: false) { rect in
        base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.4)
        return true
    }
    faded.isTemplate = true
    return faded
}

// MARK: App
@main struct BgSoundsApp: App {
    @StateObject private var model = Model()
    var body: some Scene {
        MenuBarExtra {
            Panel(model: model)
        } label: {
            Image(nsImage: menuBarIcon(playing: model.enabled))
                .accessibilityLabel(model.enabled ? "Background Sounds, on" : "Background Sounds, off")
        }
        .menuBarExtraStyle(.window)
    }
}
