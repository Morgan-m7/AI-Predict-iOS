# DouyinEQ —— 抖音 AI 高情商回复越狱插件

与微信端 HighEQReply 同一套人设（接住情绪 → 共鸣 → 引导型恋人 → 成熟稳重 → 去AI化），跑在抖音私信里。

## 与微信端的关键区别：版本免疫设计

抖音的 IM 私有类名没有微信那么公开稳定、且随版本变化快，所以本项目**不依赖任何抖音私有类**：

| 环节 | 微信端做法 | 抖音端做法 |
|---|---|---|
| 悬浮球注入 | hook `BaseMsgContentViewController` | 运行时枚举全部类，匹配 `*ChatViewController*` / `*ConversationViewController*`，再用"有消息列表视图"启发式过滤误匹配 |
| 上下文获取 | 钩消息回调入库 | **直接扫描聊天 UI**：递归收集 Table/Collection 单元格，按气泡左右位置判断对方/自己（左侧=对方，右侧=自己，居中的系统提示/时间戳跳过） |
| 输入框填充 | `onOperatePlainText:` | 找 UITextView 直接填 |
| 长期记忆 | 每个会话一份 | 单文件 `memories/douyin_chat.txt`（共用记忆目录） |

代价：上下文只能取**当前屏幕可见**的消息（约最近 10 条），往上翻过的看不到。这是版本免疫换来的取舍，实际够用。

## 共享资源（两插件互通）

- 人设：两插件都读 `/var/mobile/Library/HighEQReply/persona.txt`，改一份两边同时生效
- 记忆：同一目录，微信按对方 ID 分文件，抖音统一 `douyin_chat.txt`
- API 配置各自独立：`/var/mobile/Library/Preferences/com.douyineq.reply.plist`（长按悬浮球可设置）

## 编译与安装

**方式 A：GitHub 云端打包（推荐，本机无需任何环境）**

已内置 CI 配置 `.github/workflows/build.yml`，同时产出 rootless + rootful 两个 deb：

1. GitHub 新建仓库（Private 即可）
2. 把整个 `DouyinEQ/` 文件夹推上去（**包含 `.github` 隐藏文件夹**）：
   ```bash
   cd DouyinEQ
   git init && git add -A && git commit -m "init"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/DouyinEQ.git
   git push -u origin main
   ```
   本机推不上去：仓库页 → Add file → Upload files，直接**拖拽上传**整个文件夹。
3. Actions 标签看构建（首次 5-10 分钟）→ 完成后在该次运行底部 Artifacts 下载对应版本
4. Filza 打开 deb 点 Install → 重启抖音

**方式 B：本地 Theos**

```bash
THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1
# 产物 packages/com.douyineq.reply_1.0.0_iphoneos-arm64.deb
dpkg -i xxx.deb; killall Aweme
```

## 使用

1. 打开任意抖音私信聊天页 → 右下角 ✦ 悬浮球（隐蔽模式下改为**标题栏三连点**）
2. 点一下 = 扫描当前可见消息 → 生成建议回复 → 复制 / 填入输入框 / 重写 / 记个备忘

## 防封要点（同微信）

- **Shadow 装不上也没关系**：本插件内置轻量反检测（默认开启）——hook 文件系统检查隐藏 Cydia/MobileSubstrate/ssh/`/var/jb` 等越狱路径、hook fork 检测、hook `canOpenURL` 拦截越狱 App scheme。设置弹窗里可开关
- Shadow 官方源 `repo.akusio.fi`；rootless 越狱必须装带 `(Rootless)` 标记的版本，装不上大概率是架构不匹配；备选 Choicy / Liberty Lite
- 固定 IP，别频繁换代理/节点——掉登录九成是这个
- 不自动发送消息（本插件也只填输入框，不代发）
- 不营销、不群发、不批量私信——**营销行为才是封号主因**

## 局限

- 只支持抖音国内版（`com.ss.iphone.ugc.Aweme`），国际版 TikTok 是另一个 Bundle ID，需要时加一行过滤器即可
- 悬浮球没出现说明类名匹配没命中，开启日志（Console.app 搜 `DouyinEQ`）看命中数量，告诉我类名我帮你调匹配模式
- 语音/图片消息不进上下文
