import Foundation

/// Picks an SF Symbol for an event from the words in its title, e.g. "Gym" → figure.run.
public enum EventIcon {
    /// Keyword → symbol. A keyword matches a whole word or the start of one ("flights" matches "flight").
    /// Earlier rules win, so the more specific ones come first.
    static let rules: [(keywords: [String], symbol: String)] = [
        (["birthday", "bday", "anniversary"], "gift.fill"),
        (["flight", "fly", "airport", "boarding"], "airplane.departure"),
        (["train", "rail"], "tram.fill"),
        (["tennis", "padel"], "tennis.racket"),
        (["football", "soccer"], "soccerball"),
        (["basketball"], "basketball.fill"),
        (["swim", "pool"], "figure.pool.swim"),
        (["yoga", "pilates", "stretch"], "figure.yoga"),
        (["bike", "cycling", "cycle", "spin"], "bicycle"),
        (["run", "running", "jog", "marathon", "parkrun"], "figure.run"),
        (["gym", "workout", "training", "crossfit", "lift", "fitness"], "dumbbell.fill"),
        (["dentist", "doctor", "dr", "gp", "clinic", "hospital", "checkup", "physio"], "cross.case.fill"),
        (["haircut", "barber", "hair"], "scissors"),
        (["dinner", "lunch", "brunch", "restaurant"], "fork.knife"),
        (["breakfast", "coffee", "cafe"], "cup.and.saucer.fill"),
        (["drinks", "bar", "pub", "beer", "wine"], "wineglass.fill"),
        (["party", "celebration", "wedding"], "party.popper.fill"),
        (["movie", "movies", "cinema", "film"], "film.fill"),
        (["concert", "gig", "music", "rehearsal"], "music.note"),
        (["book", "reading", "library"], "book.fill"),
        (["call", "phone"], "phone.fill"),
        (["standup", "meeting", "sync", "1:1", "review", "interview", "workshop"], "person.2.fill"),
        (["class", "lecture", "course", "lesson", "exam", "school"], "graduationcap.fill"),
        (["shopping", "groceries", "grocery", "market"], "cart.fill"),
        (["ski", "skiing", "snowboard"], "figure.skiing.downhill"),
        (["holiday", "vacation", "trip", "travel"], "suitcase.fill"),
        (["hotel"], "bed.double.fill"),
        (["car", "service", "mot"], "car.fill"),
        (["vet", "dog", "cat"], "pawprint.fill"),
        (["pay", "rent", "bill", "bank", "tax", "invoice"], "creditcard.fill"),
        (["deadline", "due", "launch", "release"], "flag.checkered"),
    ]

    /// The symbol for a title, or nil when no word matches.
    public static func symbol(for title: String) -> String? {
        let words = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ":")).inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        for rule in rules {
            for k in rule.keywords {
                // Short keywords must match a whole word, so "dr" doesn't catch "drinks" and "run" doesn't catch "brunch".
                if words.contains(where: { k.count <= 3 ? $0 == k : ($0 == k || $0.hasPrefix(k)) }) {
                    return rule.symbol
                }
            }
        }
        return nil
    }
}
