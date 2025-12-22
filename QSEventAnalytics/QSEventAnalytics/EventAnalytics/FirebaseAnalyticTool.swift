//
//  FirebaseAnalyticTool.swift
//  QSEventAnalytics
//
//  Created by ht on 2025/12/11.
//


#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore

public class FirebaseAnalyticTool {
    // MARK: - Func
    /// 初始化配置
    public static func configure() {
        // 配置Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        var parameters = [String: String]()
        let version = appVersion ?? ""
        parameters["version"] = version
        
        let locale = Locale.current
        if let languageCode = locale.languageCode,
           let countryCode = locale.regionCode {
            parameters["language"] = countryCode + "-" + languageCode
        }
        
        Analytics.setDefaultEventParameters(parameters)
    }
    
    /// Firebase统计分析事件记录
    /// - Parameters:
    ///   - name: 事件名
    ///   - parameters: 参数
    public static func addEvent(name: String, parameters: [String: Any] = [:]) {
        var eventName = name
        let version = (AnalyticTool.appVersion ?? "").replacingOccurrences(of: ".", with: "")
        if !version.isEmpty {
            eventName = eventName + "_" + version
        }
        
        assert(eventName.count <= 40, "事件名过长，不得超过40个字符")
        
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
#endif // canImport(FirebaseAnalytics)
