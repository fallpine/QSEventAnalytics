//
//  AnalyticTool.swift
//  QSEventAnalytics
//
//  Created by ht on 2025/12/11.
//

import QSApiAnalytics
import QSFirebaseAnalytics

public class AnalyticTool {
    // MARK: - Func
    public static func initialize(userid: String,
                           api: String,
                           systemVersion: String,
                           appVersion: String
                           )
    {
        ApiAnalytics.shared.initialize(userid: userid,
                                       api: api,
                                       systemVersion: systemVersion,
                                       appVersion: appVersion)
    }
    
    /// 打点
    public static func addEvent(code: String,
                         name: String,
                         timestamp: TimeInterval?,
                         type: ApiAnalyticsType,
                         belongPage: String?,
                         extra: [String: Any]? = nil)
    {
        FirebaseAnalytics.addEvent(name: code + "_\(type.firebaseTypeCode)")
        ApiAnalytics.shared.addEvent(code: code,
                                     name: name,
                                     timestamp: timestamp,
                                     type: type,
                                     belongPage: belongPage,
                                     extra: extra)
    }
    
    /// 更新sessionId
    public static func updateSessionId() {
        ApiAnalytics.shared.updateSessionId()
    }
    
    /// 获取当前页面信息
    public static func getCurrentPageData() -> [String: Any]? {
        return ApiAnalytics.shared.getCurrentPageData()
    }
    
    /// 返回当前页面
    public static func returnToPage(pageData: [String: Any]?) {
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
    
    public static var currentPageCode: String {
        return ApiAnalytics.shared.currentPageCode
    }
}
