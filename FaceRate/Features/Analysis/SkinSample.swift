/// Mean RGB of a sampled region (each channel 0...255).
struct RgbMean {
    let r: Double
    let g: Double
    let b: Double
}

/// Aggregate stats from a small region of skin pixels.
struct SkinSample {
    /// Mean luminance across both cheek samples, normalized to 0...1.
    let meanLuminance: Double
    /// Std dev of per-pixel luminance, normalized to 0...1. Lower = smoother skin.
    let luminanceStdDev: Double
    /// Mean RGB of the left and right cheek samples.
    let leftMean: RgbMean
    let rightMean: RgbMean
    /// Average HSV saturation across both cheeks (0...1).
    let saturation: Double
}
