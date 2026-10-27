# 更新紀錄（Changelog）

本檔記錄此專案所有值得注意的變更。

格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號遵循 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

日期為該版本發佈到 [rubygems.org](https://rubygems.org/gems/active_merchant_ecpay) 的日期。

## [Unreleased]

> `master` 上的 `lib/active_merchant_ecpay/version.rb` 已經是 `0.2.0`，但這個版本**還沒有發佈到 rubygems.org**
> （該版本的 "Publish gem" 執行失敗，錯誤為 "No trusted publisher configured for this workflow"），所以先列在這裡。
> 等 0.2.0 發佈後，請把這個區塊改名為 `## [0.2.0] - YYYY-MM-DD`，並使用 rubygems.org 上顯示的日期。

### Added

- 支援 Rails 7.0、7.1、7.2、8.0 與 8.1（Ruby 3.0 – 3.4）。`actionview` 與 `activesupport`（`>= 7.0`, `< 8.2`）現在是 runtime 相依套件。
- 針對請求組裝、`CheckMacValue`、通知檢查與設定補上 RSpec spec；測試不會連網。以 `COVERAGE=1` 啟用 SimpleCov 覆蓋率。
- GitHub Actions：Ruby × Rails 測試矩陣（`test.yml`），以及透過 Trusted Publishing 自動發佈到 RubyGems（`publish.yml`）。
- `CHANGELOG.md`、完整的 `README.md`，以及 `CLAUDE.md` 裡的文件規則。
- `CLAUDE.md` 規定 `README.md` 與 `CHANGELOG.md` 一律用繁體中文撰寫。

### Changed

- **不相容變更：** 需要 Ruby `>= 3.0`（`required_ruby_version`）；不再支援 7.0 以前的 Rails。
- 更新開發相依套件（`bundler >= 2`、`rake >= 13`）；移除 `mocha` 與舊的 `rails >= 2.3.14` 開發相依，改用各版本專屬的 `gemfiles/`。
- `README.md`、`CHANGELOG.md` 改以繁體中文（zh-TW）撰寫。

## [0.1.2] - 2018-11-16

版本 `0.1.0` 與 `0.1.1` 從未發佈到 RubyGems，所以它們的變更一併在這個版本釋出。

### Added

- ECPay（綠界科技）AIO 全方位金流結帳的 ActiveMerchant / OffsitePayments 整合：`payment_service_for` 表單 helper（含 `CheckMacValue`（MD5）產生），以及 `Notification` 的解析 / 驗證。付款方式：信用卡、ATM、CVS、條碼與 Alipay 常數。（0.1.0）
- `Notification#card4no`：信用卡末四碼。（0.1.1）

### Changed

- 整理 gemspec 的描述與 `require`（`money` 改為明確 require）。

[Unreleased]: https://github.com/superlanding/active_merchant_ecpay/commits/master
[0.1.2]: https://rubygems.org/gems/active_merchant_ecpay/versions/0.1.2
