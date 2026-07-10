//
//  SoundManager.swift
//  magic eight
//
//  Plays a short, era-appropriate cue when a fortune is revealed. All cues are
//  original synthesized placeholders (see /Sounds/*.wav) — swap or edit those
//  files freely; the mapping below is the only thing that references them.
//
//  Uses the `.ambient` audio session so cues respect the ringer/silent switch
//  and mix with (rather than interrupt) any music the user is playing.
//

import AVFoundation

final class SoundManager {
    private var players: [String: AVAudioPlayer] = [:]
    private var sessionReady = false

    /// Theme id -> cue file name (in /Sounds).
    static func cue(for themeId: String) -> String {
        switch themeId {
        case "boomers1958": return "bell"
        case "matrix", "deviantart2006", "twitterx2024", "tiktok2020", "sportscenter": return "blip"
        case "facebook2008", "myspace2005", "aimy2k": return "modem"
        case "genx": return "ringtone"
        case "nbajam", "huntersthompson": return "arcade"
        case "genalpha", "genz", "millennial", "tumblr2012", "xanga2002": return "twinkle"
        case "shakespearean", "harrypotter": return "mystic"
        default: return "knock" // classic + fallbacks
        }
    }

    func play(for themeId: String) {
        play(named: SoundManager.cue(for: themeId))
    }

    func playShiny() {
        play(named: "shiny")
    }

    // MARK: - Internals

    private func activateSessionIfNeeded() {
        guard !sessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        sessionReady = true
    }

    private func player(named name: String) -> AVAudioPlayer? {
        if let p = players[name] { return p }
        let url = Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
        guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        players[name] = p
        return p
    }

    private func play(named name: String) {
        activateSessionIfNeeded()
        guard let p = player(named: name) else { return }
        p.currentTime = 0
        p.play()
    }
}
