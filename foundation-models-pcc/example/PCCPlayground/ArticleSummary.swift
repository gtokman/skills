import FoundationModels

/// Structured-output demo type, mirroring the example from WWDC26 session 319.
@Generable
nonisolated struct ArticleSummary {
    @Guide(description: "A single-sentence summary of the input.")
    let oneLineSummary: String

    @Guide(description: "Three to five key points from the input, each one short sentence.")
    let keyPoints: [String]

    @Guide(description: "The overall tone of the input, in one or two words, such as neutral or enthusiastic.")
    let tone: String
}

enum SamplePrompt: String, CaseIterable, Identifiable {
    case summarize = "Summarize an article"
    case reasoning = "Reasoning puzzle"
    case photo = "Describe a photo"

    var id: Self { self }

    var text: String {
        switch self {
        case .summarize:
            """
            Summarize this article:

            The town of Harlow Creek voted last week to convert its unused rail depot into a \
            community workshop. The building has sat empty for eleven years after freight service \
            moved to the regional hub. Under the plan, the ground floor becomes a shared space with \
            woodworking tools, sewing machines and a small electronics bench, while the upper floor \
            hosts evening classes run by volunteers.

            Supporters argued the workshop would give residents access to equipment few households \
            can justify buying, and would bring foot traffic back to the old station district. \
            Opponents worried about insurance costs and whether volunteer interest would last past \
            the first year. The council approved a two-year trial funded by a state grant, with a \
            review of attendance and costs at the halfway point.

            Renovation starts in March. Organizers say they already have forty people signed up to \
            teach or supervise, and local businesses have pledged a starter set of tools.
            """
        case .reasoning:
            """
            Five friends (Ana, Ben, Cy, Dee, Eli) sit in a row of five seats numbered 1 to 5. \
            Ana is not at either end. Ben sits immediately to the right of Cy. Dee is in an \
            odd-numbered seat. Eli is not next to Ana. Cy is in seat 2 or 3. \
            Find every valid seating arrangement and explain how you know there are no others.
            """
        case .photo:
            "Describe what's in this photo, then list anything notable a person might want to know about it."
        }
    }
}
