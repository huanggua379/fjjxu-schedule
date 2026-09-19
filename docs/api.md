# 接口与字段映射（正方 jwglxt / 金智 SSO）

> 本文档记录「课本」App 与福建江夏学院教务系统交互的真实接口与字段映射，供维护参考。
> 全部经 HTTPS，不含任何凭证；口令加密算法见下。实测可用（课表 48 条、成绩 30 条 / 2 学期）。

站点：
- 统一认证：`https://authserver.fjjxu.edu.cn`
- 教务系统：`https://jwxt.fjjxu.edu.cn`
- SSO 回调：`https://jwxt.fjjxu.edu.cn/sso/jznewsixlogin`

---

## 一、登录（金智统一认证）

### 步骤
1. `GET authserver/login?service=<SSO回调>`，从返回 HTML 解析隐藏域：
   - `lt`（登录令牌）、`execution`、`_eventId=submit`、`dllt=userNamePasswordLogin`、`rmShown=1`
   - `pwdDefaultEncryptSalt`（口令加密盐）
2. 加密口令（见下）。
3. `POST authserver/login?service=...`，表单含 `username`、`password`(密文)、上述令牌。
4. 成功后 302 携带 CAS `ticket` 跳转到 SSO 回调 → 正方写入 `JSESSIONID`。
5. 失败判定：最终 URL 仍含 `authserver/login`；若页面含滑块/验证码则抛 `CaptchaRequiredException`（**不绕过**）。

### 口令加密算法（AES/CBC/PKCS7）
```
明文     = randomAscii(64) + 原始密码
密钥 Key = pwdDefaultEncryptSalt 的前 16 字节
IV       = randomAscii(16)
输出     = Base64( AES/CBC/PKCS7( 明文, Key, IV ) )
```
实现：`lib/data/crypto/wisedu_crypto.dart`（`encrypt` 包）。
> 注意：不是对原始密码做 ECB；必须是「随机64位 + 密码」的 CBC 加密，否则登录失败。

---

## 二、课表

```
POST https://jwxt.fjjxu.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151
Headers: X-Requested-With: XMLHttpRequest ; Referer: .../xskbcx_cxXskbcxIndex.html?gnmkdm=N2151
Body(form-urlencoded): xnm=<学年起始年> & xqm=<学期码> & kzlx=ck
```

学期码 `xqm`：`3`=第一学期(秋)、`12`=第二学期(春)、`16`=第三学期(夏)。
`xnm`：学年起始年（如 2026 表示 2026-2027 学年）。

返回 JSON：
```jsonc
{
  "xsxx": { "XM":"姓名", "XH":"学号", "BJMC":"班级名称", "ZYMC":"专业名称" },
  "kbList": [ /* 每周固定排课 */ ],
  "sjkList": [ /* 实践课，通常无固定星期节次 */ ]
}
```

### kbList 字段 → ScheduleEntry

| 正方字段 | 含义 | 映射 |
|----------|------|------|
| `kcmc` | 课程名 | courseName |
| `kch_id`(或`kch`) | 课程号 | courseId 组成 |
| `jxb_id` | 教学班号 | courseId 组成 |
| `xm` | 教师姓名 | teacher |
| `xqjmc` / `xqj` | 星期(中文/数字) | weekday(1-7) |
| `jc` | 节次串，如 `1-2节` | startSection/endSection + rawJc |
| `zcd` | 周次串，如 `2-5周,7-14周` | weeks[] + rawWeeks |
| `cdmc` | 教室 | location |
| `xqmc` | 校区 | campus |
| `xf` | 学分 | credit |
| `khfsmc` | 考核方式 | assessType |

- `courseId = "{kch_id}_{jxb_id}"`（区分同名课/不同教学班）
- `entryId = "{courseId}_{weekday}_{jc}"`（隐藏/提醒去重用）
- `xqj==0` 或节次缺失的排课会被跳过（无法定位到网格）。

### sjkList 字段（实践课）
`kcmc`/`kch_id`/`jxb_id`/`jsxm`(或`xm`)/`qsjsz`(周次)/`cdmc`/`xqmc`/`xf`/`khfsmc`。
实践课 `weekday=0`、`startSection=0`，不进周课表网格，也不排上课提醒。

---

## 三、成绩

```
POST https://jwxt.fjjxu.edu.cn/jwglxt/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005
Headers: X-Requested-With: XMLHttpRequest ; Referer: .../cjcx_cxDgXscj.html?gnmkdm=N305005
Body(form-urlencoded):
  xnm= & xqm=                      # 留空=全部历史；填写=按学期筛选
  _search=false
  queryModel.showCount=500         # 取全部（默认仅15）
  queryModel.currentPage=1
  queryModel.columnName= & queryModel.sortName= & queryModel.sortOrder=
  queryModel.queryShowCount=true
```

> `doType=query` 必需，否则返回 HTML 而非 JSON；数据在 `items`（不是 `data`）。
> 曾误用 `cjcx_cxDgXscj.html` 作为数据接口 → 404/HTML；正确学生个人成绩接口是 `cjcx_cxXsgrcj.html`。

返回 JSON：
```jsonc
{ "totalCount": 30, "items": [ /* 每门成绩 */ ] }
```

### items 字段 → Grade

| 正方字段 | 含义 | 映射 | 备注 |
|----------|------|------|------|
| `kcmc` | 课程名 | courseName | |
| `jsxm` | 任课教师 | teacher | |
| `xnm`/`xqm` | 学年/学期码 | xnm/xqm/termName | |
| `xf` | 学分 | credit | |
| `cj` | **总评成绩** | score | 主显示 |
| `jd` | **绩点（校方）** | gpa | GPA 按此加权，不自算规则 |
| `bfzcj` | 百分制成绩 | hundredScore | |
| `kcxzmc` | 课程性质 | nature | |
| `kclbmc` | 课程类别 | category | |
| `khfsmc` | 考核方式 | assessType | |
| `ksxz` | 考试性质 | examType | |
| `pscj` | 平时成绩 | usualScore | **本校通常为 null** |
| `qzcj` | 期中成绩 | midScore | **本校通常为 null** |
| `sycj` | 实验成绩 | expScore | **本校通常为 null** |
| `qmcj` | 期末成绩 | finalScore | **本校通常为 null** |
| `row_id`(或`bh`) | 行唯一号 | gradeId | 缺失则回退 `xnm_xqm_kch_id_jxb_id` |

- 构成明细（平时/期中/实验/期末）本校实测全为 null，`Grade.hasComponents` 为 false，UI 明确显示「教务系统未提供成绩构成明细，仅显示总评」，**绝不虚构**。
- 加权绩点：`Σ(jd×xf) / Σ(xf)`（仅统计有 `jd` 且 `xf>0` 的记录）。

---

## 四、稳定 ID 汇总（去重关键）

| 实体 | ID 规则 |
|------|---------|
| 课程 Course | `{kch_id}_{jxb_id}` |
| 排课 ScheduleEntry | `{courseId}_{weekday}_{jc}` |
| 成绩 Grade | `row_id`，缺失回退 `{xnm}_{xqm}_{kch_id}_{jxb_id}` |
| 提醒通知 | `stableId("{entryId}|{week}")` 哈希为 31 位正整数 |
| 成绩通知 | `stableId("grade|{所有新 gradeId 拼接}")` |

---

## 五、异常映射（面向用户，绝不暴露堆栈）

| 场景 | 友好提示 |
|------|----------|
| 连接超时/读写超时 | 请求超时，请稍后重试 |
| 连接失败/DNS | 网络连接失败，请检查网络后重试 |
| 证书校验失败 | 安全证书校验失败，请检查网络环境（**不禁用校验**） |
| 5xx | 教务系统繁忙或维护中，请稍后重试 |
| 会话失效 | 登录状态已失效，请重新登录 |
| 学号/密码错误 | 学号或密码错误 |
| 需要验证码/滑块 | 教务系统要求验证码，请暂时改用网页登录或稍后再试 |
| 解析失败 | 数据解析失败，请稍后重试 |

实现：`lib/data/network/api_exception.dart` + `network_client.dart` 的 `mapError`。
