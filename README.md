# QSEventAnalytics

`QSEventAnalytics` 是一个 iOS 事件打点封装库，用于同时接入 Firebase 打点和自定义接口打点。

## 环境要求

- iOS 15.0+
- Swift 5
- CocoaPods

## 安装

在项目的 `Podfile` 中添加：

```ruby
pod 'QSEventAnalytics'
```

如果需要指定 Git 源：

```ruby
pod 'QSEventAnalytics', :git => 'https://github.com/fallpine/QSEventAnalytics.git', :tag => '1.1.6'
```

然后执行：

```bash
pod install
```

## 使用方法

先在项目中导入：

```swift
import QSEventAnalytics
import QSApiAnalytics
```

应用启动后进行初始化：

```swift
AnalyticTool.configure(
    userId: "user_id",
    api: "https://example.com/api/event",
    systemVersion: UIDevice.current.systemVersion,
    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
    ignoreFailedEventCodes: [],
    firebaseEnabled: true
)
```

添加事件打点：

```swift
AnalyticTool.addEvent(
    code: "home_page_in",
    name: "进入首页",
    type: .pageIn,
    belongPage: "home",
    extra: [
        "source": "launch"
    ],
    onSuccess: {
        print("打点成功")
    },
    onError: { model in
        print("打点失败: \(model)")
    }
)
```

页面返回时，如果需要恢复上一页信息：

```swift
let pageData = AnalyticTool.currentPageData()
AnalyticTool.returnToPage(pageData)
```

更新 session：

```swift
AnalyticTool.updateSessionId()
```

获取当前时间戳和页面 code：

```swift
let timestamp = AnalyticTool.currentTimestamp()
let pageCode = AnalyticTool.currentPageCode
```

## 依赖

本库依赖：

- `QSApiAnalytics`
- `QSFirebaseAnalytics`

## License

MIT
