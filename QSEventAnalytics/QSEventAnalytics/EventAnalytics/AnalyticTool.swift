//
//  AnalyticTool.swift
//  QSEventAnalytics
//
//  Created by ht on 2025/12/11.
//

import QSApiAnalytics
import QSFirebaseAnalytics

public enum AnalyticTool {
    // MARK: - Func
    public static func configure(userId: String,
                                 api: String,
                                 systemVersion: String,
                                 appVersion: String,
                                 ignoreFailedEventCodes: [String] = [],
                                 firebaseEnabled: Bool = true) {
        self.firebaseEnabled = firebaseEnabled

        if firebaseEnabled {
            FirebaseAnalytics.configure()
        }

        ApiAnalytics.shared.initialize(userid: userId,
                                       api: api,
                                       systemVersion: systemVersion,
                                       appVersion: appVersion,
                                       ignoreFailedEventCodes: ignoreFailedEventCodes)
    }

    /// 打点
    public static func addEvent(code: String,
                             name: String,
                             type: ApiAnalyticsType,
                             belongPage: String?,
                             timestamp: TimeInterval? = nil,
                             extra: [String: String]? = nil,
                             onSuccess: (() -> Void)? = nil,
                             onError: ((ApiAnalyticsModel) -> Void)? = nil) {
        if firebaseEnabled {
            FirebaseAnalytics.addEvent(name: code)
        }

        ApiAnalytics.shared.addEvent(code: code,
                                     name: name,
                                     timestamp: timestamp,
                                     type: type,
                                     belongPage: belongPage,
                                     extra: extra,
                                     onSuccess: onSuccess,
                                     onError: onError)
    }
    
    /// 更新sessionId
    public static func updateSessionId() {
        ApiAnalytics.shared.updateSessionId()
    }

    /// 获取当前时间戳
    public static func currentTimestamp() -> TimeInterval {
        return ApiAnalytics.shared.getCurrentTimestamp()
    }

    /// 获取当前页面信息
    public static func currentPageData() -> [String: Any]? {
        return ApiAnalytics.shared.getCurrentPageData()
    }

    /// 返回当前页面
    public static func returnToPage(_ pageData: [String: Any]?) {
        if let code = pageData?["code"] as? String,
           !code.isEmpty,
           let name = pageData?["name"] as? String
        {
            let extra = pageData?["extra"] as? [String: String]

            addEvent(code: code,
                  name: name,
                  type: .pageIn,
                  belongPage: code,
                  timestamp: nil,
                  extra: extra)
        }
    }

    public static var currentPageCode: String {
        return ApiAnalytics.shared.currentPageCode
    }

    // MARK: - Property
    private static var firebaseEnabled = true
}
