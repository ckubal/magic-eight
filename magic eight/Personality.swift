//
//  Personality.swift
//  magic eight
//
//  Phase 4 — the ball talks back. Rare sassy meta-answers (era-flavored),
//  a text scrambler for "possessed" glitch reveals, and a cross-era
//  translation helper for Phase 5.
//

import Foundation

enum Personality {

    // MARK: - Sassy meta-answers (the ball breaks the fourth wall)

    private static let genericSass = [
        "you just asked that 🙄",
        "reply hazy. reboot me",
        "the spirits are at lunch",
        "42. next question",
        "i'm a ball, not a lawyer",
        "shake responsibly",
        "none of my business tbh",
    ]

    private static let themedSass: [String: [String]] = [
        "aimy2k": ["brb — away message", "asl? jk. no."],
        "matrix": ["there is no answer", "glitch in the matrix"],
        "shakespearean": ["ask not, spoil not", "the quill refuses"],
        "boomers1958": ["we didn't ask twice", "ask the operator"],
        "nbajam": ["REJECTED!", "no buckets."],
        "tiktok2020": ["so 2019 of you", "this flopped"],
        "genz": ["no bc why ask that 💀", "it's giving no"],
        "genalpha": ["skibidi no", "womp womp"],
        "harrypotter": ["the prophecy is sealed", "muggles can't know"],
        "huntersthompson": ["we can't stop here", "too weird to answer"],
        "sportscenter": ["the tape is blank", "upon further review… no"],
        "facebook2008": ["it's complicated", "poke me later"],
        "myspace2005": ["only tom knows", "not in my top 8"],
        "tumblr2012": ["not rebloggable", "0 notes. sorry"],
        "xanga2002": ["diary's locked 🔒", "eeprops? no."],
        "millennial": ["adulting. ask later", "can't even rn"],
        "genx": ["whatever.", "as if"],
        "twitterx2024": ["community noted ❌", "ratio'd. next"],
        "classic": ["shake responsibly", "outlook: mind yours"],
        "deviantart2006": ["pending mod approval", "watch me not answer"],
    ]

    static func sassyLine(for themeId: String) -> String {
        let pool = (themedSass[themeId] ?? []) + genericSass
        return pool.randomElement() ?? "ask again"
    }

    // MARK: - Glitch scrambler ("possessed" reveals)

    private static let glitchChars = Array("█▓▒░#%&$@!?<>/\\|~*")

    /// Corrupt a string, preserving word boundaries so it still "reads" like text.
    static func scramble(_ text: String, severity: Double = 0.85) -> String {
        String(text.map { ch in
            if ch == " " { return ch }
            return Double.random(in: 0...1) < severity ? (glitchChars.randomElement() ?? ch) : ch
        })
    }
}

extension ISO8601DateFormatter {
    /// "2026-07-10" — used to detect the first fortune of each day.
    static func dayStamp(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Cross-era translation (Phase 5)

extension ResponseManager {
    /// The same verdict (positive/neutral/negative), spoken by a different era.
    func translation(
        matching type: Response.ResponseType,
        excluding excludedSetId: String
    ) -> (setId: String, setName: String, text: String)? {
        let candidates = availableSets.filter { $0.id != excludedSetId && $0.id != "random" }
        // Walk sets in random order until one has a matching-type response.
        for set in candidates.shuffled() {
            if let match = set.responses.filter({ $0.type == type }).randomElement() {
                return (set.id, set.name, match.text)
            }
        }
        return nil
    }
}
