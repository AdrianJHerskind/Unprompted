import AppKit

/// Code-drawn characters that stay out of the repository live in the git-ignored
/// `Characters/Local` folder, which hands them over through a class named `LocalCharacters`:
///
///     @objc(LocalCharacters) final class LocalCharacters: NSObject, LocalCharacterSource {
///         @MainActor static func makePacks() -> [CharacterPack] { [MyPack()] }
///     }
///
/// It's looked up by name at launch, so the app builds the same with or without that folder.
protocol LocalCharacterSource: AnyObject {
    @MainActor static func makePacks() -> [CharacterPack]
}

/// Finds all available characters: the built-in, code-drawn ones, local ones (see
/// `LocalCharacterSource`), and every sprite folder in the app bundle, the dev checkout and the
/// user's Application Support folder.
@MainActor
enum CharacterLibrary {
    static var userFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Unprompted/Characters", isDirectory: true)
    }

    static func loadAll() -> [CharacterPack] {
        var packs: [CharacterPack] = [SparklePack(), CookieBannerPack(), GhostPack()]
        if let local = NSClassFromString("LocalCharacters") as? LocalCharacterSource.Type {
            packs += local.makePacks()
        }
        var seen = Set(packs.map(\.id))

        var folders: [URL] = []
        if let resources = Bundle.main.resourceURL {
            folders.append(resources.appendingPathComponent("Characters"))
        }
        // Lets `swift run` from the project folder pick up Resources/ without bundling.
        folders.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Characters"))
        folders.append(userFolder)

        let fm = FileManager.default
        for folder in folders {
            guard let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                      fm.fileExists(atPath: item.appendingPathComponent("character.json").path),
                      !seen.contains(item.lastPathComponent) else { continue }
                do {
                    let pack = try SpritePack(folder: item)
                    packs.append(pack)
                    seen.insert(pack.id)
                } catch {
                    NSLog("Skipping character at %@: %@", item.path, String(describing: error))
                }
            }
        }
        return packs
    }

    /// Creates the user's character folder (with a short how-to) and returns it.
    static func prepareUserFolder() -> URL {
        let folder = userFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let howTo = folder.appendingPathComponent("HOW-TO.txt")
        if !FileManager.default.fileExists(atPath: howTo.path) {
            let text = """
            Make your own character
            =======================

            1. Create a folder here, e.g. "mycharacter".
            2. Put PNG frames in it (transparent background).
            3. Add a character.json describing them:

            {
              "name": "My Character",
              "frameWidth": 32, "frameHeight": 32, "scale": 3,
              "footInset": 1,
              "walkSpeed": 60, "bounciness": 0.3,
              "facesRight": true,
              "movement": "walk",
              "hat":  { "x": 16, "y": 6, "width": 12 },
              "hand": { "x": 28, "y": 22, "height": 8 },
              "animations": {
                "idle":  { "frames": ["idle_0.png", "idle_1.png"], "fps": 2 },
                "walk":  { "frames": ["walk_0.png", "walk_1.png"], "fps": 8 }
              },
              "quips": ["Something only this character would say."]
            }

            Only "idle" is required. Other states: walk, fall, drag, talk, sulk, sleep, happy.
            Missing states reuse idle.

            Positions are in source pixels, measured from the frame's top-left corner:
            • "hat" is the bottom-center of a hat (the top of the head) and the hat's width.
            • "hand" is the bottom-center of a held prop (like a coffee mug) and its height.
            Leave either out and the character won't wear hats or hold things.

            "movement" is the gait: walk, waddle, hop, roll or float.
            "bounciness" goes from 0 (lands like a sack of potatoes) to 0.9 (very bouncy).

            Then choose "Reload Characters" from the ✨ menu.
            """
            try? text.write(to: howTo, atomically: true, encoding: .utf8)
        }
        return folder
    }
}
