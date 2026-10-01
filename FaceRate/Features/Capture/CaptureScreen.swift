import SwiftUI
import PhotosUI
import Photos
import UIKit

private enum CamState { case initializing, ready, denied, restricted, unsupported, error }

private enum GalleryAlert: Identifiable {
    case accessDenied
    case accessRestricted
    case loadFailed(String)

    var id: String {
        switch self {
        case .accessDenied: return "accessDenied"
        case .accessRestricted: return "accessRestricted"
        case .loadFailed: return "loadFailed"
        }
    }
}

/// Live front-camera capture with an oval framing guide. Falls back to
/// `PhotosPicker` when live camera isn't available (simulator, permission
/// denied, or a capture error) — mirrors capture_screen.dart's `_CamState`
/// state machine exactly, including the specific hint copy per state.
struct CaptureScreen: View {
    var onCancel: () -> Void
    var onCaptured: (ScanInput) -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var service = CaptureService()
    @State private var state: CamState = .initializing
    @State private var errorMessage: String?
    @State private var flashOn = false
    @State private var capturing = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var requestingPhotoAccess = false
    @State private var galleryAlert: GalleryAlert?
    @State private var isInterrupted = false
    @State private var screenFlash = false
    @State private var savedBrightness = UIScreen.main.brightness
    @State private var feedback: CaptureFeedback?
    @State private var alignedSince: Date?

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            if state == .ready {
                CameraPreviewView(service: service)
                    .ignoresSafeArea()
            }

            OvalCameraOverlay(state: overlayState)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }

            if isInterrupted && state == .ready {
                interruptionOverlay
            }

            if screenFlash {
                Color.white.ignoresSafeArea()
            }
        }
        .background(Color.black)
        .analyticsScreen("camera")
        .onChange(of: state) { _, value in
            AppAnalytics.shared.track(.cameraState, ["state": String(describing: value)])
        }
        .task { await bootCamera() }
        .onDisappear { service.dispose() }
        .onChange(of: scenePhase) { _, phase in
            guard state == .ready else { return }
            switch phase {
            case .active: service.start()
            case .background, .inactive: service.stop()
            @unknown default: break
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: showPicker) { _, isPresented in
            AppAnalytics.shared.track(.cameraAction, ["action": isPresented ? "gallery_opened" : "gallery_closed"])
            guard state == .ready else { return }
            if isPresented {
                service.stop()
            } else if scenePhase == .active {
                service.start()
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePicked(newItem) }
        }
        .alert(item: $galleryAlert) { alert in
            switch alert {
            case .accessDenied:
                return Alert(
                    title: Text(L10n.text("Photo access is off")),
                    message: Text(L10n.text("Allow photo access in Settings to choose a photo from your library.")),
                    primaryButton: .default(Text(L10n.text("Open Settings")), action: openAppSettings),
                    secondaryButton: .cancel()
                )
            case .accessRestricted:
                return Alert(
                    title: Text(L10n.text("Photo access is restricted")),
                    message: Text(L10n.text("Photo access is restricted by this device's settings.")),
                    dismissButton: .default(Text(L10n.text("OK")))
                )
            case .loadFailed(let message):
                return Alert(
                    title: Text(L10n.text("Couldn't use that photo")),
                    message: Text(message),
                    dismissButton: .default(Text(L10n.text("Choose Another")), action: {
                        Task { await openGallery() }
                    })
                )
            }
        }
    }

    private var interruptionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: AppSpacing.sm12) {
                LucideIcon(name: "camera-off", size: 40).foregroundStyle(AppColors.textSecondary)
                Text(L10n.text("Camera paused")).appFont(.h2).foregroundStyle(AppColors.textPrimary)
                Text(L10n.text("Resumes automatically when the interruption ends."))
                    .appFont(.body).foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.xl24)
        }
        .transition(.opacity)
    }

    private var background: some View {
        Group {
            if state == .ready {
                Color.black
            } else {
                RadialGradient(colors: [AppColors.bgSurface, .black], center: .center, startRadius: 0, endRadius: 500)
                    .overlay { LucideIcon(name: "smile", size: 64).foregroundStyle(AppColors.textTertiary) }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.selection()
                AppAnalytics.shared.track(.cameraAction, ["action": "close"])
                onCancel()
            } label: {
                LucideIcon(name: "x", size: 20)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.bgSurface.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(L10n.text("Close"))
            Spacer()
            if state == .ready {
                controlPill
            }
            Spacer()
            lightingIndicator
        }
        .padding(.horizontal, AppSpacing.md16)
        .padding(.top, AppSpacing.xs8)
    }

    private var controlPill: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.selection()
                flashOn.toggle()
                AppAnalytics.shared.track(.cameraAction, ["action": "flash_toggle", "selected": flashOn])
            } label: {
                LucideIcon(name: flashOn ? "zap" : "zap-off", size: 18)
                    .foregroundStyle(flashOn ? AppColors.stateWarning : AppColors.textPrimary)
                    .frame(width: 36, height: 36)
            }
            // Front cameras have no torch; a bright white screen flash is the
            // standard selfie substitute (the old torch call was a silent no-op).
            .accessibilityLabel(flashOn ? L10n.text("Turn screen flash off") : L10n.text("Turn screen flash on"))
            Rectangle().fill(AppColors.borderSubtle).frame(width: 1, height: 18)
            Button {
                // Front-camera-only, matching the Dart original's stub flip
                // button — intentionally a no-op.
            } label: {
                LucideIcon(name: "refresh-ccw", size: 18)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(L10n.text("Switch camera"))
            .accessibilityHint(L10n.text("Not available in this version"))
        }
        .padding(.horizontal, AppSpacing.xs8)
        .frame(height: 40)
        .background(AppColors.bgSurface.opacity(0.85))
        .clipShape(Capsule())
    }

    private var lightingIndicator: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill((state == .ready && feedback?.isWellLit == true) ? AppColors.stateSuccess : AppColors.bgSurfaceElevated)
                    .frame(width: 4, height: 8 + CGFloat(i) * 4)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.xl24) {
            Text(hintText)
                .appFont(.bodyStrong)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.sm12)
                .padding(.vertical, AppSpacing.xs8)
                .background(hintBackground)
                .clipShape(Capsule())

            captureControl
        }
        .padding(.bottom, AppSpacing.xl24)
    }

    private var overlayState: CaptureGuideState {
        guard state == .ready, let feedback else { return .searching }
        return feedback.guideState
    }

    private var hintText: String {
        switch state {
        case .initializing: return NSLocalizedString("Starting camera…", comment: "")
        case .ready:
            guard let feedback else { return NSLocalizedString("Center your face in the oval", comment: "") }
            switch feedback.quality {
            case .tooDark: return NSLocalizedString("A bit dark — find better lighting", comment: "")
            case .tooBright: return NSLocalizedString("Too bright — reduce glare", comment: "")
            case .aligned: return NSLocalizedString("Hold still…", comment: "")
            case .searching: return feedback.hasFace ? NSLocalizedString("Line up your face with the oval", comment: "") : NSLocalizedString("Center your face in the oval", comment: "")
            }
        case .denied: return NSLocalizedString("Camera access denied", comment: "")
        case .restricted: return NSLocalizedString("Camera is restricted on this device — pick a photo instead", comment: "")
        case .unsupported: return NSLocalizedString("Pick a photo to analyze", comment: "")
        case .error: return errorMessage.map { String(format: NSLocalizedString("Camera error: %@", comment: ""), $0) } ?? NSLocalizedString("Camera error — using gallery instead", comment: "")
        }
    }

    private var hintBackground: Color {
        switch state {
        case .denied, .error: return AppColors.stateDanger.opacity(0.20)
        case .restricted: return AppColors.stateWarning.opacity(0.20)
        default: return AppColors.bgSurface.opacity(0.85)
        }
    }

    @ViewBuilder
    private var captureControl: some View {
        if state == .ready {
            HStack(alignment: .center) {
                galleryButton
                    .frame(width: 76)

                Spacer()

                shutterButton

                Spacer()

                // Keeps the shutter visually centered while the gallery
                // action remains easy to reach with the left thumb.
                Color.clear
                    .frame(width: 76, height: 62)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.xxl32)
        } else {
            VStack(spacing: AppSpacing.sm12) {
                PrimaryButton(
                    title: L10n.text("Choose from gallery"),
                    leadingIcon: "image",
                    isLoading: requestingPhotoAccess
                ) {
                    Task { await openGallery() }
                }

                if state == .denied {
                    PrimaryButton(title: L10n.text("Open camera settings"), variant: .outline, leadingIcon: "settings") {
                        openAppSettings()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xxl32)
        }
    }

    private var galleryButton: some View {
        Button {
            Haptics.selection()
            Task { await openGallery() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(AppColors.bgSurface.opacity(0.88))
                        .frame(width: 48, height: 48)
                    if requestingPhotoAccess {
                        ProgressView().tint(AppColors.textPrimary)
                    } else {
                        LucideIcon(name: "image", size: 21)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                Text(L10n.text("Gallery"))
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .disabled(capturing || requestingPhotoAccess)
        .accessibilityLabel(L10n.text("Choose photo from gallery"))
    }

    private var shutterButton: some View {
        Button {
            Task { await onShutter() }
        } label: {
            ZStack {
                Circle().fill(AppColors.accentGradient).frame(width: 76, height: 76)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5))
                    .shadow(color: AppColors.accentGlow, radius: 28)
                if capturing {
                    ProgressView().tint(.white)
                }
            }
            .scaleEffect(capturing ? 0.92 : 1)
            .animation(.easeOutCubic, value: capturing)
        }
        .disabled(capturing)
        .accessibilityLabel(state == .ready ? L10n.text("Take photo") : L10n.text("Choose photo"))
    }

    private func bootCamera() async {
        guard CaptureService.supportsLiveCamera else {
            state = .unsupported
            return
        }
        switch await service.requestCameraPermission() {
        case .granted:
            service.onInterruptionChanged = { interrupted in
                withAnimation(.easeOutCubic) { isInterrupted = interrupted }
            }
            service.onFeedback = { fb in handleFeedback(fb) }
            do {
                try await service.configureAndStart()
                state = .ready
            } catch {
                state = .error
                errorMessage = error.localizedDescription
            }
        case .notSupported:
            state = .unsupported
        case .restricted:
            state = .restricted
        case .permanentlyDenied, .denied:
            state = .denied
        }
    }

    private func onShutter(automatic: Bool = false) async {
        guard !capturing else { return }
        AppAnalytics.shared.track(.cameraAction, ["action": "shutter", "source": automatic ? "automatic" : "manual"])
        capturing = true
        Haptics.heavy()
        defer { capturing = false }

        guard state == .ready else { return }
        do {
            if flashOn {
                flashScreenOn()
                try? await Task.sleep(for: .milliseconds(180))
            }
            let input = try await service.takePicture()
            AppAnalytics.shared.track(.cameraAction, ["action": "photo_captured", "source": "camera"])
            if flashOn { flashScreenOff() }
            onCaptured(input)
        } catch {
            if flashOn { flashScreenOff() }
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    private func openGallery() async {
        guard !capturing, !requestingPhotoAccess else { return }
        AppAnalytics.shared.track(.cameraAction, ["action": "gallery_tapped"])
        requestingPhotoAccess = true
        alignedSince = nil
        defer { requestingPhotoAccess = false }

        let status = await requestPhotoLibraryAuthorization()
        AppAnalytics.shared.track(.cameraAction, ["action": "gallery_permission", "state": status.rawValue])
        guard !Task.isCancelled else { return }

        switch status {
        case .authorized, .limited:
            showPicker = true
        case .denied:
            galleryAlert = .accessDenied
        case .restricted:
            galleryAlert = .accessRestricted
        case .notDetermined:
            galleryAlert = .loadFailed(L10n.text("Photo permission could not be completed. Please try again."))
        @unknown default:
            galleryAlert = .loadFailed(L10n.text("Photo access is unavailable right now. Please try again."))
        }
    }

    private func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func flashScreenOn() {
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        withAnimation(.easeOut(duration: 0.1)) { screenFlash = true }
    }

    private func flashScreenOff() {
        UIScreen.main.brightness = savedBrightness
        withAnimation(.easeIn(duration: 0.15)) { screenFlash = false }
    }

    /// Drives the live overlay and auto-captures once the face has stayed
    /// aligned and well-lit for ~1.1s. The manual shutter still works.
    private func handleFeedback(_ fb: CaptureFeedback) {
        feedback = fb
        guard state == .ready, !capturing, !showPicker else { alignedSince = nil; return }
        if fb.quality == .aligned {
            let start = alignedSince ?? Date()
            alignedSince = start
            if Date().timeIntervalSince(start) > 1.1 {
                alignedSince = nil
                Task { await onShutter(automatic: true) }
            }
        } else {
            alignedSince = nil
        }
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                galleryAlert = .loadFailed(L10n.text("The selected photo couldn't be loaded. Please choose another one."))
                return
            }
            guard let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else {
                galleryAlert = .loadFailed(L10n.text("The selected file isn't a supported image. Please choose another photo."))
                return
            }
            let url = try ScanImageStore.write(jpegData)
            AppAnalytics.shared.track(.cameraAction, ["action": "photo_selected", "source": "gallery"])
            onCaptured(ScanInput(imagePath: url.path, capturedAt: Date(), source: .gallery))
        } catch {
            AppAnalytics.shared.track(.cameraAction, ["action": "gallery_load_failed", "error_code": (error as NSError).code])
            galleryAlert = .loadFailed(error.localizedDescription)
        }
    }
}

#Preview {
    CaptureScreen(onCancel: {}, onCaptured: { _ in })
}
