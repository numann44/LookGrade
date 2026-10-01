import SwiftUI
import RiveRuntime

/// Owns the single Rive state-machine instance used throughout onboarding.
/// Commands are queued until Rive's default view-model instance is bound, so
/// the first wake/pose request is never lost on a cold launch.
@MainActor
final class MiroMascotController: ObservableObject {
    let riveViewModel: RiveViewModel

    private var lastEyeGesture = -Double.infinity
    private var expressionTask: Task<Void, Never>?
    private var reducesMotion = false
    private var dataBindingInstance: RiveDataBindingViewModel.Instance?
    private var pendingTriggers: [String] = []
    private var pendingNumbers: [String: Float] = [:]
    private var pendingBooleans: [String: Bool] = [:]

    init() {
        let model = RiveViewModel(
            fileName: "miro_pro",
            stateMachineName: "MiroMachine",
            fit: .contain,
            alignment: .center,
            autoPlay: true,
            artboardName: "Miro_Pro",
            loadCdn: false
        )
        riveViewModel = model

        model.riveModel?.enableAutoBind { [weak self] instance in
            guard let self else { return }
            dataBindingInstance = instance
            flushPendingCommands()
        }
    }

    enum Expression: Float {
        case neutral = 0, grin, curious, sad, laugh
    }

    func express(_ expression: Expression) {
        expressionTask?.cancel()
        // Celebrate once, then settle into a relaxed smile.
        let pose: Expression = reducesMotion && expression == .laugh ? .grin : expression
        setNumber("expression", value: pose.rawValue)
        guard pose == .laugh else { return }
        expressionTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(1.9)) } catch { return }
            self?.setNumber("expression", value: Expression.grin.rawValue)
        }
    }

    func wake() {
        fire("wake")
    }

    func blink() { eyeGesture("blink") }
    func wink() { eyeGesture("wink") }
    func doubleBlink() { eyeGesture("doubleBlink") }

    private func eyeGesture(_ name: String) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEyeGesture >= 0.7 else { return }
        lastEyeGesture = now
        fire(name)
    }

    func attend(to target: MiroAttention) {
        let direction = target.direction
        look(x: direction.x, y: direction.y)
    }

    /// Short, varied glances always return to the current speech/control target.
    /// Owned by the visible SwiftUI view, so scene changes cancel the old routine.
    func animatePresence(attention: MiroAttention) async {
        attend(to: attention)
        let delays = [1.7, 2.3, 1.9, 2.6, 1.6]
        let glances: [MiroAttention] = [.center, .left, .right, .down]
        var beat = 0
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(delays[beat % delays.count])) } catch { return }
            guard !Task.isCancelled, !reducesMotion else { return }
            if beat % 6 == 5 { wink() }
            else if beat % 4 == 2 { doubleBlink() }
            else { blink() }
            if beat.isMultiple(of: 2) {
                attend(to: glances[(beat / 2) % glances.count])
                do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
                guard !Task.isCancelled else { return }
                attend(to: attention)
            }
            beat += 1
        }
    }

    func tap() {
        fire("tap")
    }

    func look(x: Float = 0, y: Float = 0) {
        // The authored gaze states use one axis at a time. Resolve diagonal
        // requests to their strongest axis so no request falls between states.
        let horizontal = abs(x) >= abs(y)
        setNumber("lookX", value: horizontal ? max(-1, min(1, x)) : 0)
        setNumber("lookY", value: horizontal ? 0 : max(-1, min(1, y)))
    }

    func setReducedMotion(_ enabled: Bool) {
        reducesMotion = enabled
        setBoolean("reducedMotion", value: enabled)
        if enabled {
            expressionTask?.cancel()
            look()
            riveViewModel.pause()
        } else {
            riveViewModel.play()
        }
    }

    private func fire(_ propertyName: String) {
        guard !reducesMotion else { return }
        guard let property = dataBindingInstance?.triggerProperty(fromPath: propertyName) else {
            if !pendingTriggers.contains(propertyName) { pendingTriggers.append(propertyName) }
            return
        }
        property.trigger()
        advanceImmediately()
    }

    private func setNumber(_ propertyName: String, value: Float) {
        guard let property = dataBindingInstance?.numberProperty(fromPath: propertyName) else {
            pendingNumbers[propertyName] = value
            return
        }
        property.value = value
        advanceImmediately()
    }

    private func setBoolean(_ propertyName: String, value: Bool) {
        guard let property = dataBindingInstance?.booleanProperty(fromPath: propertyName) else {
            pendingBooleans[propertyName] = value
            return
        }
        property.value = value
        advanceImmediately()
    }

    private func flushPendingCommands() {
        let numbers = pendingNumbers
        let booleans = pendingBooleans
        let triggers = pendingTriggers
        pendingNumbers.removeAll()
        pendingBooleans.removeAll()
        pendingTriggers.removeAll()

        for (name, value) in numbers {
            setNumber(name, value: value)
        }
        for (name, value) in booleans {
            setBoolean(name, value: value)
        }
        for name in triggers {
            fire(name)
        }
    }

    private func advanceImmediately() {
        // Auto-play advances continuously. This zero-delta advance also makes
        // a freshly written data-binding value visible in the same run loop.
        riveViewModel.riveView?.advance(delta: reducesMotion ? 0.2 : 0)
        if reducesMotion { riveViewModel.pause() }
    }
}

enum MiroAttention: String {
    case center, left, right, up, down

    var direction: (x: Float, y: Float) {
        switch self {
        case .center: return (0, 0)
        case .left: return (-0.8, 0)
        case .right: return (0.8, 0)
        case .up: return (0, -0.8)
        case .down: return (0, 0.8)
        }
    }
}

struct MiroMascotView: View {
    @ObservedObject var controller: MiroMascotController
    var attention: MiroAttention = .center
    var onTap: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var physicalAttention: MiroAttention {
        guard L10n.isRightToLeft else { return attention }
        switch attention {
        case .left: return .right
        case .right: return .left
        default: return attention
        }
    }

    var body: some View {
        controller.riveViewModel
            .view()
            .contentShape(Rectangle())
            .onTapGesture {
                controller.tap()
                onTap?()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("Miro, your LookGrade guide"))
            .accessibilityAddTraits(.isImage)
            .task(id: "\(attention.rawValue)-\(reduceMotion)-\(scenePhase)") {
                controller.setReducedMotion(reduceMotion)
                guard scenePhase == .active else {
                    controller.riveViewModel.pause()
                    return
                }
                guard !reduceMotion else { return }
                await controller.animatePresence(attention: physicalAttention)
            }
    }
}

/// A reusable speaking companion for the scan, report, and purchase journey.
struct MiroCompanion: View {
    let message: String
    var expression: MiroMascotController.Expression = .grin
    var size: CGFloat = 154
    var stacked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var controller = MiroMascotController()

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: 2) {
                    mascot
                    speech
                }
            } else {
                HStack(spacing: 0) {
                    mascot
                    speech
                }
            }
        }
        .task(id: expression) {
            controller.setReducedMotion(reduceMotion)
            controller.express(expression)
        }
        .onChange(of: reduceMotion) { _, enabled in
            controller.setReducedMotion(enabled)
        }
        .onAppear { controller.wake() }
    }

    private var mascot: some View {
        MiroMascotView(controller: controller, attention: stacked ? .down : .right)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var speech: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MIRO")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : 1.3)
                .foregroundStyle(Color(rgb: 0x42665A))
            Text(message)
                .font(.system(size: stacked ? 20 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(rgb: 0x17251F))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(rgb: 0xF5F5F1), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// A tap and an expiring timer can arrive in the same run loop. A timer must
/// name the line it belongs to; an old timer can never skip a newer line.
struct MiroDialogueProgress {
    enum Advance: Equatable { case ignored, next, finished }
    static let readingDelay: Double = 5.5
    let count: Int
    private(set) var index = 0
    private(set) var isFinished = false
    private var lastAdvance: TimeInterval = -.infinity

    init(count: Int) {
        precondition(count > 0)
        self.count = count
    }

    mutating func advance(from expectedIndex: Int, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Advance {
        guard !isFinished, expectedIndex == index, now - lastAdvance >= 0.35 else { return .ignored }
        lastAdvance = now
        if index < count - 1 {
            index += 1
            return .next
        }
        isFinished = true
        return .finished
    }
}
