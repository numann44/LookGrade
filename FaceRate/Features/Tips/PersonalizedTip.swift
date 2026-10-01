import Foundation

/// How aggressively a tip should read. Drives headline tone and the urgency
/// badge color on the Tips screen.
enum TipUrgency {
    case high      // score < 6.5 — significant gap
    case medium    // 6.5..7.5 — clear opportunity
    case maintain  // >= 7.5 — already strong
}

/// One personalized tip card, generated from a single category score.
/// Sensitive to the actual numeric score: low scores get urgent tone and
/// concrete intervention bullets; high scores get maintenance-tone copy.
struct PersonalizedTip: Identifiable {
    var id: String { category.rawValue }
    let category: ScoreCategory
    let score: Double
    let icon: String
    let headline: String
    let body: String
    let actions: [String]
    let urgency: TipUrgency
    let tags: [String]
}

enum TipBuilder {
    static func urgency(for score: Double) -> TipUrgency {
        if score < 6.5 { return .high }
        if score < 7.5 { return .medium }
        return .maintain
    }

    static func forScore(_ category: ScoreCategory, _ score: Double) -> PersonalizedTip {
        let u = urgency(for: score)
        let base = bases[category]!

        let tonePrefix: String
        let headline: String
        let actions: [String]
        let bodyDetail: String
        switch u {
        case .high:
            tonePrefix = "Significant opportunity:"
            headline = base.headlineHigh
            actions = base.actionsHigh
            bodyDetail = base.bodyHigh
        case .medium:
            tonePrefix = "Room to refine:"
            headline = base.headlineMedium
            actions = base.actionsMedium
            bodyDetail = base.bodyMedium
        case .maintain:
            tonePrefix = "Already strong —"
            headline = base.headlineMaintain
            actions = base.actionsMaintain
            bodyDetail = base.bodyMaintain
        }

        let body = String(
            format: NSLocalizedString("%1$@ your %2$@ score is %3$@ / 10. %4$@", comment: "tip body: tone, category, score, detail"),
            NSLocalizedString(tonePrefix, comment: "tone prefix"),
            category.label,
            String(format: "%.1f", locale: L10n.locale, score),
            NSLocalizedString(bodyDetail, comment: "tip body detail")
        )

        return PersonalizedTip(
            category: category, score: score, icon: base.icon,
            headline: NSLocalizedString(headline, comment: "tip headline"),
            body: body,
            actions: actions.map { NSLocalizedString($0, comment: "tip action") },
            urgency: u,
            tags: base.tags.map { NSLocalizedString($0, comment: "tag") }
        )
    }

    fileprivate struct Base {
        let icon: String
        let headlineHigh: String
        let headlineMedium: String
        let headlineMaintain: String
        let bodyHigh: String
        let bodyMedium: String
        let bodyMaintain: String
        let actionsHigh: [String]
        let actionsMedium: [String]
        let actionsMaintain: [String]
        let tags: [String]
    }

    fileprivate static let bases: [ScoreCategory: Base] = [
        .symmetry: Base(
            icon: "scale",
            headlineHigh: "Reset facial balance",
            headlineMedium: "Tighten symmetry",
            headlineMaintain: "Keep your balance",
            bodyHigh: "Visible left/right offset detected — likely posture-related. Daily mirror practice and side-stretches make the largest near-term gains.",
            bodyMedium: "Small asymmetry shows up in your contours. A short daily routine can clean this up over a few weeks.",
            bodyMaintain: "Your face reads well-balanced. Hold this with daily posture habits.",
            actionsHigh: [
                "Hold your phone at eye level when capturing — most asymmetry is camera angle",
                "Daily 5-min neck side-stretches (each side)",
                "Sleep on your back for one week and re-scan",
            ],
            actionsMedium: [
                "Mirror practice 2 minutes per side per day",
                "Cross-body posture exercises 3x/week",
                "Re-scan in 14 days to track movement",
            ],
            actionsMaintain: [
                "Keep up your posture routine",
                "Re-scan monthly to confirm stability",
            ],
            tags: ["Posture", "Stretching"]
        ),
        .skin: Base(
            icon: "droplet",
            headlineHigh: "Rebuild your skin barrier",
            headlineMedium: "Smooth out skin texture",
            headlineMaintain: "Maintain clear skin",
            bodyHigh: "Cheek pixels show high luminance variance — likely texture or redness. Focus on barrier repair before any active ingredients.",
            bodyMedium: "Some unevenness in your cheek samples. A targeted routine cleans this up over 4–6 weeks.",
            bodyMaintain: "Skin texture reads even and well-hydrated. Light maintenance only.",
            actionsHigh: [
                "Switch to a gentle, fragrance-free cleanser",
                "Add a ceramide moisturizer AM + PM",
                "Cut actives (retinol, AHA/BHA) for 2 weeks, then re-scan",
            ],
            actionsMedium: [
                "Hydrate to ~3L water/day",
                "Add a 5% niacinamide serum every morning",
                "SPF 30+ daily — even indoors near windows",
            ],
            actionsMaintain: [
                "Continue your current routine",
                "Add one weekly exfoliation if not already",
            ],
            tags: ["Skincare", "Hydration"]
        ),
        .jawline: Base(
            icon: "dumbbell",
            headlineHigh: "Define your lower face",
            headlineMedium: "Sharpen jaw definition",
            headlineMaintain: "Keep your jawline sharp",
            bodyHigh: "Chin angle reads soft. Targeted daily work + reduced sodium will show measurable change in 8–12 weeks.",
            bodyMedium: "Your jaw is mostly well-defined; a small consistent routine sharpens the V-line over a few months.",
            bodyMaintain: "Strong lateral projection along the mandible. Maintain with consistent posture and hydration.",
            actionsHigh: [
                "Mewing — tongue on roof of mouth — all day, every day",
                "20 chin tucks, 3 sets daily",
                "Cut sodium below 2g/day for 2 weeks (de-puffs the lower face)",
            ],
            actionsMedium: [
                "Mewing throughout the workday",
                "15 chin tucks 2x/day",
                "Track water intake — aim for 3L/day",
            ],
            actionsMaintain: [
                "Maintain mewing as a posture habit",
                "Re-scan monthly",
            ],
            tags: ["Routine", "Diet"]
        ),
        .eyes: Base(
            icon: "eye",
            headlineHigh: "Brighten and open the eyes",
            headlineMedium: "Add eye expressiveness",
            headlineMaintain: "Keep your eyes striking",
            bodyHigh: "Eye-open probability is low — fatigue or undereye shadow is visible. Sleep + cold compress is the highest-leverage fix.",
            bodyMedium: "Small upward canthal tilt and good ratio. Rested eyes will add another half-point.",
            bodyMaintain: "Exceptional canthal tilt and eye-to-face ratio. Stay rested.",
            actionsHigh: [
                "Sleep 7–8h for 5 consecutive nights",
                "Cold compress 90 sec each morning",
                "Hydrate 500ml right after waking",
            ],
            actionsMedium: [
                "Cap caffeine after 2pm",
                "Add an undereye serum at night",
                "Re-scan after a full week of 7+ hour sleep",
            ],
            actionsMaintain: [
                "Maintain your sleep schedule",
                "Track eye openness in monthly scans",
            ],
            tags: ["Sleep", "Hydration"]
        ),
        .lips: Base(
            icon: "smile",
            headlineHigh: "Restore lip color & shape",
            headlineMedium: "Refine lip definition",
            headlineMaintain: "Keep lip shape sharp",
            bodyHigh: "Vermillion border reads soft. Hydration + barrier care is the first move; pigmentation and shape follow naturally.",
            bodyMedium: "Lip width and balance are healthy. A small care routine preserves color and definition.",
            bodyMaintain: "Strong vermillion definition and balance. Light maintenance.",
            actionsHigh: [
                "Lip balm with SPF 15+ every 2h outdoors",
                "Stop licking lips — biggest cause of soft borders",
                "Weekly gentle exfoliation with a damp cloth",
            ],
            actionsMedium: [
                "Hydrating balm AM + PM",
                "Weekly exfoliation",
            ],
            actionsMaintain: [
                "Continue your current lip-care routine",
            ],
            tags: ["Skincare"]
        ),
        .nose: Base(
            icon: "move",
            headlineHigh: "Rebalance nose proportion",
            headlineMedium: "Refine nose contour",
            headlineMaintain: "Keep nose proportions clean",
            bodyHigh: "Bridge or width reads off-target. Camera angle and lighting drive most of this — try shooting closer to eye level.",
            bodyMedium: "Proportions are close to ideal. Lighting awareness will close the remaining gap in photos.",
            bodyMaintain: "Bridge proportions sit close to classical ideals. Maintain.",
            actionsHigh: [
                "Capture from eye level — phones below the chin distort the nose",
                "Front lighting flattens the bridge naturally",
                "If using makeup: subtle bridge shading",
            ],
            actionsMedium: [
                "Shoot in soft, front-facing daylight",
                "Avoid wide-angle phone modes — they exaggerate the nose",
            ],
            actionsMaintain: [
                "Stick with eye-level capture",
            ],
            tags: ["Photography", "Makeup"]
        ),
        .tone: Base(
            icon: "sun",
            headlineHigh: "Even your skin tone",
            headlineMedium: "Balance left/right tone",
            headlineMaintain: "Maintain even tone",
            bodyHigh: "Significant left/right cheek RGB delta detected. Most likely sun damage on one side — daily SPF + vitamin C is the fix.",
            bodyMedium: "Mild reflectance gradient between cheeks. SPF + a brightening serum levels this out over weeks.",
            bodyMaintain: "Reflectance is consistent across cheeks. Strong daily habits.",
            actionsHigh: [
                "SPF 30+ every morning, every day, including indoors",
                "10–15% vitamin C serum daily",
                "Re-apply SPF when driving (window-side cheek darkens)",
            ],
            actionsMedium: [
                "SPF 30+ daily",
                "Add weekly gentle exfoliation",
            ],
            actionsMaintain: [
                "Maintain SPF as a non-negotiable",
            ],
            tags: ["SPF", "Vitamin C"]
        ),
        .harmony: Base(
            icon: "scan",
            headlineHigh: "Restore facial proportions",
            headlineMedium: "Tune facial harmony",
            headlineMaintain: "Strong proportions — maintain",
            bodyHigh: "Facial-thirds ratio is off-target. Hairstyle and frame choices have huge leverage here without changing anything else.",
            bodyMedium: "Thirds and fifths are close to ideal. Frame and hairstyle can reinforce the proportions in photos.",
            bodyMaintain: "Thirds and fifths align with classical ratios.",
            actionsHigh: [
                "Try a hairstyle that adds height — closes the upper third",
                "Glasses with a strong horizontal can rebalance vertically",
                "Beard length/shape changes the lower third dramatically",
            ],
            actionsMedium: [
                "Experiment with one hairstyle change",
                "Try eyebrow grooming to define the upper third",
            ],
            actionsMaintain: [
                "Stick with your current frame & hair",
            ],
            tags: ["Style"]
        ),
    ]
}
