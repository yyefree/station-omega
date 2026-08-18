[English](README.md) | **中文**

# Station Omega（空间站 Omega）

一款完全程序化生成的科幻 FPS 地牢探索游戏，基于 **Godot 4.7** 引擎。零外部资源 — 所有纹理、音效和视觉效果全部由代码实时生成。

[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-blue)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-99%2F99%20passing-brightgreen)](#测试)

## 故事背景

深空研究站 **Omega** 发生了灾难性的维度裂缝突破事件。外星生物已经淹没了下层甲板。你是最后幸存的安全操作员 — 穿越空间站，收集能源核心，到达桥楼启动自毁程序，阻止污染扩散到地球。

## 特性

- **2 个完整关卡** — 工程甲板（工业风格、紧急照明）和丛林密境（外星侵蚀的废墟）
- **3 种武器** — 左轮手枪、突击步枪、霰弹枪，含枪口闪光特效
- **全程序化生成** — 16 种纹理类型、31 种音效，全部运行时生成（无图片/音频文件）
- **科幻氛围** — 红色紧急顶灯、冷蓝色工作灯、体积雾、空间站天花板
- **敌人 AI** — 飞行无人机和地面安保机器人，具备寻路和战斗能力
- **谜题机制** — 电源开关、压力板、锁定的气密闸门
- **完整 HUD** — 生命值、弹药、得分、计时器、目标追踪、武器显示
- **自动演示模式** — 菜单界面 5 秒后 AI 自动游玩
- **99 项自动化测试** — 涵盖移动、战斗、谜题、关卡切换的回归测试

## 操作说明

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标 | 视角 |
| 鼠标左键 | 射击 |
| R | 换弹 |
| 1 / 2 / 3 | 切换武器 |
| E | 交互 |
| 空格 | 跳跃 |
| Shift | 疾跑 |
| Ctrl / C | 蹲伏 |
| Esc | 暂停 |

## 快速开始

### 方式一：下载运行

1. 下载安装 [Godot 4.7](https://godotengine.org/download)
2. 克隆本仓库：
   ```
   git clone https://github.com/yyefree/station-omega.git
   ```
3. 打开 Godot → 导入 → 选择 `project.godot` 文件
4. 按 **F5** 开始游戏

### 方式二：命令行启动

```bash
# 第一关（工程甲板）
path/to/Godot --path . -- --level 1

# 第二关（丛林密境）
path/to/Godot --path . -- --level 2

# 自动演示模式
path/to/Godot --path . -- --level 1 --demo

# 跳过菜单直接开始
path/to/Godot --path . -- --level 1 --autostart

# 全屏模式
path/to/Godot --path . -- --fullscreen
```

## 项目结构

```
station-omega/
├── project.godot          # Godot 项目配置
├── scenes/
│   └── main.tscn          # 主场景（极简 — 所有内容由代码构建）
├── scripts/
│   ├── main.gd            # 游戏循环、状态机、场景构建
│   ├── player.gd          # FPS 控制器、武器、相机
│   ├── enemy.gd           # 敌人 AI、战斗、死亡
│   ├── hud.gd             # 完整 UI：菜单、HUD、设置
│   ├── fx.gd              # 粒子特效、枪口闪光、浮动文字
│   ├── texgen.gd          # 16 种程序化纹理生成器（512px）
│   ├── audio_manager.gd   # 31 种程序化 PCM 音效
│   ├── weapon.gd          # 武器数据容器
│   ├── artifact.gd        # 可收集的能源核心
│   ├── pickup.gd          # 生命和弹药拾取物
│   ├── ruin_door.gd       # 动画门（气密闸门）
│   ├── ruin_switch.gd     # 拉杆和压力板
│   └── target.gd          # 靶子练习（未使用）
├── tests/
│   ├── run_all.gd         # 67 项回归测试（第一关）
│   └── run_level2.gd      # 32 项回归测试（第二关）
├── .gitignore
├── LICENSE
├── README.md
└── README.zh-CN.md
```

## 测试

从命令行运行自动化测试：

```bash
# 第一关测试（67 项检查）
path/to/Godot --headless --path . --script "res://tests/run_all.gd"

# 第二关测试（32 项检查）
path/to/Godot --headless --path . --script "res://tests/run_level2.gd"
```

测试覆盖：移动、跳跃、蹲伏、武器切换、射击、敌人战斗、文物收集、谜题机制、关卡切换和 UI 状态。

## 技术亮点

- **程序化纹理**：ground、stone、brick、wood、metal、steel、polymer、plastic、carbon、grass、leaf、vine、gunmetal、knurl — 全部通过多层噪声和混合生成
- **程序化音频**：枪声、爆炸、脚步、环境风声、UI 点击 — 全部合成 PCM 波形
- **空间站照明**：红色紧急 Omni+SpotLight 灯组、冷蓝色工作灯、体积雾注入
- **GLSL 着色器**：多层波浪焦散水面、动态天花板面板、天空大气
- **性能优化**：纹理首次生成后缓存，前向渲染器 + FXAA + MSAA

## 许可证

本项目采用 MIT 许可证 — 详见 [LICENSE](LICENSE) 文件。
