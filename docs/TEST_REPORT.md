# Candidate test report / 測試結果表

Decision: **NOT READY**

Copy this template for each release candidate. Use PASS / FAIL / PENDING / BLOCKED. Never fill PASS without a matching observation and evidence file/link. Do not upload credentials, serial numbers, private workloads or unredacted logs.

## Candidate identity

| Field | Value |
| --- | --- |
| Source commit | Pending |
| App version/build | Pending |
| GitHub release URL | Pending |
| DMG SHA-256 | Pending |
| Mac model/chip/RAM | Pending |
| macOS version/build | Pending |
| Engine before → after | Pending |
| Clean install / upgrade / migration baseline | Pending |
| Tester and test date | Pending |
| Restore procedure verified | Pending |

## Results

| Gate | Status | Actual result / evidence | Defect / follow-up |
| --- | --- | --- | --- |
| G01 Build/artifact | PENDING | | |
| G02 Download/launch | PENDING | | |
| G03 Clean install | PENDING | | |
| G04 Host information | PENDING | | |
| G05 Creation controls | PENDING | | |
| G06 Lifecycle/data | PENDING | | |
| G07 Updates | PENDING | | |
| G08 Migration | PENDING | | |
| G09 Failure/recovery | PENDING | | |
| G10 Languages/visual | PENDING | | |
| G11 Accessibility | PENDING | | |
| G12 Stability | PENDING | | |
| G13 README/media | PENDING | | |
| G14 Public handoff | PENDING | | |

## Defects

| ID | Severity | Steps to reproduce | Expected / actual | Fix commit | Retest evidence |
| --- | --- | --- | --- | --- | --- |
| UI-001 | Major (suspected) | In 0.1.2 QA, open Create Container after filtering the container table and hiding the sidebar. | Window becomes unavailable; process sample stays in SwiftUI sheet layout. Restarting QA restores management. Reproduce on final candidate and fix before public release. | Pending | Pending |

## Decision record

- Required gates passed: 0/14 (this blank template is not an executed report).
- Open critical / major / minor defects: not yet assessed.
- Evidence reviewed by / date: pending.
- Decision: NOT READY. Keep private.
- GitHub visibility change result, if later eligible: not performed.
