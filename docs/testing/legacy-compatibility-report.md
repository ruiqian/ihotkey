# KeyPilot macOS 兼容性测试报告

## 结论边界

本轮实际运行环境仅有 **macOS 26.6.2 / Apple Silicon arm64**。Monterey 12、Ventura 13、Sonoma 14、Sequoia 15 仅做了源码可用性/部署目标检查，**没有运行对应操作系统，不等于实测通过**。Intel 二进制存在且类型检查通过，但本机不能执行 x86_64 程序（Bad CPU type in executable），未安装或变更 Rosetta。

测试针对已安装的 `KeyPilot.app`，与 `dist/KeyPilot.app` 二进制 SHA-256 一致：
`54b88e77f1253142050972c9e360b04fa132b30ed4f73bc095e1843a9ba68099`

源码基线：`95fbcbc`。本轮仅新增测试脚本，没有修改/重装应用，没有重置辅助功能授权，没有切换登录项。

## 系统矩阵

| macOS | arm64 源码部署目标检查 | x86_64 源码部署目标检查 | 运行结果 |
|---|---|---|---|
| 12 Monterey（目标 12.0） | PASS | PASS | 未测试：缺少旧系统 |
| 13 Ventura（目标 13.0） | PASS | PASS | 未测试：缺少旧系统 |
| 14 Sonoma（目标 14.0） | PASS | PASS | 未测试：缺少旧系统 |
| 15 Sequoia（目标 15.0） | PASS | PASS | 未测试：缺少旧系统 |
| 26 Tahoe（目标 26.0） | PASS | PASS | 26.6.2 arm64 本机回归通过；Intel 未测试 |

**方法限制**：所有源码检查使用当前 macOS 26.5 SDK 与 Swift 6.3.3，分别 `swiftc -target <arch>-apple-macosx<version> -typecheck`，不是安装/模拟旧 SDK，也不是让新系统伪装成旧系统。此方法能发现未做可用性保护的新 API，不能覆盖旧版 SwiftUI 渲染、登录项策略、TCC、窗口行为或系统补丁差异。

## 本轮实际结果

### 自动化检查

- 综合脚本：37 项 PASS、0 项 FAIL、1 项 BLOCKED。这里的 37 是脚本检查项数量，包含环境采集和类型检查，**不是 37 个已覆盖功能**。
- 单元测试：26/26，通过。包括几何、坐标变换、间距、循环布局、配置兼容解码、快捷键冲突等。
- Carbon 系统快捷键：20/20 注册成功；内部重复拒绝、合成 Carbon 热键事件分发通过。此项不是实体键盘或 CGEvent 注入的端到端测试。
- 主窗口/状态栏：打开窗口、Dock 图标显示、关闭隐藏、最小化隐藏且非 Dock 最小化、重新打开、状态栏菜单及分屏条目通过。
- 分屏：通过 LaunchServices 启动，以 KeyPilot 自己身份确认辅助功能授权有效；在真实 TextEdit 窗口执行左半屏、右半屏、左上角、最大化、居中、恢复六个动作，均读取实际窗口几何进行验证；恢复动作回到原始位置与尺寸。
- 本轮命令行 basic 自测中 `Accessibility trusted: false` 不代表 KeyPilot 授权失效：直接从终端启动时 TCC 归属与 LaunchServices 不同。真实分屏报告中的 `PASS AXIsProcessTrusted` 才是应用身份的证据。
- 配置文件测试前后哈希一致；未改用户快捷键配置。
- 额外验证免开发工具测试脚本：4 项 PASS、0 项 FAIL、1 项 BLOCKED（Intel 程序无法运行）；原始日志单独保存。

### 包与签名

- 通用二进制包含 arm64、x86_64。
- 两个架构的 Mach-O `minos` 均为 12.0；Info.plist `LSMinimumSystemVersion` 为 12.0。
- ServiceManagement 为 weak-link；注意：框架弱链接本身不是充分条件，调用方仍须 `#available(macOS 13, *)` 保护。
- 本机 `codesign --verify --strict` 通过；这不等于 Apple Developer ID、公证或陌生机器上的 Gatekeeper 验证通过。
- `hdiutil verify dist/KeyPilot-1.0.0.dmg` 校验和通过。

## 警告与待测项目

- macOS 14 以上目标检查对 SwiftUI `onChange(of:perform:)` 提示 deprecated。它目前仍可用，保留这个调用是为了兼容 macOS 12；不是编译失败，也不是已发现的运行错误。
- Monterey 12 的 LaunchAgent 分支未在 Monterey 实测，不能用 Tahoe 上 SMAppService 的行为代替。
- 本轮没有开关登录项或重启，因此本轮不能证明开机启动、登录静默运行通过。
- 实际 Intel 硬件、Rosetta 转译运行未覆盖；不能以 `x86_64` slice 存在宣称 Intel 已验证。
- 多显示器、屏幕缩放/排列、全屏窗口、Stage Manager、Spaces、Dock 位置等仍需真实场景验证。
- Electron/Chromium 应用、固定最小尺寸窗口、不可缩放窗口未实测。
- 首次安装、旧版升级与权限迁移、干净用户环境、Gatekeeper、公证未纳入本轮。

## 可重复执行

### 在开发机执行完整检查

```bash
cd <legacy-project>
python3 scripts/compatibility-test.py --runtime --snap
```

输出目录自动生成，包含 JSON 汇总、完整命令、退出码、日志、二进制 hash。运行测试会短暂关闭/重开 KeyPilot、激活 TextEdit 测试文档。不会重置权限、切换自启或安装 Rosetta。

### 在任意已安装 KeyPilot 的 Mac 执行（不需 Xcode / Python）

```bash
bash test-on-mac.sh KeyPilot.app
```

将创建 `~/Desktop/KeyPilot-Compatibility-时间戳/`。辅助功能未授权时分屏记录 BLOCKED，不会伪报 PASS。将报告目录回传即可对齐真实 OS 版本及相同构建。

测试脚本仅覆盖主窗口/菜单、Carbon 热键管线、应用路径解析与六种分屏动作，并非全功能验收。

### 各真实 OS 额外人工验收

| 场景 | 操作与通过条件 |
|---|---|
| 初装与授权 | 拖入 Applications；正常打开；未授权有清晰提示；授权后提示消失、分屏有效 |
| 应用快捷键 | 设置后按实体键盘，应用打开/聚焦；显示隐藏模式再按隐藏；录制时不误触发 |
| 关闭/最小化 | 主窗口关闭/黄灯最小化后不退出，菜单栏可重新打开 |
| 登录启动 | 打开自启，注销/登录；菜单栏驻留且无窗口弹出；关闭自启后不再启动 |
| 12 → 13+ 迁移 | 升级系统后检查旧 LaunchAgent 与新 SMAppService 状态，不重复启动 |
| 多屏与尺寸 | 各屏半屏/第三屏等动作；左右/上下排列；屏幕缩放；Dock 在左右下方 |
| 常用应用 | Safari、TextEdit、Finder、Terminal、VS Code；对不可缩放和全屏窗口不崩溃 |
| 权限/更新 | 签名一致升级后仍能分屏；撤销授权后显示正确提示；再授权恢复 |
| 语言/外观 | 中文/英文、浅色/深色、最小窗口尺寸下文字可读、无重要控件截断 |

## 独立审查补充（已由主流程复核）

本轮没有修改应用源码，以下为已发现的代码缺陷/兼容性风险，不等于已在旧系统复现。发布前建议修复并回归：

1. **登录启动事件识别错误**：`LaunchAtLogin.swift:85–87` 把 `keyAELaunchedAsLogInItem` 与另一个参数的枚举值比较；SDK `AERegistry.h:1045` 明确说明它是事件中“存在即表示登录启动”的 keyword。现有 `systemUptime < 180` 兜底会使延迟登录或早期手动打开的行为不准确。
2. **Monterey → Ventura+ 登录项迁移缺失**：`LaunchAtLogin.swift:21–29,60–63` 在新系统只读 SMAppService、跳过旧 LaunchAgent；旧 plist 可能仍存在，而 UI 显示关闭。是否持续自启须真实升级环境验证。
3. **待审批登录项缺少取消/跳转操作**：`GeneralView.swift:9–12` 只把 `.enabled` 当开启，`.requiresApproval` 显示关闭；用户再次点击会尝试注册，而不是取消待审批请求。`openLoginItemsSettings()` 已实现但没有 UI 调用入口。
4. **恢复失败仍返回成功**：`WindowManager.swift:74–79` 在恢复时先丢弃记录、忽略 `setFrame` 错误并返回 `.moved`；当前实际窗口恢复成功，并不排除权限变化或拒绝移动窗口时误报成功。
5. **Monterey 授权文案不准确**：`AccessibilityHelpBanner.swift` 固定写“系统设置 › 隐私与安全性”，12 应为“系统偏好设置 › 安全性与隐私 › 隐私”。

此外，默认 CI 仅有 macOS 14 runner，且没有走正式 Developer ID 公证发布脚本。不能认为 CI 产物已验证跨系统运行、或任意机器升级后均保留授权。

## 下一步真正完成跨版本测试的前提

需要 macOS 12、13、14、15 的可登录桌面环境（本地虚拟机或备用 Mac）和 Intel Mac。当前未发现已安装的虚拟化测试工具，未擅自下载系统镜像或安装 Rosetta；macOS 界面与 AX/TCC 不可用 Linux/Docker 代替。取得环境后，在每个系统运行同一安装包和免开发工具脚本，并进行上述手动场景，才能升级为“对应版本已实测”。
