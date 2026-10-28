# Hugging Face tutorial video / 模型教學影片 / 模型教程视频

[Watch / 觀看 / 观看 (90 s, MP4)](Container-Desk-Hugging-Face.zh-Hant.mp4) · [Outline / 腳本大綱](OUTLINE.zh-Hant.md)

[![Tutorial preview](poster.png)](Container-Desk-Hugging-Face.zh-Hant.mp4)

Traditional Chinese narration and on-screen guidance. Optional subtitle files: [English](Container-Desk-Hugging-Face.en.srt), [繁體中文](Container-Desk-Hugging-Face.zh-Hant.srt), [简体中文](Container-Desk-Hugging-Face.zh-Hans.srt). English captions summarize each step.

繁體中文旁白與畫面解說，另附英文、繁體及簡體字幕。內容使用真實模型搜尋視窗截圖與動畫標註；下載、部署與相容性測試為操作解說，並非這次錄下的完整實作。135M 模型的文字推論與工具不相容結論來自 [既有驗證紀錄](../AI_VALIDATION.md)。

繁体中文旁白与画面说明，另附三语字幕。使用真实搜索窗口截图配合动画；下载、部署和兼容性测试为操作说明，并非本次连续录屏。

This tutorial was recorded for v0.3.0-preview; its closing download/version card is historical. Download the current 1.0.0 installer from the [release page](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v1.0.0). The VM + Package logo is included in 1.0.0. The historical v0.3.0-preview installer has not been replaced. This video does not claim Metal acceleration, MCP compatibility for the small test model, Apple notarization, or a newly completed live deployment. No model was downloaded to produce this video.

The video is documentation media, not a GitHub Release attachment. Releases remain DMG-only.

## Reproduce the video

The [composition](source/index.html), captured sheet images, narration WAVs and design notes are included. On a Mac with system fonts, Node.js 22+, Chrome and FFmpeg 7.1 available:

```sh
cd docs/video/source
npx hyperframes@0.8.192 check
npx hyperframes@0.8.192 render --output ../Container-Desk-Hugging-Face.zh-Hant.mp4 --fps 30 --quality high --workers 2 --strict
```

The composition loads GSAP 3.14.2 from jsDelivr. Narration was generated locally with the macOS Meijia voice; no voice model was downloaded. The included frames exclude host names, filesystem paths, and unrelated containers.

## Validation

Rendered output: 1920×1080, 30 fps, exactly 90 seconds, H.264 with AAC narration. Full-file decoding completed without errors. The final composition passed lint, runtime, layout, motion, contrast (37/37 text checks) and craft checks with no warnings; representative frames were inspected again from the actual MP4.

The standalone animation-map helper could not run because its optional `@hyperframes/producer` module was unavailable. The CLI motion check and sampled transition frames were used for this build. This is media validation, not a new container inference test.
