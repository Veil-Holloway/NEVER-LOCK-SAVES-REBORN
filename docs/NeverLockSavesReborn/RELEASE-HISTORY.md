# Retained release history

The original full archives remain unchanged in the project Drive folder. This
preview packages current documentation instead of recursively duplicating old
logs. The exact preRC1 input is also preserved by the development workflow.

| Artifact | Drive file ID | SHA-256 |
|---|---|---|
| preRC1 Release Testing Preview | 1wdxuNuZHCfKFbkTJGtIzyAOL7kNygz5w | 8956ab9594ab3ef31e8c3dbb2efc5df7649fc5a7310455af31ca739f47868735 |
| alpha2 Backup Rotation | 17ZMBYjg0cY9CVT5Bk9TEy9FioyG5Z-St | 6eaf4cf5a3f19067f50df3bf199f0f47b3cfa3eb31d4ccb563adec4f7721dcf0 |
| alpha1 Guardian Foundations | 1FjkvLWkHLeRqI0FGlF87KtlQpZrsRQNl | 0d391d814c6a0594efd6efcc8d4e2cf3c54fcfe7e1f1f66a5ef2d359650c2be4 |

PreRC1 is the rollback target. Restore its config and preset bank together.
The user's “It works let's go” is recorded as working preRC1 feedback without
inventing game patch, framework versions, Windows coverage or per-case outcomes.

## preRC3 input and acceptance kit

The current runtime input is preRC2, Drive ID
`1_mF8frLL9597IRtQAUx0nmImS0yRyZZE`, 378,910 bytes, SHA-256
`a2682d98f7949e08ea0d42aa5f006481f662319a23aec8cc1a6b38580b7cfd5b`.
The separate preRC2 acceptance kit is ID
`1u2zkAhz-pz4YHrUEk9e9q4IhwfxV02m3`, SHA-256
`ea8f7d9e1a4e51092fa2ade5f3cf314dcae5595a3bad1bdeb0bbaa6c08a1e69c`.
It is a pinned preRC2 test tool, not a newer runtime ZIP. Current feedback is
user-reported working with unspecified fingerprint/cases/versions.

## preRC4 input

Fresh runtime input is preRC3, ID `1d3f6-kmx62iWSoPvKDiLvdlCFiUzNgV0`,
modified `2026-10-24T17:42:22.232Z`, 406,625 bytes, SHA-256
`ee0c241600e454fd690340dbc6e4c4dd58a3ee4255ff343a09901e4532a89229`.
All 222 input manifest entries and CRC matched. User reports working with
unspecified versions/case coverage; older full archives remain for rollback.

## 1.0.0-rc3 — Smart interaction queue routing

Separates Smart deferred admission from immediate checkpoint authorization in
all three save hooks; adds truthful custom blocked feedback when no request is
queued. Retains existing gates, modes and RC2 type correction. See CHANGELOG-RC3,
TESTING-RC3 and VALIDATION-REPORT-RC3. Runtime acceptance remains outstanding.
