# KeySoil（按键沃土）

> 键盘播种，成熟收获 —— 一款打字即耕耘的桌面陪伴应用。

KeySoil 是一款跨平台桌面陪伴应用。你在键盘上正常打字时，每一次按键都会驱动虚拟像素农场的生长。农场以**键盘配列**呈现在透明悬浮窗口中——每个物理按键就是一块土壤，常用键作物茂盛，冷门键维持荒芜。

## 特色

- ⌨️ **键盘即农场**：每个按键就是一块土壤。按下哪个键 → 哪块地就获得浇灌。
- 🌾 **四种作物**：小麦、番茄、玉米、草莓——每种 4 个视觉生长阶段。
- 🐕 **宠物伙伴**：领养小猫小狗，它们会在农场巡逻并自动帮你收获成熟作物。
- 🪟 **透明悬浮窗**：始终置顶、鼠标穿透，不影响正常工作。
- 🔒 **隐私优先**：仅处理物理按键码，绝不记录你输入的内容。
- 🌍 **跨平台**：支持 Windows、macOS、Linux。

## 技术栈

Electron · TypeScript · Canvas 2D · pnpm · uiohook-napi · electron-vite · electron-builder

## 快速开始

### 环境要求

- [Node.js](https://nodejs.org/) 20+
- [pnpm](https://pnpm.io/) 9+

### 开发

```bash
pnpm install
pnpm assets:build       # 处理美术资源
pnpm dev                # 启动开发服务器（支持热更新）
```

### 构建与打包

```bash
pnpm build              # 生产构建
pnpm package:mac        # 打包 macOS .dmg
pnpm package:win        # 打包 Windows .exe
pnpm package:linux      # 打包 Linux .AppImage
```

### 测试

```bash
pnpm test:unit          # 单元测试
pnpm test:integration   # 集成测试
pnpm test:e2e           # 端到端测试
pnpm test:all           # 全部测试
```

## 项目结构

详见 [CLAUDE.md](CLAUDE.md) 获取详细项目文档，[docs/design.md](docs/design.md) 查看完整实现计划。

## 许可证

[MIT](LICENSE)
