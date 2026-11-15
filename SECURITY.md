# Security policy

## Project status and supported versions

iHotkey is preparing `1.0.0-rc.2`, a prerelease candidate. There is no stable-release support commitment or guaranteed response time. Security fixes will target the current development line and latest candidate; historical builds should not be assumed to receive backports.

The macOS 12 deployment target and universal build configuration are not security certifications. See [known issues](docs/KNOWN_ISSUES.md) and the [historical compatibility report](docs/testing/legacy-compatibility-report.md) for verification limits. No completed Developer ID/notarization release is claimed.

## Reporting a vulnerability

**Do not disclose an unpatched vulnerability, exploit, private log or credential in a public issue, pull request or discussion.**

When the repository is hosted on GitHub:

1. Open the repository's **Security** tab.
2. If private vulnerability reporting is enabled, choose **Report a vulnerability** and submit a private advisory.
3. If that option is unavailable, do **not** post sensitive details publicly. You may open a minimal issue asking the maintainers to enable private reporting or provide a verified private contact, without including the vulnerability, exploit, affected private data or reproduction material. Wait for a verified private channel before sending those details.

This checkout does not define a security email address or a confirmed private-reporting endpoint. Do not guess a maintainer's address or send sensitive information to an unverified account. English and Chinese reports are welcome. There is no bug bounty or guaranteed remediation timeline.

A private report should include, where safe:

- Affected iHotkey version or commit, installation source and signing mode.
- Exact macOS version, CPU architecture and relevant permission/login-item state.
- A concise description of impact, preconditions and the expected security boundary.
- Minimal reproduction steps or a non-destructive proof of concept using synthetic data.
- Any mitigations you have identified and whether the issue is already public.

Do not include passwords, Apple ID credentials, notarization secrets, signing keys, full private configuration or unrelated personal data. Redact local usernames, paths and window/document information in screenshots and logs. Test only on systems you own or are authorized to assess; do not disrupt another user's apps or permissions.

## Permissions and local data

- **Global app shortcuts** use Carbon hotkey registration and do not require Accessibility or Input Monitoring. The shortcut recorder observes events locally while recording in the app; it is not a general keystroke logger.
- **Window snapping** requires Accessibility permission to inspect and modify window position and size. macOS grants this permission broadly: only grant it to an app copy and source you trust. iHotkey is not a sandboxed security boundary for the applications it controls.
- **Launch at login** is opt-in and registers a per-user login item or LaunchAgent. Login detection, approval handling and migration have [known limitations](docs/KNOWN_ISSUES.md).
- **Configuration** is a local JSON file at `~/Library/Application Support/iHotkey/config.json`. It can contain app names, bundle identifiers, local paths, shortcuts and preferences. It is not encrypted by iHotkey. Treat imports as configuration from a trusted source and review exports before sharing.
- **Diagnostics** may contain host details, artifact paths, signatures and test-window information. Review reports before uploading them.
- **Network behavior:** the app has no account system, telemetry or application-level network service. Development and release tools are separate; notarization communicates with Apple, and package/tool downloads may require network access.

## Build and signing safety

Local builds default to ad-hoc signing. Optional `SIGN_MODE=local` creates a self-signed identity in a dedicated user keychain through `scripts/setup-signing.sh`; it is not Apple Developer ID signing or notarization. Protect the private key, signing keychain and the `.signing-keychain-password` file under `~/Library/Application Support/iHotkey/`. Never upload these files or include them in a support archive.

A valid local signature does not establish the publisher's identity or imply Gatekeeper acceptance on another Mac. Official distribution requires independently verified Developer ID signing, notarization and stapling results for the exact final artifact.

Do not disable Gatekeeper or SIP to run iHotkey. Do not remove quarantine from an unverified download. If permissions become stale after rebuilding, use the targeted Accessibility recovery instructions in the [README](README.md#permissions-and-privacy), rather than resetting privacy settings for all applications.

If a credential or signing key is exposed, revoke or rotate it through its provider first; deleting a commit alone is not remediation. Share the incident scope only through a verified private channel.

## 中文说明

当前版本为 `1.0.0-rc.2` 候选版本，不提供响应时限或长期安全维护承诺。请勿在公开 Issue、PR 或讨论中发布未修复漏洞、利用代码、私密日志或凭据。

仓库在 GitHub 托管后，若已开启私密漏洞报告，请使用 **Security → Report a vulnerability**。若入口不存在，只能公开询问如何建立私密通道，**不要附带敏感细节**；确认维护者提供的私密渠道后再发送。项目未提供安全联系邮箱，请勿猜测邮箱或向未经核实的账号发送信息。

辅助功能权限能力较广，请只授权可信来源的应用。导出配置和诊断报告可能含有本地路径、应用列表及系统信息，分享前请脱敏。本机自签名不等于 Apple 公证；请勿关闭 Gatekeeper 或 SIP，也不要对未知下载移除隔离属性。
