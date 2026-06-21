**Comparison target**

- Source visual truth: `/tmp/brick-10x16.png` (the prior 10 × 16 control layout).
- Implementation screenshot: `/tmp/brick-controls.png`.
- Full-view comparison evidence: `/tmp/brick-controls-comparison.png`.
- Viewport: iPhone 17 Pro, iOS 26.0, 402 × 874 pt (1206 × 2622 px capture), light mode.
- State: active game. Tetromino and Next preview differ because they are dynamic gameplay state; comparison focuses on the fixed control order.

**Findings**

- No actionable P0, P1, P2, or P3 findings.

**Required fidelity surfaces**

- Fonts and typography: labels and icon controls remain readable and untruncated.
- Spacing and layout rhythm: button size, gap, alignment, and one-screen structure are unchanged.
- Colors and visual tokens: blue icon tint and selected speed styling are unchanged.
- Image quality and asset fidelity: no image assets changed.
- Copy and content: control order now matches the requested sequence: Left, Down, Right, Rotate.

**Focused-region comparison evidence**

- `/tmp/brick-controls-comparison.png` clearly shows the former `Left, Rotate, Right, Down` row beside the final `Left, Down, Right, Rotate` row.

**Open Questions**

- None.

**Implementation Checklist**

1. Completed: swap the rotation and hard-drop button positions.
2. Completed: build, install, and visually inspect the iPhone 17 Pro simulator result.

**Follow-up Polish**

- None.

**Patches made since the previous QA pass**

- Swapped the second and fourth bottom control buttons while preserving their action handlers.

final result: passed
