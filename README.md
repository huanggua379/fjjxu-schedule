# 课本 (KeBen)

> 蓝白未来科技风的校园课表 + 成绩助手 · Flutter + Material 3 · 面向福建江夏学院正方教务系统

「课本」通过学号登录学校教务系统（金智统一认证 SSO + 正方 jwglxt），自动拉取真实课表与成绩，提供今日课程、周课表矩阵、课程隐藏、上课提醒、成绩提醒、后台自动同步与离线缓存。**不新建任何后端服务**，全部逻辑在端上完成，数据只存储在本机。

---

## 目录

- [功能清单](#功能清单)
- [环境准备](#环境准备)
- [构建与安装](#构建与安装)
- [项目结构](#项目结构)
- [架构设计](#架构设计)
- [接口说明（逆向自正方教务系统）](#接口说明逆向自正方教务系统)
- [数据模型](#数据模型)
- [数据库表结构](#数据库表结构)
- [安全与合规](#安全与合规)
- [测试结果](#测试结果)
- [已知限制](#已知限制)

---

## 功能清单

| 模块 | 功能 | 说明 |
|------|------|------|
| 登录 | 学号 + 密码登录教务系统 | 金智 SSO，AES/CBC 加密口令，动态令牌；凭证仅存安全存储 |
| 登录 | 会话保持与静默重登 | Cookie 持久化；会话过期时用安全存储凭证自动重登 |
| 首页 | 今日课程 | 按当前周过滤 + 节次排序 |
| 首页 | 当前 / 下一节课状态 | 正在上课（呼吸灯）/ 距下节课倒计时 |
| 首页 | 下拉同步 | 显示课表变更（新增/取消/教室教师时间调整）与新成绩数 |
| 课表 | 周课表矩阵 | 网格行数按当周实际最大节次动态扩展（上限 100），课程块按节次跨行 |
| 课表 | 实践课/未排入区 | 无固定星期节次的排课（如部分实验、实践课）单列展示，不会凭空消失 |
| 课表 | 切换周次 | 左右横滑、上/下周按钮、周次选择器；顶栏显示本周日期区间与月份 |
| 课表 | 高亮今天 / 当前周 | 今日列与日期条高亮 |
| 课表 | 课程详情 | 点击查看时间、周次、教室、教师、学分、考核方式 |
| 隐藏 | 隐藏整门课程 | 本机隐藏，**不删除教务系统数据**，重新同步后仍保持 |
| 隐藏 | 隐藏单次课程 | 只隐藏某一周的某一次排课 |
| 隐藏 | 恢复管理 | 独立页面查看并恢复隐藏项，支持「全部恢复」 |
| 成绩 | 自动查询与历史 | 拉取全部学期成绩，按学期分组 |
| 成绩 | 统计概览 | 加权平均绩点（用校方每门 `jd`×学分）、平均分、已修学分 |
| 成绩 | 绩点科目可选 | 可勾选纳入绩点统计的科目，排除项本机保存 |
| 成绩 | 新成绩提醒 | 仅对「新出现」的成绩提醒一次，去重、可关闭、通知不含分数 |
| 成绩 | 成绩详情 | **仅展示校方真实提供的字段**；构成明细为空时明确说明 |
| 提醒 | 上课提醒 | 通知 / 闹钟 / 两者，可配置提前 5/10/15/20/30/45/60/自定义分钟 |
| 提醒 | 每段只提醒首节 | 上午/下午/晚上每段只对第一节课提醒，同段后续课不再重复打扰 |
| 提醒 | 作息时间可配置 | 设置页可逐节校准上下课钟表时间，保存后自动重排提醒 |
| 提醒 | 每门课单独设置 | 可对单门课程覆盖提醒方式与提前时间（数据层已支持） |
| 提醒 | 去重 | 稳定 ID（entryId+周次）派生，先全清再重建，重启/同步不重复 |
| 同步 | 后台自动同步 | WorkManager 周期任务（最小 15 分钟），进程被杀仍可唤醒 |
| 同步 | 频率可配 | 15/30/60/180/360/720 分钟或仅手动 |
| 离线 | 本地缓存 | 课表/成绩落 SQLite，断网可查看上次数据 |
| 外观 | 浅色 / 深色 / 跟随系统 | Material 3 蓝白主题 |
| 数据 | 清除本地数据 | 一键清缓存与本地设置，不影响教务系统、不退出登录 |

---

## 环境准备

- Flutter 3.47.4 / Dart 3.13.3
- Android SDK（platform 36 + build-tools 36）、JDK 17
- 手机 Android 6.0（minSdk 23）及以上
- 能访问 `dl.google.com` / `repo.maven.apache.org` 的网络

装好后运行 `flutter doctor` 检查环境即可。

---

## 构建与安装

```bash
cd keben
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`（当前用 debug 签名，见「已知限制」）。

装到手机：把这个 apk 传到手机点开安装；或连电脑执行 `adb install -r build/app/outputs/flutter-apk/app-release.apk`。

首次打开：输学号密码登录 → 给通知权限 → 自动同步课表和成绩。

---

## 项目结构

```
keben/
├─ android/                      # Android 工程（清单权限、图标、Gradle 配置）
│  └─ app/src/main/AndroidManifest.xml
├─ assets/images/                # 应用图标源图
├─ lib/
│  ├─ main.dart                  # 入口：初始化 + 注册后台任务 + ProviderScope
│  ├─ app/
│  │  ├─ providers.dart          # 全部 Riverpod Provider（依赖注入）
│  │  └─ router.dart             # go_router 路由 + 登录守卫
│  ├─ core/
│  │  ├─ constants/app_constants.dart   # URL、学期码、超时、默认作息
│  │  ├─ theme/                  # 配色 app_colors + 主题 app_theme
│  │  ├─ utils/schedule_utils.dart      # 周次/节次解析、学期周次计算
│  │  └─ widgets/hud_card.dart   # 科技风卡片/标签/呼吸灯/网格背景
│  ├─ domain/entities/entities.dart     # 领域模型（与接口字段解耦）
│  ├─ data/
│  │  ├─ crypto/wisedu_crypto.dart      # 金智口令 AES/CBC 加密
│  │  ├─ network/                # Dio 封装 + 统一异常映射
│  │  ├─ remote/                 # auth / schedule / grade 远程数据源
│  │  ├─ local/                  # SQLite + 安全存储 + 设置存储
│  │  └─ repositories/           # 仓库：远程+本地+隐藏过滤+统计
│  └─ features/
│     ├─ auth/                   # 登录控制器 + 登录页
│     ├─ home/home_page.dart     # 首页
│     ├─ schedule/               # 周课表控制器 + 页面
│     ├─ grade/                  # 成绩控制器 + 列表页 + 详情页 + 绩点科目选择页
│     ├─ course_manage/          # 隐藏课程管理页
│     ├─ settings/               # 设置页 + 作息时间编辑页(period_times_page)
│     ├─ reminder/reminder_service.dart # 上课/成绩提醒排程
│     ├─ sync/sync_service.dart  # 同步编排
│     ├─ background/background_sync.dart # WorkManager 后台任务
│     └─ shell/main_shell.dart   # 底部导航框架
└─ test/widget_test.dart         # 解析/周次/模型单元测试
```

---

## 架构设计

严格分层，单向依赖：

```
Presentation (features/*_page.dart)
      │  watch/read
State Management (Riverpod Notifier / Provider)
      │
Repository (data/repositories/*)   ← 业务编排：远程 + 本地 + 隐藏过滤 + 统计
      │                    │
Remote DataSource        Local DataSource
(data/remote/*)          (data/local/*: SQLite / SecureStorage / SharedPreferences)
      │
Network (Dio + CookieJar) / Crypto (AES)
      │
正方 jwglxt HTTP API（HTTPS）
```

设计取舍：

- **无后端**：所有请求由 App 直接发往学校教务系统。不引入自建服务器，避免无谓的运维、数据中转与隐私风险（符合「不为了显得高级而加后端」的要求）。
- **sqflite 而非 Drift、Riverpod 手写而非 codegen**：减少构建期代码生成环节，最大化构建稳定性与可读性。
- **服务器数据与用户设置分表**：同步只覆盖 `schedule_entry`/`grade`，隐藏与提醒设置存独立表，**保证隐藏状态在重新同步后不丢失**。
- **稳定 ID 去重**：`courseId=kch+jxb`、`entryId=courseId+星期+节次`、`gradeId=row_id`，用于隐藏、提醒、新成绩检测的去重。

---

## 接口说明（逆向自正方教务系统）

> 全部通过 HTTPS 访问 `jwxt.fjjxu.edu.cn`；不含任何硬编码凭证。

### 1. 登录（金智统一认证 SSO）

1. GET `authserver/login?service=...`，从页面解析隐藏域：`lt`、`execution`、`_eventId`、`dllt`、`rmShown`、以及口令加密盐 `pwdDefaultEncryptSalt`。
2. 口令加密：**AES/CBC/PKCS7**
   - 明文 = `随机64位字符 + 原始密码`
   - 密钥 = `pwdDefaultEncryptSalt`（取 16 字节）
   - IV = 随机 16 位 ASCII 字符
   - 输出 Base64
3. POST 登录表单；成功后 CAS 携带 `ticket` 重定向到正方 `sso/jznewsixlogin`，换取正方 `JSESSIONID`。
4. 若页面出现滑块/验证码，判定为需要人工验证 —— **App 不绕过**，提示用户稍后再试或改用网页登录（见「安全与合规」）。

### 2. 课表

```
POST /jwglxt/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151
Header: X-Requested-With: XMLHttpRequest
Body(form): xnm=<学年起始年>&xqm=<学期码>&kzlx=ck
→ { xsxx: {...学生信息}, kbList: [...课表], sjkList: [...实践课] }
```

学期码：`3`=第一学期(秋)、`12`=第二学期(春)、`16`=第三学期(夏)。

### 3. 成绩

```
POST /jwglxt/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005
Header: X-Requested-With: XMLHttpRequest
Body(form): queryModel.showCount=500 (取全部) [+ xnm/xqm 可选筛选]
→ { totalCount, items: [ {...每门成绩} ] }
```

> `doType=query` 为必需，否则返回 HTML 页面而非 JSON。数据在 `items` 字段。本校 `pscj/qzcj/sycj/qmcj`（平时/期中/实验/期末）通常为 `null`，因此 App **只显示总评 `cj` 与校方绩点 `jd`**，绝不虚构构成明细。

字段映射详见 `lib/data/remote/*.dart` 与 `docs/api.md`。

---

## 数据模型

见 `lib/domain/entities/entities.dart`：

- `Student`：name / id / className / major / college
- `Semester`：xnm（学年起始年）/ xqm（学期码），提供 `termIndex`、`displayName`
- `Course`：courseId / name / teacher / credit / nature / category / assessType / teachingClass / xnm / xqm
- `ScheduleEntry`：entryId / courseId / courseName / teacher / weekday(1-7) / startSection / endSection / weeks[] / location / campus / rawJc / rawWeeks / credit / assessType；`occursInWeek(w)`
- `Grade`：gradeId / courseName / teacher / xnm / xqm / termName / credit / score(cj) / gpa(jd) / hundredScore / nature / category / assessType / examType / usualScore / midScore / expScore / finalScore；`hasComponents`、`scoreValue`、`gpaValue`、`creditValue`
- `RemindMode`：notification / alarm / both
- `CourseReminderSetting`：courseId / enabled / mode / minutesBefore（<=0 用全局默认）

---

## 数据库表结构

SQLite（`keben.db`，version 1）：

| 表 | 用途 | 关键列 | 同步是否覆盖 |
|----|------|--------|--------------|
| `schedule_entry` | 课表缓存 | entryId(PK), courseId, weekday, startSection, endSection, weeks, location, xnm, xqm | ✅ 按学期整体替换 |
| `grade` | 成绩缓存 | gradeId(PK), courseName, score, gpa, credit, xnm, xqm, termName | ✅ 整体替换 |
| `hidden_course` | 隐藏的整门课程 | courseId(PK), hiddenAt | ❌ **永不覆盖** |
| `hidden_occurrence` | 隐藏的单次课程 | id(PK), entryId, week, UNIQUE(entryId,week) | ❌ **永不覆盖** |
| `course_reminder` | 每门课提醒设置 | courseId(PK), enabled, mode, minutesBefore | ❌ **永不覆盖** |
| `meta` | 键值元数据 | k(PK), v | ❌ |

敏感凭证（学号/密码）不在 SQLite，存于 `flutter_secure_storage`（Android EncryptedSharedPreferences）。

---

## 安全与合规

- **无硬编码凭证**：源码、日志中均不含账号密码；界面不回显密码。
- **不打日志泄露敏感信息**：不记录密码、完整 token/cookie。
- **安全存储**：凭证经 `flutter_secure_storage`（Android 端 EncryptedSharedPreferences）加密保存。
- **全程 HTTPS**：不禁用 SSL/TLS 校验；证书异常时提示用户而非绕过。
- **不上传第三方**：数据仅在本机与学校教务系统之间流转，不发送任何无关第三方。
- **不绕过学校安全机制**：遇到验证码/滑块/人机校验/登录限制时，App 停止自动化并给出友好提示，建议用户稍后再试或改用网页登录，绝不破解或模拟绕过。
- **隐私**：提醒通知不展示具体分数；成绩通知只提示「有 N 门新成绩」。

---

## 测试结果

单元测试 `test/widget_test.dart`（`flutter test`）全部通过：

```
00:00 +9: All tests passed!
```

覆盖：周次串解析（区间/多段/单双周/空）、节次解析、星期中文映射、分钟格式化、当前周计算（以周一为起点、开学前返回 null）、`ScheduleEntry.occursInWeek`、`Grade.hasComponents` 与数值解析。

静态分析：`flutter analyze` **0 error**（仅余 `withOpacity` 等 deprecation info，不影响构建与运行）。

---

## 已知限制

1. **上下课钟表时间需校准**：正方课表接口不返回每节的起止钟点，App 内置了一套默认作息（`AppConstants.defaultPeriodTimes`）。现已支持在「设置 → 上下课作息时间」逐节手动校准（可增删节次、恢复默认），保存后首页时间显示与提醒排程会立即使用新作息。请按福建江夏学院实际作息填写，否则提醒触发时刻会偏差（如首节实际 8:20 而默认 8:00）。
2. **开学日期需校准**：无官方校历接口，周次由「开学第一周周一」推算；默认按规则估算，建议在「设置 → 开学第一周」手动选择准确日期，否则周次/提醒日期会偏差。
3. **验证码/滑块**：若学校对登录启用图形/滑块验证，自动化登录会失败并提示，需稍后重试或用网页登录（不绕过）。
4. **发布签名**：当前 release 构建使用 debug 签名以便直接安装测试；正式上架需配置自己的 keystore 签名。
5. **闹钟模式**：采用「全屏意图 + 闹钟音频属性(USAGE_ALARM)」的本地通知实现，效果接近系统闹钟；未引入额外原生闹钟插件以降低构建风险。
6. **单课程提醒 UI**：数据层与排程逻辑已支持每门课独立提醒设置，当前设置页暴露的是全局默认；后续可在课程详情内加入单课程覆盖入口。
