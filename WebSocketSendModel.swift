//   
//   WebSocketSendModel.swift
//   LiveProject
//   
//   Created  by 大虾咪 on 2024/6/17 
//   
//   
   

import Foundation
import HandyJSON

struct WebSocketSendModel :HandyJSON{
    var t: Int? //协议类型,参考字典
    var f: Int = 1    //协议格式，0/RAW, 1/JSON, 固定值1
    var s: Bool?      //状态
    var v: String?       //简单int值
    var vv:[Int:Int]? //简单int值KV
    var d: String?    //业务数据json体, 参考对应业务消息结构
}

struct WebSocketSendParamsModel: HandyJSON{
    var account_id: String = UserMessageManager.shared.getUsermodel()?.id ?? ""
    var platform: String = "iOS"
    var version: String = CommonTool.getVersion()
    var device: String = AppMessages.shared.phoneModel ?? "iPhone"
    var addition: String = ""
    var sign: String =  CommonTool.randomIDFA() ?? ""
}

