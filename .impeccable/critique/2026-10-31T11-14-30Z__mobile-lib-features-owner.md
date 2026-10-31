---
target: owner app screens except Reports and WhatsApp
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:D:\\Cuts-Salon\\mobile\\lib\\features\\owner"
timestamp: 2026-10-31T11-14-30Z
slug: mobile-lib-features-owner
---
# Critique: owner app screens (excluding Reports, WhatsApp)

Method: dual-agent (A: design review · B: detector + code scan)

## Design health: 24/40 (Acceptable)
| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of system status | 3 | Bill total off-screen while picking services |
| 2 | Match system / real world | 2 | Raw PRESENT/LATE/REMOVED on laptop Team; star icon = Review QR |
| 3 | User control and freedom | 3 | Log Out unconfirmed |
| 4 | Consistency and standards | 1 | Two Team designs; pastel tiles; 26 font sizes, 22 radii, 647 hex literals |
| 5 | Error prevention | 3 | Discount slider imprecise |
| 6 | Recognition rather than recall | 2 | Four icon-only header buttons |
| 7 | Flexibility and efficiency | 2 | No service search in New Bill |
| 8 | Aesthetic and minimalist | 2 | Home repeats bills-today 3x |
| 9 | Error recovery | 3 | Plain snackbars, retry |
| 10 | Help and documentation | 3 | Good inline notes |

## Priority issues
1. [P1] Pastel rainbow icon tiles remain (Home Today grid, Clients stats, client page, staff profile, expenses); theme.dart accent* soft pairs. -> quieter
2. [P1] New Bill does not scale: flat service cards, no search/categories, radio for multi-select, total + Create bill below fold, 0-25% slider. -> layout
3. [P1] Laptop Team screen is a legacy design with raw status codes (customers_employees:2488) and 'Absent' for no record (:2854). -> adapt
4. [P2] Home repeats itself; decorative dash; #FAFAFA background. -> distill
5. [P2] Icon-only header actions (QR, star, bell, gear); 11 of 24 IconButtons lack tooltips. -> clarify
6. [P2] Design system bypassed: billing 0 DsCard / 31 hand-rolled cards, 647 hex literals with a second slate palette, 26 font sizes, gradient save buttons, leftover indigo. -> polish
7. [P2] Tiny text (9-10px) and tap targets (26-32px); textMuted 2.6:1 contrast. -> harden
8. [P3] Destructive actions too prominent (Remove from team/menu, red Log Out). -> clarify
