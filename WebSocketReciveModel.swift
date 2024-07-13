//   
//   WebSocketReciveModel.swift
//   LiveProject
//   
//   Created  by 大虾咪 on 2024/6/17 
//   
//   
   

import Foundation
import HandyJSON
///  最外层t=10 的结构体
struct WebSocketReciveModel: HandyJSON{
    var t: Int?
    var f: Int?
    var s: Bool?
    var d: [WebSocketReciveInfoModel]?
}

/**
    t值    说明    d值
    1    普通弹幕    {"uid": 0, "nickname": "", "text": ""}
    2    付费弹幕    {"uid": 0, "nickname": "", "text": ""}
    3    送礼    {"uid": 0, "nickname": "", "count": 1, "name": "礼物名称"}
    4    开通粉丝团    {"uid": 0, "nickname": ""}
    5    开通贵族    {"uid": 0, "nickname": ""}
    13    被踢出房间    {}
    14    主播下播    {}
 */
struct WebSocketReciveInfoModel: HandyJSON{
    
    var i: Int? // 消息ID
    var t: Int? // 消息类型
    var p: Int? // 消息权重
    var s: Int? // 消息时间
    var e: Int? //消息范围
    var f: Int?// 来自那里
    var ts: String? //接收sess
    var ta: Int?// 接收账号
    var tg: Int?// 接收房间
    var td: Int?// 接收设备
    var d:WebSocketReciveInfoDModel? //业务内容
    var nickname: String?
    var uid: String?
    var text: String?

}

struct WebSocketReciveInfoDModel: HandyJSON{
    var uid: Int = 0
    var nickname:String = ""
    var text:String = ""
    var count:Int = 0
    var name: String?
    var avatar: String?
}
