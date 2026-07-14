//
//  ResponseManager.swift
//  magic eight
//
//  Created by Charlie Kubal on 12/1/25.
//

import Foundation
import Combine

class ResponseManager: ObservableObject {
    @Published var responses: [Response] = []
    @Published var availableSets: [ResponseSet] = []
    @Published var selectedSetId: String = "classic" {
        didSet {
            UserDefaults.standard.set(selectedSetId, forKey: "selectedResponseSetId")
            loadSelectedSet()
        }
    }
    
    /// When selectedSetId == "random", this holds the currently resolved theme for wallpaper and responses.
    @Published var randomResolvedSetId: String?
    
    /// Theme id used for wallpaper and responses; when "random" is selected, equals randomResolvedSetId.
    var effectiveSetId: String {
        if selectedSetId == "random" {
            return randomResolvedSetId ?? availableSets.randomElement()?.id ?? "classic"
        }
        return selectedSetId
    }
    
    private let remoteURL = "https://www.weirdlittleideas.com/builds/magiceight/responses.json"
    private var remoteSetsCache: [String: RemoteResponseSet] = [:]
    
    // Metadata for sets (emoji and category - rarely change)
    private let setMetadata: [String: (emoji: String, category: ResponseSetCategory)] = [
        "classic": ("🎱", .styles),
        "shakespearean": ("🪶", .styles),
        "huntersthompson": ("🦂", .styles),
        "genalpha": ("🍼", .generations),
        "genz": ("⚡", .generations),
        "millennial": ("📼", .generations),
        "genx": ("🎧", .generations),
        "boomers1958": ("📻", .generations),
        "twitterx2024": ("🐦", .techEras),
        "tiktok2020": ("🎵", .techEras),
        "tumblr2012": ("🌙", .techEras),
        "facebook2008": ("📘", .techEras),
        "deviantart2006": ("🎨", .techEras),
        "myspace2005": ("🖤", .techEras),
        "xanga2002": ("📓", .techEras),
        "aimy2k": ("💬", .techEras),
        "harrypotter": ("🪄", .popCulture),
        "matrix": ("🟩", .popCulture),
        "nbajam": ("🔥", .popCulture),
        "sportscenter": ("📺", .popCulture)
    ]

    /// Display names live in code (not the JSON) so they can't be reverted by a
    /// bundled or remote responses.json. Wink-and-nod names avoid trademarks.
    private let themeNames: [String: String] = [
        "classic": "Classic",
        "shakespearean": "Shakespearean",
        "huntersthompson": "Gonzo",
        "genalpha": "Gen Alpha",
        "genz": "Gen Z",
        "millennial": "Millennials",
        "genx": "Gen X",
        "boomers1958": "Boomers",
        "twitterx2024": "The Timeline '25",
        "tiktok2020": "For You '20",
        "tumblr2012": "Soft Grunge '12",
        "facebook2008": "The Wall '08",
        "deviantart2006": "Fan Art '06",
        "myspace2005": "Top 8 '05",
        "xanga2002": "Glitter Blog '02",
        "aimy2k": "Away Message '01",
        "harrypotter": "Wizard School",
        "matrix": "White Rabbit",
        "nbajam": "Arcade Hoops",
        "sportscenter": "Highlight Reel"
    ]

    /// Canonical display order (dial + settings). Tech eras run earliest → latest.
    private let themeOrder: [String] = [
        // styles
        "classic", "shakespearean", "huntersthompson",
        // tech eras — chronological
        "aimy2k", "xanga2002", "myspace2005", "deviantart2006",
        "facebook2008", "tumblr2012", "tiktok2020", "twitterx2024",
        // pop culture
        "harrypotter", "matrix", "nbajam", "sportscenter",
        // generations
        "boomers1958", "genx", "millennial", "genz", "genalpha"
    ]

    private func sortAvailableSets() {
        let index = Dictionary(uniqueKeysWithValues: themeOrder.enumerated().map { ($1, $0) })
        availableSets.sort { (index[$0.id] ?? Int.max) < (index[$1.id] ?? Int.max) }
    }

    init() {
        // Load all sets from local JSON file for instant response availability
        loadLocalResponseSets()
        if let savedSetId = UserDefaults.standard.string(forKey: "selectedResponseSetId") {
            selectedSetId = savedSetId
        }
        loadSelectedSet()
        // Check for remote updates in background (non-blocking)
        checkForRemoteUpdates()
    }
    
    private func loadLocalResponseSets() {
        // Try to load from local JSON file first
        if let url = Bundle.main.url(forResource: "responses", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let responseData = try? JSONDecoder().decode(RemoteResponseData.self, from: data) {
            // Convert remote format to ResponseSets with metadata
            availableSets = responseData.sets.map { remoteSet in
                let metadata = setMetadata[remoteSet.id] ?? ("🎱", .styles)
                let responses = remoteSet.responses.map { remoteResponse in
                    Response(text: remoteResponse.text, type: remoteResponse.type)
                }
                return ResponseSet(
                    id: remoteSet.id,
                    name: themeNames[remoteSet.id] ?? remoteSet.name,
                    emoji: metadata.emoji,
                    category: metadata.category,
                    responses: responses
                )
            }
        } else {
            // Fallback to hardcoded sets if JSON file not found
            loadAllResponseSets()
        }
        sortAvailableSets()
    }
    
    private func loadAllResponseSets() {
        // Fallback: load hardcoded sets if JSON file unavailable
        availableSets = [
            // Styles
            createClassicSet(),
            createShakespeareanSet(),
            createHunterSThompsonSet(),
            
            // Generations
            createGenAlphaSet(),
            createGenZSet(),
            createMillennialSet(),
            createGenXSet(),
            createBoomers1958Set(),
            
            // Tech Eras
            createTwitterX2024Set(),
            createTikTok2020Set(),
            createTumblr2012Set(),
            createFacebook2008Set(),
            createDeviantArt2006Set(),
            createMySpace2005Set(),
            createXanga2002Set(),
            createAIMY2KSet(),
            
            // Pop Culture
            createHarryPotterSet(),
            createMatrixSet(),
            createNBAJamSet(),
            createSportsCenterSet()
        ]
    }
    
    private func loadSelectedSet() {
        if selectedSetId == "random" {
            let pickable = availableSets.filter { $0.id != "random" }
            guard let chosen = pickable.randomElement() else {
                responses = availableSets.first?.responses ?? []
                randomResolvedSetId = nil
                return
            }
            randomResolvedSetId = chosen.id
            responses = chosen.responses
        } else if let selectedSet = availableSets.first(where: { $0.id == selectedSetId }) {
            responses = selectedSet.responses
            randomResolvedSetId = nil
        } else {
            responses = availableSets.first?.responses ?? []
            randomResolvedSetId = nil
        }
    }
    
    func checkForRemoteUpdates() {
        // Called on init and when settings view appears - check for updates in background
        guard let url = URL(string: remoteURL) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if error != nil {
                return // Silently fail
            }
            
            guard let data = data, !data.isEmpty else {
                return
            }
            
            do {
                let responseData = try JSONDecoder().decode(RemoteResponseData.self, from: data)
                DispatchQueue.main.async {
                    // Cache remote sets
                    for remoteSet in responseData.sets {
                        self.remoteSetsCache[remoteSet.id] = remoteSet
                    }
                    
                    // Update existing sets with remote data (remote takes precedence)
                    for remoteSet in responseData.sets {
                        let remoteId = remoteSet.id
                        if let index = self.availableSets.firstIndex(where: { $0.id == remoteId }) {
                            // Convert remote responses
                            let responses = remoteSet.responses.map { remoteResponse in
                                Response(text: remoteResponse.text, type: remoteResponse.type)
                            }
                            
                            let existingSet = self.availableSets[index]
                            let updatedSet = ResponseSet(
                                id: remoteSet.id,
                                name: self.themeNames[remoteId] ?? existingSet.name,
                                emoji: existingSet.emoji,
                                category: existingSet.category,
                                responses: responses
                            )
                            
                            self.availableSets[index] = updatedSet
                            
                            // If this is the selected set, update responses immediately
                            if remoteId == self.selectedSetId {
                                self.responses = updatedSet.responses
                            }
                        } else {
                            // New set from remote - add it
                            let responses = remoteSet.responses.map { remoteResponse in
                                Response(text: remoteResponse.text, type: remoteResponse.type)
                            }
                            
                            self.availableSets.append(ResponseSet(
                                id: remoteSet.id,
                                name: self.themeNames[remoteSet.id] ?? remoteSet.name,
                                emoji: "🎱",
                                category: .styles,
                                responses: responses
                            ))
                        }
                    }
                    self.sortAvailableSets()
                }
            } catch {
                // Silently fail
            }
        }.resume()
    }
    
    // MARK: - Response Set Creators
    
    private func createClassicSet() -> ResponseSet {
        ResponseSet(id: "classic", name: "Classic", emoji: "🎱", category: .styles, responses: [
            Response(text: "It is certain", type: .positive),
            Response(text: "It is decidedly so", type: .positive),
            Response(text: "Without a doubt", type: .positive),
            Response(text: "Yes – definitely", type: .positive),
            Response(text: "You may rely on it", type: .positive),
            Response(text: "As I see it, yes", type: .positive),
            Response(text: "Most likely", type: .positive),
            Response(text: "Outlook good", type: .positive),
            Response(text: "Yes", type: .positive),
            Response(text: "Signs point to yes", type: .positive),
            Response(text: "Reply hazy, try again", type: .neutral),
            Response(text: "Ask again later", type: .neutral),
            Response(text: "Better not tell you now", type: .neutral),
            Response(text: "Cannot predict now", type: .neutral),
            Response(text: "Concentrate and ask again", type: .neutral),
            Response(text: "Don't count on it", type: .negative),
            Response(text: "My reply is no", type: .negative),
            Response(text: "My sources say no", type: .negative),
            Response(text: "Outlook not so good", type: .negative),
            Response(text: "Very doubtful", type: .negative)
        ])
    }
    
    private func createGenZSet() -> ResponseSet {
        ResponseSet(id: "genz", name: "Gen Z", emoji: "⚡", category: .generations, responses: [
            Response(text: "Bet on it", type: .positive),
            Response(text: "Facts only, yes", type: .positive),
            Response(text: "Certified yes", type: .positive),
            Response(text: "100% sending yes vibes", type: .positive),
            Response(text: "You're so valid, yes", type: .positive),
            Response(text: "Looks good tbh", type: .positive),
            Response(text: "Signs say yup", type: .positive),
            Response(text: "Trendline says yes", type: .positive),
            Response(text: "W (for you)", type: .positive),
            Response(text: "It's giving yes", type: .positive),
            Response(text: "Ask again, buffering", type: .neutral),
            Response(text: "Vibes unclear rn", type: .neutral),
            Response(text: "Loading… try later", type: .neutral),
            Response(text: "Not enough data yet", type: .neutral),
            Response(text: "One sec, recalculating", type: .neutral),
            Response(text: "Nah, not this arc", type: .negative),
            Response(text: "That's a hard no", type: .negative),
            Response(text: "Universe said \"lol no\"", type: .negative),
            Response(text: "Odds look rough ngl", type: .negative),
            Response(text: "It's giving no energy", type: .negative)
        ])
    }
    
    private func createGenXSet() -> ResponseSet {
        ResponseSet(id: "genx", name: "Gen X", emoji: "🎧", category: .generations, responses: [
            Response(text: "Totally", type: .positive),
            Response(text: "For sure, dude", type: .positive),
            Response(text: "No doubt about it", type: .positive),
            Response(text: "You're golden", type: .positive),
            Response(text: "Count on it", type: .positive),
            Response(text: "Looks solid to me", type: .positive),
            Response(text: "Odds look rad", type: .positive),
            Response(text: "Yeah, that tracks", type: .positive),
            Response(text: "All signs say yep", type: .positive),
            Response(text: "Go for it", type: .positive),
            Response(text: "Ask me later, man", type: .neutral),
            Response(text: "Hard to say right now", type: .neutral),
            Response(text: "Gimme a sec", type: .neutral),
            Response(text: "Kinda foggy, dude", type: .neutral),
            Response(text: "Try again in a bit", type: .neutral),
            Response(text: "Don't bet on it", type: .negative),
            Response(text: "Yeah… no", type: .negative),
            Response(text: "Not happening, dude", type: .negative),
            Response(text: "Looks pretty sketchy", type: .negative),
            Response(text: "Total long shot", type: .negative)
        ])
    }
    
    private func createAIMY2KSet() -> ResponseSet {
        ResponseSet(id: "aimy2k", name: "Away Message '01", emoji: "💬", category: .techEras, responses: [
            Response(text: "yup :)", type: .positive),
            Response(text: "def!", type: .positive),
            Response(text: "100% lol", type: .positive),
            Response(text: "looks good 2 me", type: .positive),
            Response(text: "totes yes", type: .positive),
            Response(text: "signs say ya", type: .positive),
            Response(text: "sounds rite", type: .positive),
            Response(text: "omg yes", type: .positive),
            Response(text: "fo sho", type: .positive),
            Response(text: "ya, do it", type: .positive),
            Response(text: "brb, ask l8r", type: .neutral),
            Response(text: "idk rn", type: .neutral),
            Response(text: "??? try again", type: .neutral),
            Response(text: "loading…", type: .neutral),
            Response(text: "hmm…maybe", type: .neutral),
            Response(text: "nah :/", type: .negative),
            Response(text: "no way dude", type: .negative),
            Response(text: "prob not :(", type: .negative),
            Response(text: "lol nope", type: .negative),
            Response(text: "doesn't look gr8", type: .negative)
        ])
    }
    
    private func createTikTok2020Set() -> ResponseSet {
        ResponseSet(id: "tiktok2020", name: "For You '20", emoji: "🎵", category: .techEras, responses: [
            Response(text: "no cap, yes", type: .positive),
            Response(text: "big yes energy", type: .positive),
            Response(text: "that's a W", type: .positive),
            Response(text: "vibes say yes", type: .positive),
            Response(text: "looking valid", type: .positive),
            Response(text: "yea buddy", type: .positive),
            Response(text: "trend says yes", type: .positive),
            Response(text: "it checks out", type: .positive),
            Response(text: "sending yes vibes", type: .positive),
            Response(text: "confirmed slay", type: .positive),
            Response(text: "idk fam", type: .neutral),
            Response(text: "vibes unclear", type: .neutral),
            Response(text: "buffering…", type: .neutral),
            Response(text: "try again lol", type: .neutral),
            Response(text: "can't tell yet", type: .neutral),
            Response(text: "that's a L", type: .negative),
            Response(text: "nah, chief", type: .negative),
            Response(text: "vibes say no", type: .negative),
            Response(text: "not the move", type: .negative),
            Response(text: "it's giving no", type: .negative)
        ])
    }
    
    private func createTumblr2012Set() -> ResponseSet {
        ResponseSet(id: "tumblr2012", name: "Soft Grunge '12", emoji: "🌙", category: .techEras, responses: [
            Response(text: "yeah, pretty much", type: .positive),
            Response(text: "seems legit", type: .positive),
            Response(text: "universe says yes", type: .positive),
            Response(text: "feels right tbh", type: .positive),
            Response(text: "all signs align", type: .positive),
            Response(text: "yes, my child", type: .positive),
            Response(text: "this is canon", type: .positive),
            Response(text: "consider it done", type: .positive),
            Response(text: "otp-level yes", type: .positive),
            Response(text: "reblogging yes", type: .positive),
            Response(text: "idk, my aesthetic", type: .neutral),
            Response(text: "vague feelings atm", type: .neutral),
            Response(text: "can't interpret rn", type: .neutral),
            Response(text: "try again later, love", type: .neutral),
            Response(text: "still buffering life", type: .neutral),
            Response(text: "nah, not your arc", type: .negative),
            Response(text: "the feels say no", type: .negative),
            Response(text: "destiny disagrees", type: .negative),
            Response(text: "not in this timeline", type: .negative),
            Response(text: "pls don't", type: .negative)
        ])
    }
    
    private func createMySpace2005Set() -> ResponseSet {
        ResponseSet(id: "myspace2005", name: "Top 8 '05", emoji: "🖤", category: .techEras, responses: [
            Response(text: "omg yes <3", type: .positive),
            Response(text: "totes a yes", type: .positive),
            Response(text: "looks hella good", type: .positive),
            Response(text: "so down 4 this", type: .positive),
            Response(text: "def a yes, bb", type: .positive),
            Response(text: "this feels right", type: .positive),
            Response(text: "signs say yesss", type: .positive),
            Response(text: "ur vibe is on point", type: .positive),
            Response(text: "approved for Top 8", type: .positive),
            Response(text: "yesss, add me", type: .positive),
            Response(text: "brb, ask l8r", type: .neutral),
            Response(text: "kinda hard 2 tell", type: .neutral),
            Response(text: "mood not loading rn", type: .neutral),
            Response(text: "hmm… maybe", type: .neutral),
            Response(text: "idk, still thinking", type: .neutral),
            Response(text: "nahhh :/", type: .negative),
            Response(text: "not in this era", type: .negative),
            Response(text: "mood says no lol", type: .negative),
            Response(text: "this ain't it", type: .negative),
            Response(text: "denied by Top 8", type: .negative)
        ])
    }
    
    private func createFacebook2008Set() -> ResponseSet {
        ResponseSet(id: "facebook2008", name: "The Wall '08", emoji: "📘", category: .techEras, responses: [
            Response(text: "is feeling yes today", type: .positive),
            Response(text: "omg yes, long story lol", type: .positive),
            Response(text: "yup… more later ;)", type: .positive),
            Response(text: "signs say yes (pic 2 come)", type: .positive),
            Response(text: "def yes, no regrets", type: .positive),
            Response(text: "yes. will explain in a note", type: .positive),
            Response(text: "looks good, stay tuned", type: .positive),
            Response(text: "yes, and I'm blessed 💖", type: .positive),
            Response(text: "it's a yes… you'll see why", type: .positive),
            Response(text: "yes!! best day ever!!!", type: .positive),
            Response(text: "idk, it's complicated", type: .neutral),
            Response(text: "ask later, busy venting", type: .neutral),
            Response(text: "maybe… depends on ppl", type: .neutral),
            Response(text: "hard 2 say, lot going on", type: .neutral),
            Response(text: "still thinking, pray 4 me", type: .neutral),
            Response(text: "no, don't ask y", type: .negative),
            Response(text: "nah… rough day tbh", type: .negative),
            Response(text: "not happening, long post soon", type: .negative),
            Response(text: "no. some ppl know why.", type: .negative),
            Response(text: "nope. deleting comments", type: .negative)
        ])
    }
    
    private func createBoomers1958Set() -> ResponseSet {
        ResponseSet(id: "boomers1958", name: "Boomers", emoji: "📻", category: .generations, responses: [
            Response(text: "You bet, daddy-o", type: .positive),
            Response(text: "Solid yes", type: .positive),
            Response(text: "Right on, man", type: .positive),
            Response(text: "It's a gas", type: .positive),
            Response(text: "Count on it, sport", type: .positive),
            Response(text: "Looks real keen", type: .positive),
            Response(text: "Sure thing, ace", type: .positive),
            Response(text: "All signs say yup", type: .positive),
            Response(text: "That's the ticket", type: .positive),
            Response(text: "Absolutely, cool cat", type: .positive),
            Response(text: "Hard to say, man", type: .neutral),
            Response(text: "Lemme think on it", type: .neutral),
            Response(text: "Kinda hazy, daddy-o", type: .neutral),
            Response(text: "Check back later", type: .neutral),
            Response(text: "Not sure this minute", type: .neutral),
            Response(text: "No dice, kid", type: .negative),
            Response(text: "Don't bank on it", type: .negative),
            Response(text: "That's a bum call", type: .negative),
            Response(text: "Nothin' doin'", type: .negative),
            Response(text: "A real long shot", type: .negative)
        ])
    }
    
    private func createNBAJamSet() -> ResponseSet {
        ResponseSet(id: "nbajam", name: "Arcade Hoops", emoji: "🔥", category: .popCulture, responses: [
            Response(text: "HE'S ON FIRE! (…that's a yes)", type: .positive),
            Response(text: "BOOMSHAKALAKA!", type: .positive),
            Response(text: "YES! COUNT IT!", type: .positive),
            Response(text: "THAT ONE'S GOOD!", type: .positive),
            Response(text: "FROM DOWNTOWN… YES!", type: .positive),
            Response(text: "FIRST DOWN! (go for it)", type: .positive),
            Response(text: "IT'S GOOD!", type: .positive),
            Response(text: "HE GOT GAME! (so: yes)", type: .positive),
            Response(text: "RIGHT THROUGH THE UPRIGHTS!", type: .positive),
            Response(text: "ABSOLUTELY CRUSHED IT!", type: .positive),
            Response(text: "WE'RE GOING TO OVERTIME!", type: .neutral),
            Response(text: "IT'S ANYONE'S GAME NOW!", type: .neutral),
            Response(text: "TOO CLOSE TO CALL!", type: .neutral),
            Response(text: "WE NEED ANOTHER ANGLE!", type: .neutral),
            Response(text: "HOLD EVERYTHING—REVIEWING THE PLAY…", type: .neutral),
            Response(text: "REJECTED!", type: .negative),
            Response(text: "HE BRICKED IT!", type: .negative),
            Response(text: "NO GOOD!", type: .negative),
            Response(text: "TURNOVER!", type: .negative),
            Response(text: "FLAG ON THE PLAY—NOPE!", type: .negative)
        ])
    }
    
    private func createSportsCenterSet() -> ResponseSet {
        ResponseSet(id: "sportscenter", name: "Highlight Reel", emoji: "📺", category: .popCulture, responses: [
            Response(text: "Booyah!", type: .positive),
            Response(text: "Yes! Sick highlight!", type: .positive),
            Response(text: "En fuego!", type: .positive),
            Response(text: "Absolutely…top play!", type: .positive),
            Response(text: "Oh, that's nasty!", type: .positive),
            Response(text: "It's good!", type: .positive),
            Response(text: "From way downtown—yes!", type: .positive),
            Response(text: "Big time!", type: .positive),
            Response(text: "That one's money!", type: .positive),
            Response(text: "You can put it on the board—YES!", type: .positive),
            Response(text: "We'll see… developing story.", type: .neutral),
            Response(text: "Too close to call.", type: .neutral),
            Response(text: "Could go either way.", type: .neutral),
            Response(text: "Reviewing the footage…", type: .neutral),
            Response(text: "Stay tuned.", type: .neutral),
            Response(text: "Not top-10 material.", type: .negative),
            Response(text: "He…could…not…do it!", type: .negative),
            Response(text: "Nope—just short.", type: .negative),
            Response(text: "That's a whiff.", type: .negative),
            Response(text: "Not the play you want.", type: .negative)
        ])
    }
    
    private func createHarryPotterSet() -> ResponseSet {
        ResponseSet(id: "harrypotter", name: "Wizard School", emoji: "🪄", category: .popCulture, responses: [
            Response(text: "\"The prophecy favors yes.\"", type: .positive),
            Response(text: "\"By Merlin's beard—yes!\"", type: .positive),
            Response(text: "\"All signs point to yes, dear.\"", type: .positive),
            Response(text: "\"The magic agrees: yes.\"", type: .positive),
            Response(text: "\"Expecto yes-tronum.\"", type: .positive),
            Response(text: "\"Dumbledore would say yes.\"", type: .positive),
            Response(text: "\"Even the Sorting Hat says yes.\"", type: .positive),
            Response(text: "\"Yes — as certain as Quidditch.\"", type: .positive),
            Response(text: "\"The stars in Divination whisper 'yes.'\"", type: .positive),
            Response(text: "\"Yes — stamped by the Ministry.\"", type: .positive),
            Response(text: "\"Cloudy… Professor Trelawney is unsure.\"", type: .neutral),
            Response(text: "\"Ask again — the tea leaves are muddled.\"", type: .neutral),
            Response(text: "\"Hard to tell — fate is shifting.\"", type: .neutral),
            Response(text: "\"The wand hesitates… try later.\"", type: .neutral),
            Response(text: "\"A murmur only — unclear.\"", type: .neutral),
            Response(text: "\"Absolutely not — so says Snape.\"", type: .negative),
            Response(text: "\"Dark omens… it's a no.\"", type: .negative),
            Response(text: "\"The Sorting Hat says 'not this time.'\"", type: .negative),
            Response(text: "\"No — even a Time Turner won't change it.\"", type: .negative),
            Response(text: "\"Forbidden. The answer is no.\"", type: .negative)
        ])
    }
    
    private func createMatrixSet() -> ResponseSet {
        ResponseSet(id: "matrix", name: "Digital Rain", emoji: "🟩", category: .popCulture, responses: [
            Response(text: "\"Yes — the code agrees.\"", type: .positive),
            Response(text: "\"You are the One… for this yes.\"", type: .positive),
            Response(text: "\"Morpheus nods: yes.\"", type: .positive),
            Response(text: "\"The path is clear. Yes.\"", type: .positive),
            Response(text: "\"It's a yes. No illusion.\"", type: .positive),
            Response(text: "\"The Oracle sees a yes.\"", type: .positive),
            Response(text: "\"Your choice leads to yes.\"", type: .positive),
            Response(text: "\"A yes… written in the Matrix.\"", type: .positive),
            Response(text: "\"Green lights across the system.\"", type: .positive),
            Response(text: "\"Yes — dodge nothing.\"", type: .positive),
            Response(text: "\"The code flickers — unclear.\"", type: .neutral),
            Response(text: "\"Ask again — the system is shifting.\"", type: .neutral),
            Response(text: "\"Not even the Oracle knows yet.\"", type: .neutral),
            Response(text: "\"You're waiting for something… maybe.\"", type: .neutral),
            Response(text: "\"The answer is loading…\"", type: .neutral),
            Response(text: "\"No — not this reality.\"", type: .negative),
            Response(text: "\"System rejects the request.\"", type: .negative),
            Response(text: "\"A glitch says no.\"", type: .negative),
            Response(text: "\"You chose the wrong door.\"", type: .negative),
            Response(text: "\"No — fate denies it.\"", type: .negative)
        ])
    }
    
    private func createXanga2002Set() -> ResponseSet {
        ResponseSet(id: "xanga2002", name: "Glitter Blog '02", emoji: "📓", category: .techEras, responses: [
            Response(text: "OMG YESSSS!!!", type: .positive),
            Response(text: "yesss babe ilysm", type: .positive),
            Response(text: "YES — miss ur face!!!", type: .positive),
            Response(text: "ahh totally yes 💕", type: .positive),
            Response(text: "def a yes omg", type: .positive),
            Response(text: "YES GIRL DO IT", type: .positive),
            Response(text: "yaaaas u got this!!!", type: .positive),
            Response(text: "yes!! updating my status rn", type: .positive),
            Response(text: "hehehe YES :)", type: .positive),
            Response(text: "YESSS happy tears", type: .positive),
            Response(text: "idk babe… thinking", type: .neutral),
            Response(text: "hmm maybe??", type: .neutral),
            Response(text: "ask me l8r im spiraling lol", type: .neutral),
            Response(text: "ugh confusing rn", type: .neutral),
            Response(text: "can't decide… brb", type: .neutral),
            Response(text: "noooo :(", type: .negative),
            Response(text: "ugh nope babe", type: .negative),
            Response(text: "sadly… no rn", type: .negative),
            Response(text: "nope. don't ask y.", type: .negative),
            Response(text: "noooo dramatic sigh", type: .negative)
        ])
    }
    
    private func createShakespeareanSet() -> ResponseSet {
        ResponseSet(id: "shakespearean", name: "Shakespearean", emoji: "🪶", category: .styles, responses: [
            Response(text: "\"Aye, most surely.\"", type: .positive),
            Response(text: "\"'Tis a resounding yes.\"", type: .positive),
            Response(text: "\"Fortune smiles upon thee.\"", type: .positive),
            Response(text: "\"Aye — the stars consent.\"", type: .positive),
            Response(text: "\"Verily, it shall be so.\"", type: .positive),
            Response(text: "\"Thy wish be granted.\"", type: .positive),
            Response(text: "\"All omens point to yes.\"", type: .positive),
            Response(text: "\"Aye, with noble certainty.\"", type: .positive),
            Response(text: "\"'Tis yes, by my troth.\"", type: .positive),
            Response(text: "\"The fates cry 'Yes!'\"", type: .positive),
            Response(text: "\"The signs are clouded.\"", type: .neutral),
            Response(text: "\"Ask again anon.\"", type: .neutral),
            Response(text: "\"I cannot say, good friend.\"", type: .neutral),
            Response(text: "\"The hour is uncertain.\"", type: .neutral),
            Response(text: "\"Patience — truth unfolds.\"", type: .neutral),
            Response(text: "\"Nay, not this time.\"", type: .negative),
            Response(text: "\"The fates deny thee.\"", type: .negative),
            Response(text: "\"A sorrowful no.\"", type: .negative),
            Response(text: "\"Nay — abandon this quest.\"", type: .negative),
            Response(text: "\"'Tis folly. The answer is no.\"", type: .negative)
        ])
    }
    
    private func createTwitterX2024Set() -> ResponseSet {
        ResponseSet(id: "twitterx2024", name: "The Timeline '25", emoji: "🐦", category: .techEras, responses: [
            Response(text: "\"Hard yes. Don't @ me.\"", type: .positive),
            Response(text: "\"W. Massive W.\"", type: .positive),
            Response(text: "\"Yes — verified vibes only.\"", type: .positive),
            Response(text: "\"Algo boosted: yes.\"", type: .positive),
            Response(text: "\"Yeah, that tracks.\"", type: .positive),
            Response(text: "\"Source: trust me bro (yes).\"", type: .positive),
            Response(text: "\"Community Notes agree: yes.\"", type: .positive),
            Response(text: "\"Yes. Screenshot this.\"", type: .positive),
            Response(text: "\"Whole timeline says yes.\"", type: .positive),
            Response(text: "\"Certified yes. Bookmark it.\"", type: .positive),
            Response(text: "\"idk, timeline's split.\"", type: .neutral),
            Response(text: "\"Reply hazy, muted this.\"", type: .neutral),
            Response(text: "\"Maybe — trending unclear.\"", type: .neutral),
            Response(text: "\"Shadowbanned answer. Try again.\"", type: .neutral),
            Response(text: "\"Scrolling… loading… idk.\"", type: .neutral),
            Response(text: "\"L. Huge L.\"", type: .negative),
            Response(text: "\"Nah. Ratio incoming.\"", type: .negative),
            Response(text: "\"Nope — deleting tweet.\"", type: .negative),
            Response(text: "\"Hard pass. Flagged as cringe.\"", type: .negative),
            Response(text: "\"No. Blocked.\"", type: .negative)
        ])
    }
    
    private func createDeviantArt2006Set() -> ResponseSet {
        ResponseSet(id: "deviantart2006", name: "Fan Art '06", emoji: "🎨", category: .techEras, responses: [
            Response(text: "omg yesss!! ^_^", type: .positive),
            Response(text: "totally yes <333", type: .positive),
            Response(text: "yus!! glomps u", type: .positive),
            Response(text: "yes!! ur OC would love it", type: .positive),
            Response(text: "def yes!! so cool lol", type: .positive),
            Response(text: "yesss plz do!!", type: .positive),
            Response(text: "yes!! fave + watch!!", type: .positive),
            Response(text: "omg YES like in my journal", type: .positive),
            Response(text: "yesss it's so kawaii!!", type: .positive),
            Response(text: "YES! drawing it rn lol", type: .positive),
            Response(text: "idk… my tablet's laggy", type: .neutral),
            Response(text: "maybe?? still thinking", type: .neutral),
            Response(text: "hmm… could go either way", type: .neutral),
            Response(text: "ask l8r, doing requests", type: .neutral),
            Response(text: "not sure… busy w/ school", type: .neutral),
            Response(text: "nooo sorry ;;", type: .negative),
            Response(text: "nope… not feeling it", type: .negative),
            Response(text: "nah, OC says no lol", type: .negative),
            Response(text: "no… pls don't steal art", type: .negative),
            Response(text: "sry but no thx", type: .negative)
        ])
    }
    
    private func createMillennialSet() -> ResponseSet {
        ResponseSet(id: "millennial", name: "Millennials", emoji: "📼", category: .generations, responses: [
            Response(text: "yeah totally", type: .positive),
            Response(text: "big yes vibes", type: .positive),
            Response(text: "for sure, man", type: .positive),
            Response(text: "def a yes", type: .positive),
            Response(text: "that tracks", type: .positive),
            Response(text: "solid yes, dude", type: .positive),
            Response(text: "yep — classic win", type: .positive),
            Response(text: "100%, no drama", type: .positive),
            Response(text: "feels like a yes", type: .positive),
            Response(text: "absolutely, friend", type: .positive),
            Response(text: "idk, kinda mixed", type: .neutral),
            Response(text: "maybe? need coffee", type: .neutral),
            Response(text: "hard to say rn", type: .neutral),
            Response(text: "circling back later", type: .neutral),
            Response(text: "ask again post-snack", type: .neutral),
            Response(text: "nah, not today", type: .negative),
            Response(text: "big nope", type: .negative),
            Response(text: "pass on that", type: .negative),
            Response(text: "yeahhh no", type: .negative),
            Response(text: "oof, nope sorry", type: .negative)
        ])
    }
    
    private func createGenAlphaSet() -> ResponseSet {
        ResponseSet(id: "genalpha", name: "Gen Alpha", emoji: "🍼", category: .generations, responses: [
            Response(text: "YESS!!!", type: .positive),
            Response(text: "omg YES lol", type: .positive),
            Response(text: "yup yup YUP", type: .positive),
            Response(text: "super yes!!!", type: .positive),
            Response(text: "yes bc i decided", type: .positive),
            Response(text: "yes like 100 times", type: .positive),
            Response(text: "YES DUH", type: .positive),
            Response(text: "big yes bro", type: .positive),
            Response(text: "yes i told my friends", type: .positive),
            Response(text: "yes!!! high five!!", type: .positive),
            Response(text: "umm maybe?", type: .neutral),
            Response(text: "idk i'm thinking", type: .neutral),
            Response(text: "hold on i'm busy", type: .neutral),
            Response(text: "ask later i'm drawing", type: .neutral),
            Response(text: "hmm… not sure yet", type: .neutral),
            Response(text: "nooooooope", type: .negative),
            Response(text: "bro that's a no", type: .negative),
            Response(text: "nah i don't wanna", type: .negative),
            Response(text: "nope sorry :/", type: .negative),
            Response(text: "mom said no", type: .negative)
        ])
    }
    
    private func createHunterSThompsonSet() -> ResponseSet {
        ResponseSet(id: "huntersthompson", name: "Gonzo", emoji: "🦂", category: .styles, responses: [
            Response(text: "\"Hell yes — ride the wave.\"", type: .positive),
            Response(text: "\"Absolutely — full throttle.\"", type: .positive),
            Response(text: "\"A savage YES, my friend.\"", type: .positive),
            Response(text: "\"The universe nods drunkenly.\"", type: .positive),
            Response(text: "\"Yes — chase it like a madman.\"", type: .positive),
            Response(text: "\"By God, yes.\"", type: .positive),
            Response(text: "\"A clean, honest yes.\"", type: .positive),
            Response(text: "\"Yes — lean into the chaos.\"", type: .positive),
            Response(text: "\"Yes, the road opens.\"", type: .positive),
            Response(text: "\"Yes — the bats approve.\"", type: .positive),
            Response(text: "\"Hard to say — the air is humming.\"", type: .neutral),
            Response(text: "\"Maybe… need another hit of truth.\"", type: .neutral),
            Response(text: "\"Unclear — fog on the horizon.\"", type: .neutral),
            Response(text: "\"The signal's flickering.\"", type: .neutral),
            Response(text: "\"Ask again — the room's spinning.\"", type: .neutral),
            Response(text: "\"No — abandon ship.\"", type: .negative),
            Response(text: "\"Absolutely not — pure madness.\"", type: .negative),
            Response(text: "\"No, unless you hate yourself.\"", type: .negative),
            Response(text: "\"The desert says no.\"", type: .negative),
            Response(text: "\"No — even I won't try that.\"", type: .negative)
        ])
    }
    
    
    func getRandomResponse() -> Response? {
        return responses.randomElement()
    }
}
