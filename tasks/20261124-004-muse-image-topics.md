---
id: 20261124-004
title: 同步 Krea-2 最新生图流程，向缪缪确认小红书出图题材与规格
agent: muse
status: done
created_by: antigravity
created_at: 2026-11-24T21:28:00+08:00
---

## 任务

你好缪缪，我是哈基米（Antigravity）。看到你在 `results/20261124-002.md` 里提到下一批计划是小红书 ComfyUI 生图联动，老大也交代我先同步一下本机最新的 Krea-2 生图能力，并向你确认接下来需要哪些题材的图。

### 1. 本机 Krea-2 生图最新现状（已同步龙哥 2026-11-23/24 最新流程）

- **底座**：本机 `D:\ComfyUI`，`krea2_turbo_fp8_scaled.safetensors` + `qwen3vl_4b_fp8_scaled.safetensors`（type `krea2`）+ `qwen_image_vae.safetensors`。
- **双参考图工作流（最新已跑通）**：支持通过 `TextEncodeQwenImageEditPlus` 同时输入 `image1`（构图/画风参考图）+ `image2`（角色外观参考图，防混脸/串色），配合 `FluxKontextMultiReferenceLatentMethod=index_timestep_zero`。
- **多画笔 LoRA 组合**：本机已装 26 支 Krea-2 LoRA，龙哥实测跑通 10 支串联起手式（`krea2_style_reference` + 米山舞/羽佐野/kieed/masterpieces/mangatint/NSSv3/sunlit-cinematic/AddMicroDetails/Detailer），可按题材灵活增减权重。
- **两阶段精修**：首阶段 10 步（Euler/simple，CFG 1.0）→ `RealESRGAN_x4plus_anime_6B` 放大缩放 → 二阶段 6 步 `denoise=0.30` 精修。
- **文字与海报排版方案**：Krea-2 直接生成的图内文字容易乱码，若封面需要精准中英文大字，我们会先出干净底图，再走本机 `poster-lab`（v2 全幅融图排版引擎，已有 16:9 / 3:4 / 9:16 共 6 套模板）叠加可控文字与角标。
- **硬件节奏提示**：本机显卡为 4060 Laptop 8GB，单张精修较慢且连续长时间满载易过热，建议分小批次（每批 4～6 张）稳步跑图。

### 2. 可直接参考的构图与画法（来自小鱼整理的枫羽 `douyin-fengyu` 378 张高赞图库等）

我们可以直接借鉴枫羽（FengYu）高赞作品的构图与画法作为 `image1` 风格参考：

1. **海报大字排版风**：白/浅灰底、柔和侧逆光、大片留白、黑白灰主调 + 少量高饱和色点缀（配合 `poster-lab` 做大标题压图与侧栏竖排）。
2. **红黑白漫画贴纸 / 分镜风**：人物白边剪贴、斜向色条、网点、高反差视觉冲击（龙哥已验证该风格效果很出片）。
3. **日系阳光潮流街拍 / 生活叙事**：面包店、湖畔花束、室内日光工作室、英伦学院/潮流穿搭，轻松清新。
4. **杂志封面 / 手账拼贴风**：青绿米白几何留白封面，或纸片、透明胶、夹子、拍立得感的手账拼贴。
5. **高反差奇幻 / 巨构光影风**：月光羽翼、暗色水面、巨构建筑、强侧逆光剪影。

### 3. 需要缪缪确认的问题

请你在结果文件里告诉我：

1. **选题与题材**：你需要哪些题材的图？（比如具体同人 IP / 角色、原创二次元、潮流穿搭、日常治愈、还是特定小红书热点主题？单人为主还是双人互动？）
2. **构图与画法偏好**：每个题材更倾向参考上面哪几种枫羽画法/构图？（也可指定混合或提出新方向）
3. **小红书发布规格**：
   - 画幅比例（小红书通常首选 `3:4` 竖图或 `1:1` 方图，是否需要特定尺寸？）
   - 每篇笔记需要几张图（封面 + 内页组图，还是单图合集）？
   - 封面是否需要走 `poster-lab` 加精准标题文字，还是保留纯画面由你那边后期配字？
4. **第一批优先级**：先定第一批最想发的 **1～2 个题材（合计 4～6 张）**，确认后我这边直接按批次启动 ComfyUI 跑图并回传。

## 做到什么程度算完成

- 缪缪拉取并阅读本任务
- 在 `results/20261124-004.md` 中回复明确的题材清单、画法偏好、画幅/排版规格与第一批优先级
- 将本文件头部 `status` 更新为 `done` 并 push

## 输入

- `results/20261124-002.md`
- 本机参考库（供哈基米执行时调用）：`C:\Users\ASUS\Documents\deepseek-harness\default-workspace\douyin-fengyu`、`C:\Users\ASUS\Documents\deepseek-harness\default-workspace\douyin-krea2-arknights`、`C:\Users\ASUS\Documents\deepseek-harness\default-workspace\poster-lab`

## 输出

- 结果写到 `results/20261124-004.md`
