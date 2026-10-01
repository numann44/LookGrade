# Vision and scoring pipeline

The app performs facial-landmark detection using Apple Vision and computes its own display scores from those measurements. It does not upload the photo to an inference server or train a model in this repository.

## 1. Normalize the image

[`VisionAnalysisService`](../FaceRate/Features/Analysis/VisionAnalysisService.swift) loads a `UIImage` from the capture path. A JPEG may store its orientation in EXIF metadata while exposing a rotated raw `CGImage` buffer. When orientation is not `.up`, the service redraws the image upright with a scale-1 renderer before analysis.

This matters because the later formulas assume a consistent image: the chin has a larger Y coordinate than the forehead, and cheek rectangles are placed relative to an upright face box.

## 2. Detect and select the face

The service performs `VNDetectFaceLandmarksRequest` and selects the observation with the largest bounding-box area. An empty result raises `NoFaceDetectedError`. The app analyzes one face rather than aggregating a group portrait.

On Simulator, each supported compute stage is explicitly assigned a CPU device when one is available. Physical-device builds keep Vision's default device selection. That branch addresses Simulator inference support; it does not replace Vision with generated scores.

## 3. Convert coordinates

[`FaceMetrics+Vision`](../FaceRate/Features/Analysis/FaceMetrics+Vision.swift) translates Vision's normalized, bottom-left coordinate system into image pixels with a top-left origin. Landmark points are normalized inside the face bounding box, so the conversion incorporates both the face box and the full image dimensions.

For a normalized point `(u, v)` inside a face box `(bx, by, bw, bh)` and an image of width `W`, height `H`:

```text
x = (bx + u × bw) × W
y = (1 − (by + v × bh)) × H
```

The adapter collects eye contours, face contour, nose, lips, pupil/eye centroids, and pose. Vision's closed lip contours are split by their vertical midpoint to fit the scorer's upper/lower representation. Missing cheek points are handled by box-relative sampling. Some legacy fields are approximations/defaults rather than independent Vision predictions; the adapter should be consulted before interpreting a field as a measured probability.

`FaceMetrics` itself has no dependency on a `VNFaceObservation`. Synthetic geometry can therefore exercise the scoring math without image files, SDK inference, or camera hardware.

## 4. Sample cheek pixels

[`SkinSampler`](../FaceRate/Features/Analysis/SkinSampler.swift) creates an RGBA buffer and samples two square regions inferred from the face bounding box. The square side is based on 18% of face width and is clamped to 8–160 pixels. Sampling is strided to bound the work around approximately 400 pixels per region.

Luminance uses `0.299R + 0.587G + 0.114B`. The output includes normalized mean luminance, luminance standard deviation, mean RGB for each region, and saturation. Image rows are flipped during rendering to match the metric coordinate convention.

These are image statistics. They do not independently measure dermatological skin health or pigmentation, and lighting/white balance can change them.

## 5. Reject clearly unreadable inputs

The current quality checks reject:

| Signal | Threshold |
| --- | --- |
| Face bounding-box area | Below 0.045 of the image |
| Absolute yaw | Above 34 degrees |
| Absolute pitch | Above 30 degrees |
| Sample mean luminance | Below 0.12 or above 0.98 |

The service returns a localized retake instruction. These are deliberately lenient gates, not a calibrated confidence estimator. Passing them does not guarantee that all landmarks or image statistics are reliable.

## 6. Compute eight categories

[`FaceScorer`](../FaceRate/Features/Analysis/FaceScorer.swift) uses readable geometric rules, weighted components, and triangular quality functions around selected reference ratios.

| Category | Main inputs |
| --- | --- |
| Symmetry | Eye/mouth distance differences, mirrored contour error, pose penalty |
| Jawline | Chin angle and jaw-to-face width ratio; aspect-ratio fallback |
| Eyes | Contour width/balance, spacing, tilt, openness-related fields |
| Lips | Width/height ratios and upper/lower contour proportions |
| Nose | Width, length, bridge straightness; landmark fallback |
| Harmony | Facial segment, eye-width/spacing, and mouth/eye ratios |
| Skin | Cheek luminance variation and exposure |
| Tone | Sampled left/right color consistency and saturation; pose-based fallback |

The display transform is:

```text
categoryScore = roundToOneDecimal(5.5 + 4.0 × clamp(quality, 0, 1))
overallScore = roundToOneDecimal(sum(categoryScore × weight) / sum(weight))
```

Overall weights are symmetry 1.4, skin 1.2, jawline 1.1, eyes 1.2, lips 1.0, nose 1.0, tone 1.0, and harmony 1.3. The range 5.5–9.5 is an intentional display band. A score of 8.2 is not an 82% confidence or accuracy value.

Several branches use neutral or geometry-based fallbacks when a signal is absent. These should remain visible as limitations when evaluating the system. The unit tests check category coverage, score bounds, weighted aggregation, and relative response to changed geometry; they do not validate the reference proportions scientifically.

## 7. Assemble findings and descriptors

`FindingsCatalog` maps category scores into localized messages. `FaceProfile` estimates face shape from geometry and undertone from sampled colors. `PersonalizedTip` builds prioritized suggestions from the result. `potentialDelta` is a bounded formula based on distance from a 9.5 ceiling; it is not a measured prediction of future improvement.

The resulting `ScanResult` carries the original input, overall score, categories, findings, and optional descriptors. The coordinator publishes it only after checking cancellation.

## Evaluation boundary

There is no labeled benchmark, accuracy percentage, demographic validation, clinical study, or custom-model training pipeline included here. Useful future evaluation would measure repeatability across pose, exposure, camera distance, and device families, and separate landmark extraction reliability from the display heuristic. Screenshot scores and seeded chart values must never be presented as experimental evidence.
