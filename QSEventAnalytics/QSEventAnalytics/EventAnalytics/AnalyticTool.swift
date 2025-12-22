//
//  AnalyticTool.swift
//  QSEventAnalytics
//
//  Created by ht on 2025/12/11.
//

import Alamofire
import Foundation

#if os(iOS)
    import UIKit
#elseif os(watchOS)
    import WatchKit
#endif

public class AnalyticTool {
    // MARK: - Func

    public func initialize(userid: String,
                           api: String,
                           getIpLocationAction: @escaping ((@escaping (_ networkIp: String, _ countryCode: String, _ cityCode: String) -> Void) -> Void))
    {
        #if os(iOS)
            FirebaseAnalyticTool.configure()
        #endif // canImport(FirebaseAnalytics)

        self.userid = userid
        self.api = api
        self.getIpLocationAction = getIpLocationAction
    }

    /// 打点
    public func addEvent(code: String,
                         name: String,
                         timestamp: TimeInterval?,
                         type: EventType,
                         belongPage: String?,
                         extra: [String: Any]? = nil)
    {
        let newTimestamp = timestamp ?? Date().timeIntervalSince1970 * 1000

        if type == .pageIn {
            // 退出上一个页面
            if !currentPageCode.isEmpty {
                addEvent(code: currentPageCode,
                         name: currentPageName,
                         timestamp: newTimestamp - 1,
                         type: .pageOut,
                         belongPage: currentPageCode,
                         extra: nil)
            }

            // 记录新页面
            currentPageCode = code
            currentPageName = name
            currentPageExtra = extra
        }

        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }

            #if os(iOS)
                // Firebase 打点（仅在支持 FirebaseAnalytics 的平台执行）
                FirebaseAnalyticTool.addEvent(name: code + "_\(type.firebaseTypeCode)")
            #endif // canImport(FirebaseAnalytics)

            // Firebase打点
            // 接口记录
            requestApi(sessionId: sessionId,
                       eventCode: code,
                       eventName: name,
                       timestamp: newTimestamp,
                       eventType: type,
                       belongPage: belongPage,
                       extra: extra) {} onFailure: { [weak self] in
                guard let `self` = self else { return }

                failedEventsLock.lock()
                let model = AnalyticModel(sessionId: sessionId,
                                          eventCode: code,
                                          eventName: name,
                                          eventType: type,
                                          timestamp: newTimestamp,
                                          belongPage: belongPage,
                                          extra: extra)
                failedEvents.append(model)
                failedEventsLock.unlock()
            }
        }
    }

    /// 更新sessionId
    public func updateSessionId() {
        sessionId = UUID().uuidString
    }

    /// 获取当前页面信息
    public func getCurrentPageData() -> [String: Any] {
        return [
            "code": currentPageCode,
            "name": currentPageName,
            "extra": currentPageExtra as Any,
        ]
    }

    /// 返回当前页面
    public func returnToPage(pageData: [String: Any]?) {
        if let code = pageData?["code"] as? String,
           let name = pageData?["name"] as? String
        {
            let extra = pageData?["extra"] as? [String: Any]

            addEvent(code: code,
                     name: name,
                     timestamp: nil,
                     type: .pageIn,
                     belongPage: code,
                     extra: extra)
        }
    }

    // MARK: - Property

    public static var appVersion: String? {
        let kInfoDict = Bundle.main.infoDictionary
        // 获取App的版本号
        return kInfoDict?["CFBundleShortVersionString"] as? String
    }

    /// 重新发送失败的事件
    private func resendFailedEvents() {
        if isSending { return }
        if failedEvents.isEmpty { return }

        isSending = true

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            while true {
                failedEventsLock.lock()
                guard !failedEvents.isEmpty else {
                    failedEventsLock.unlock()
                    break
                }
                let model = failedEvents.removeFirst()
                failedEventsLock.unlock()

                requestApi(sessionId: model.sessionId,
                           eventCode: model.eventCode,
                           eventName: model.eventName,
                           timestamp: model.timestamp,
                           eventType: model.eventType,
                           belongPage: model.belongPage,
                           extra: model.extra)
                {
                    // 成功无需处理
                } onFailure: { [weak self] in
                    guard let self = self else { return }

                    failedEventsLock.lock()
                    failedEvents.append(model)
                    failedEventsLock.unlock()
                }
            }
        }
    }

    /// 打点事件
    /// - Parameters:
    ///   - sessionId: 会话id
    ///   - eventCode: 事件Code
    ///   - eventName: 事件名
    ///   - eventType: 事件类型
    ///   - belongPage: 属于哪个页面
    ///   - extra: 额外数据
    ///   - completion: 完成回调
    private func requestApi(sessionId: String,
                            eventCode: String,
                            eventName: String,
                            timestamp: TimeInterval,
                            eventType: EventType,
                            belongPage: String?,
                            extra: [String: Any]?,
                            onSuccess: @escaping (() -> Void),
                            onFailure: @escaping (() -> Void))
    {
        getIpLocationAction? { [weak self] networkIp, countryCode, cityCode in
            guard let `self` = self else { return }

            var extraContent = ""
            if extra != nil {
                extraContent = objectToJsonString(extra!) ?? ""
            }

            var paraDict = [
                "sessionId": sessionId,
                "uuid": userid,
                "eventCode": eventCode,
                "eventName": eventName,
                "eventType": eventType.typeCode,
                "eventTime": timestamp,
                "userIp": networkIp,
                "countryCode": countryCode,
                "cityCode": cityCode,
                "systemVersion": getSystemVersion(),
                "appVersion": AnalyticTool.appVersion ?? "",
                "attrPage": belongPage ?? "",
                "eventContent": extraContent,
            ] as [String: Any]

            #if DEBUG
                paraDict["env"] = "dev"
            #else
                paraDict["env"] = "prd"
            #endif

            guard let requestUrl = URL(string: api) else {
                return
            }

            // 请求
            AF.request(requestUrl,
                       method: .post,
                       parameters: paraDict,
                       encoding: JSONEncoding.prettyPrinted)
                .responseData(completionHandler: { [weak self] response in
                    switch response.result {
                    case .success:
                        self?.myPrint("打点：", eventCode, eventName, eventType.typeCode, belongPage ?? "", extraContent)
                        onSuccess()

                    case let .failure(err):
                        self?.myPrint("打点：", err.localizedDescription)
                        onFailure()
                    }
                })
        }
    }

    /// 对象转Json字符串
    ///
    /// - Parameter obj: 对象
    /// - Returns: Json字符串
    private func objectToJsonString(_ obj: Any) -> String? {
        var jsonString: String?

        if let jsonData = try? JSONSerialization.data(withJSONObject: obj, options: JSONSerialization.WritingOptions.prettyPrinted) {
            jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
        }

        guard var jsonString = jsonString else { return nil }

        // 去掉字符串中的空格
        let range = NSRange(location: 0, length: jsonString.count)
        jsonString = jsonString.replacingOccurrences(of: " ", with: "", options: String.CompareOptions.literal, range: Range(range, in: jsonString))
        // 去掉字符串中的换行符
        let range1 = NSRange(location: 0, length: jsonString.count)
        jsonString = jsonString.replacingOccurrences(of: "\n", with: "", options: String.CompareOptions.literal, range: Range(range1, in: jsonString))

        return jsonString
    }

    /// APP进入前台
    @objc private func appWillEnterForeground() {
        // 打点
        addEvent(code: "app_foreground",
                 name: "进入-【前台】",
                 timestamp: nil,
                 type: .appIn,
                 belongPage: currentPageCode,
                 extra: nil)
    }

    /// APP进入后台
    @objc private func appDidEnterBackground() {
        // 打点
        addEvent(code: "app_foreground",
                 name: "进入-【后台】",
                 timestamp: nil,
                 type: .appOut,
                 belongPage: currentPageCode,
                 extra: nil)
    }

    /// APP进入活跃状态
    @objc private func didBecomeActive() {
        // 打点
        addEvent(code: "app_become_active",
                 name: "进入-活跃状态",
                 timestamp: nil,
                 type: .state,
                 belongPage: currentPageCode,
                 extra: nil)
    }

    /// APP非进入活跃状态
    @objc private func willResignActive() {
        // 打点
        addEvent(code: "app_resign_active",
                 name: "进入-非活跃状态",
                 timestamp: nil,
                 type: .state,
                 belongPage: currentPageCode,
                 extra: nil)
    }

    /// 监听网络状态
    private func networkReachabilityChanged() {
        networkReachabilityManager = NetworkReachabilityManager()

        networkReachabilityManager?.startListening(onUpdatePerforming: { [weak self] status in
            switch status {
            case .reachable:
                self?.resendFailedEvents()

            default:
                break
            }
        })
    }

    private func getSystemVersion() -> String {
        #if os(iOS)
            return UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        #elseif os(watchOS)
            return WKInterfaceDevice.current().systemName + " " + WKInterfaceDevice.current().systemVersion
        #else
            return ""
        #endif
    }

    private func myPrint(_ items: Any...) {
        #if DEBUG
            print(items)
        #endif
    }

    // MARK: - Property

    private var networkReachabilityManager: NetworkReachabilityManager?
    private var userid = ""
    private var api = ""
    private var getIpLocationAction: ((@escaping (_ networkIp: String, _ countryCode: String, _ cityCode: String) -> Void) -> Void)?
    private var sessionId = UUID().uuidString

    public var currentPageCode = ""
    private var currentPageName = ""
    private var currentPageExtra: [String: Any]?

    // 发送失败的点
    private var failedEvents = [AnalyticModel]()
    private var isSending = false
    private let failedEventsLock = NSLock()

    // MARK: - 单例

    private static var _shareInstance: AnalyticTool?
    public static var share: AnalyticTool {
        guard let instance = _shareInstance else {
            _shareInstance = AnalyticTool()
            return _shareInstance!
        }

        return instance
    }

    private init() {
        // 监听应用生命周期（根据平台不同使用不同的通知）
        #if os(iOS)
            // 监听进入后台
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            // 监听进入前台
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            // 监听进入活跃状态
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            // 监听进入非活跃状态
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(willResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        #elseif os(watchOS)
            // watchOS 生命周期通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: WKExtension.applicationDidEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForeground),
                name: WKExtension.applicationWillEnterForegroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didBecomeActive),
                name: WKExtension.applicationDidBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(willResignActive),
                name: WKExtension.applicationWillResignActiveNotification,
                object: nil
            )
        #endif

        // 网络状态改变
        networkReachabilityChanged()
    }
}
