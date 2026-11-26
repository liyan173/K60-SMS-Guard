# K60-SMS-Guard

适用于 Redmi K60 Pro（22127RK46C，代号 socrates）、Android 16 和 KernelSU 的后台短信限制模块。

## 功能

- 限制清单内的后台应用使用短信发送权限。遇到清单以外的共享 UID 成员时跳过对应项。
- 从 Android 主用户移除预置的小米 SIM 卡激活服务。
- 关闭 5G 消息及发送失败后的短信和彩信回落。
- 保留默认短信应用的手动发短信和接收验证码所需权限。

## 安装和验证

1. 在 [Releases](https://github.com/liyan173/K60-SMS-Guard/releases/latest) 下载 `K60-SMS-Guard-v1.0.0.zip`。
2. 在 KernelSU 的「模块」里选择「从本地安装」，选中安装包后重启。
3. 开机后可以用 Root 读取 `/data/adb/k60-sms-guard/last-boot.log`，检查模块实际应用了哪些规则。

v1.0.0 已在一台上述配置的 K60 Pro 上实测开机执行。复查确认小米 SIM 激活服务仍处于移除状态，默认短信应用的收发权限仍已授予。本次查验范围内，短信数据库未出现发送记录。验证过程仅查询权限和记录。

ZIP 的 SHA-256 为 `b1cbcc391b2246c661431daccf44ba56c07021ecdbfd4fbb01468a147c91aeee`。[`module/`](module/) 中的文件与此 ZIP 内的内容逐一对应。

## 影响与恢复

依赖短信激活的小米查找设备、账号或云服务功能可能受影响。停用或移除模块会停止后续应用规则，Android 已保存的应用卸载状态、短信限制和 5G 消息设置需要另行恢复。模块会把应用前的状态记录在 `/data/adb/k60-sms-guard/before.tsv`。恢复小米激活服务及发信权限可能再次触发运营商计费短信。

如果设备上有模块可识别的旧版短信保护启动脚本，模块会在规则验证成功后迁移它并保存备份。卸载模块会尝试恢复这份旧脚本。[模块内说明](module/README.zh-CN.md)

反馈时请附上机型、Android 版本、KernelSU 版本和脱敏的模块日志。[提交反馈](https://github.com/liyan173/K60-SMS-Guard/issues)
