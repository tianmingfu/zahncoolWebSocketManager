//
//   WebSocketManager.swift
//   LiveProject
//
//   Created  by 大虾咪 on 2024/6/5
//
//


import Foundation
import Starscream
import Network
import Reachability
import HandyJSON

public enum CommandConnectType:Int
{
    case CommandConnect = 1 //连接后发送
    case CommandConnectACK = 2 //发送收到的
    case CommandDisconnect = 3 //主动断开连接
    case CommandDisconnectACK = 4 //断开确认
    case CommandBind = 5 //进房间绑定消息
    case CommandBindACK = 6 //绑定消息确认
    case CommandMsgDownward = 10 //消息下行
    case CommandMsgUpward = 12 //消息上行
    case CommandMsgUpwardACK = 13 //消息上行确认
    case CommandPing = 14 //心跳ping消息
    case CommandPong = 15 //心跳pong消息
}

typealias WebSocketReciveBlock = (WebSocketReciveModel) -> Void


class WebSocketManager {
    
    let reachability = try! Reachability()
    
    static let shared = WebSocketManager()
    
    var timer:Timer?;
    
    var socket:WebSocket?
    
    var reConnectCount = 0
    
    var isConnected:Bool = false
    
    let maxReConnectCount = 5
    
    var firsrConnectWebSocket = true//是否是第一次连接
    
    var currentRoom_id: String?//当前WebSocket进入的房间号 重连时如果有房间号 则需要进入当前房间
    
    var reciveDataTime:TimeInterval = Date.getNowTimeStamp() //最后收到信息的时间
    
    
    //解析数据回调Block
    var webSocketReciveBlock: WebSocketReciveBlock?

    // Make sure the class has only one instance
    // Should not init outside
    private init() {
        
        //MARK: 监控网络变化
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi || reachability.connection == .cellular {
                if self.firsrConnectWebSocket {
                    self.firsrConnectWebSocket = false
                }else{
                    DebugLog("监听到不是第一次连接 网络")
                    DebugLog("reConnect")
                    WebSocketManager.shared.reConnect()
                }
            } else {
                //无网络停止发送心跳包
                self.timer?.invalidate()
                DebugLog("监听到无网络")
                toast("網絡不穩定，請檢查您的網絡連接", .textColor(.white), .radiusSize(8.5), .backColor(UIColor.settingToast), .textAlignment(.center))
            }
        }
        reachability.whenUnreachable = { _ in
            //无网络停止发送心跳包
            self.timer?.invalidate()
            DebugLog("监听到无网络")
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            DebugLog("Unable to start notifier")
        }
        
        if let ws = UserMessageManager.shared.getGlobalConfigModel()?.ws {
            DebugLog("WebSocketWebSocketURL:\(ws)")
            var request = URLRequest(url: URL(string: ws)!)
            request.timeoutInterval = 5
            socket = WebSocket(request: request)
            socket?.delegate = self
        }
        
    }
    
}

extension WebSocketManager {
    
    func connect(){
        timer?.invalidate()
        currentRoom_id = nil
        if isConnected{
            disconnect()
        }
        socket?.connect()
    }
    
    func senMsg(msg: String){
        DebugLog("============websocketwebsocket sendMsg: \(msg) \n   ====== \n")
        if isConnected {
            socket?.write(string: msg)
        }
    }
    
    func disconnect() {
        if isConnected {
            socket?.disconnect()
        }
    }
    
    func reConnect(){
        //无网络 不在重连
        if reachability.connection != .unavailable{
            reConnectCount = reConnectCount + 1
            //超过次数 不在重连
            if reConnectCount > maxReConnectCount{
                //提示重连失败
                return
            }
            if isConnected{
                disconnect()
            }
            DebugLog("重连\(reConnectCount)次")
            connect()
        }else{//提示无网络
            
        }
    }

}

extension WebSocketManager: WebSocketDelegate{
//    public enum WebSocketEvent {
//        case connected([String: String])  //!< 连接成功
//        case disconnected(String, UInt16) //!< 连接断开
//        case text(String)                 //!< string通信
//        case binary(Data)                 //!< data通信
//        case pong(Data?)                  //!< 处理pong包（保活）
//        case ping(Data?)                  //!< 处理ping包（保活）
//        case error(Error?)                //!< 错误
//        case viablityChanged(Bool)        //!< 可行性改变
//        case reconnectSuggested(Bool)     //!< 重新连接
//        case cancelled                    //!< 已取消
//    }
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            isConnected = true
            reConnectCount = 0
            
            //发送用户注册协议（标记用户身份）
            registData()
            
            //用户绑定房间协议（用户进入房间）
            if let currentRoom_id = currentRoom_id {
                enterRoom(room_id: currentRoom_id)
            }
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(timeInterval: String.pingTimeInterval, target: self, selector: #selector(sendPingData), userInfo: nil, repeats: true)
            DebugLog("连接成功")
            DebugLog("websocketwebsocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            isConnected = false
            DebugLog("websocketwebsocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            //记录最后收到信息的时间
            reciveDataTime = Date.getNowTimeStamp()
            let dic = string.toDictionary()
            let t = dic["t"]
                
            if t as! Int == 10{
                DebugLog("10============websocketwebsocket reciveMsg: \n \(dic) \n  ===== \n " )
            }else{
                DebugLog("============websocketwebsocket reciveMsg: \n \(dic) \n  ===== \n " )
            }
            //处理收到t=10的数据
            
        
            
            dealStrToModel(string: string)
           /* if let model = model {
                DebugLog("modelmodel\(String(describing: model.t))")
                if model.t == 10 {
                    self.webSocketReciveBlock?(model)
                }
            }*/
        case .binary(let data):
            DebugLog("websocketwebsocket Received data: \(data.count)")
        case .ping(_):
            DebugLog("websocketwebsocket Received ping")
            break
        case .pong(_):
            DebugLog("websocket Received pong")
            break
        case .viabilityChanged(_):
            DebugLog("websocketwebsocket Received viabilityChanged")

            break
        case .reconnectSuggested(_):
            DebugLog("websocketwebsocket Received reconnectSuggested")
            break
        case .cancelled:
            isConnected = false
            reConnect()
            DebugLog("websocketwebsocket Received cancelled")
        case .error(let error):
            isConnected = false
            DebugLog("websocketwebsocket Received handleError")
            handleError(error)
        case .peerClosed:
            DebugLog("websocketwebsocket Received peerClosed")
//            reConnect()
            break
        }
    }
    func dealStrToModel(string: String) {
        guard let outerData = string.data(using: .utf8) else { return  }
        
        let jsonObject = try? JSONSerialization.jsonObject(with: outerData, options: [])
        let outerDict = jsonObject as? [String: Any]
        let dString = outerDict?["d"] as? String
        let trimmedDString = dString?.trimmingCharacters(in: .whitespacesAndNewlines) // 移除可能存在的空白字符
        let innerData = trimmedDString?.data(using: .utf8) // 将内部JSON字符串转换为Data
        let innerJsonArray = try? JSONSerialization.jsonObject(with: innerData ?? Data(), options: .allowFragments) as? [[String: Any]]
        var webSocketReciveInfoModelArr = [WebSocketReciveInfoModel]()
        var reciveInfoModelArr = [WebSocketReciveInfoDModel]()
        if let innerJsonArray = innerJsonArray {
            for item in innerJsonArray {
                let tempModel1 = JSONDeserializer<WebSocketReciveInfoModel>.deserializeFrom(json: item.toJsonString())
                let innerDString = item["d"] as? String
                let cleanInnerDString = innerDString?.replacingOccurrences(of: "\\\"", with: "\"", options: .literal, range: nil)
//                    WebSocketReciveInfoModel
                guard let model = JSONDeserializer<WebSocketReciveInfoDModel>.deserializeFrom(json: cleanInnerDString) else { return  }
                reciveInfoModelArr.append(model)
             
               let tempWebSocketReciveInfoModel = WebSocketReciveInfoModel(i: tempModel1?.i,t: tempModel1?.t,p: tempModel1?.p,s: tempModel1?.s,e: tempModel1?.e,f: tempModel1?.f,ts: tempModel1?.ts,ta: tempModel1?.ta,tg: tempModel1?.tg,td: tempModel1?.td,d: model)
                webSocketReciveInfoModelArr.append(tempWebSocketReciveInfoModel)
//                    let finalInnerData = cleanInnerDString?.data(using: .utf8)
            }
        }
        
        
        let tempModel1 = JSONDeserializer<WebSocketReciveModel>.deserializeFrom(json: string)
        
        let model = JSONDeserializer<WebSocketReciveModel>.deserializeFrom(json: string)
        let tempModel = WebSocketReciveModel(t: model?.t,f: model?.f,s: model?.s,d: webSocketReciveInfoModelArr)
//        DebugLog("msgmsgmsgmsgmsg2:\(tempModel)结束")
        DebugLog("modelmodel\(String(describing: model?.t))")
        if model?.t == 10 {
            self.webSocketReciveBlock?(tempModel)
        }
        /*
         0 主播消息{"uid":"用户ID""nickname":"用户昵称""text":"消息内容""avatar":"用户头像”}
         1 普通弹幕{"uid": "" "nickname":"" "text":"""avatar":""}
         2 付费弹幕{"uid": "" "nickname":"", "text": """avatar".""}
         3 送礼{"uid":"""nickname":"""count":1,"name":"礼物名称" "avatar":"")
         4 开通粉丝团 {"uid": "","nickname":"","avatar".""}
         5 开通贵族{"uid":"" "nickname":"" "avatar":""}
         6 进入房间{"uid": "" "nickname":"" "avatar":""}
         7 主播公告{"text"."7}
         8 主播名片待定
         13 被踢出房间 {}
         14 主播下播{}
         15 主播开播 {}
         */
        

    }
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            DebugLog("websocketwebsocket encountered an error: \(e.message)")
        } else if let e = error {
            DebugLog("websocketwebsocket encountered an error: \(e.localizedDescription)")
        } else {
            DebugLog("websocketwebsocket encountered an error")
        }
        //重新连接
        reConnect()
    }
    
}

extension WebSocketManager {
    //解析数据回调
    func webSocketObserver(connectType:CommandConnectType,webSocketReciveBlock: @escaping WebSocketReciveBlock){
        
        switch connectType {
        case .CommandMsgDownward:
            self.webSocketReciveBlock = webSocketReciveBlock
        default:
            DebugLog("webSocketObserver")
        }
    }
}


extension WebSocketManager{
    
    func enterRoom(room_id:String) {
        DebugLog("============websocketwebsocket enterRoom room_id : \n " + room_id + "\n" + "===== \n")
        currentRoom_id = room_id
    
        let d = WebSocketSendParamsModel()
        var sendModel = WebSocketSendModel()
        sendModel.t = CommandConnectType.CommandBind.rawValue
//        sendModel.f = 1
        sendModel.v = room_id
        sendModel.d = d.toJSONString()
        
        
        if let sendString = sendModel.toJSONString() {
            WebSocketManager.shared.senMsg(msg: sendString)
        }
    }
    
    func exitRoom(room_id:String) {
        let d = WebSocketSendParamsModel()
        
        var sendModel = WebSocketSendModel()
        sendModel.t = CommandConnectType.CommandDisconnect.rawValue
        sendModel.d = d.toJSONString()
        
        if let sendString = sendModel.toJSONString() {
            WebSocketManager.shared.senMsg(msg: sendString)
        }
        
        currentRoom_id = nil
    }
    
    //连接后注册 标记用户身份
    func registData(){
        
        let d = WebSocketSendParamsModel()
        
        var sendModel = WebSocketSendModel()
        sendModel.t = CommandConnectType.CommandConnect.rawValue
//        sendModel.f = 1
        sendModel.v = "1"
        sendModel.d = d.toJSONString()
        
        
        if let sendString = sendModel.toJSONString() {
            WebSocketManager.shared.senMsg(msg: sendString)
        }
        
    }
    
    func sendMessage(msg:String){
        let d = WebSocketSendParamsModel()
        var sendModel = WebSocketSendModel()
        sendModel.t = CommandConnectType.CommandMsgUpward.rawValue
//        sendModel.f = 1
//        sendModel.v = "1"
        sendModel.d = d.toJSONString()
        
        
        if let sendString = sendModel.toJSONString() {
            WebSocketManager.shared.senMsg(msg: sendString)
        }

    }
    
    
    //模拟心跳包
    //如无收到消息 4s发送一次
    //有消息 重置4s间隔时间 避免浪费性能
    @objc func sendPingData(){
//        当前时间  - reciveDataTime < 30s 不发心跳包
        
        let noSend = (Date.getNowTimeStamp() - reciveDataTime) < String.pingTimeInterval
        if noSend{
          return
        }
        
        let d = WebSocketSendParamsModel()
       
        var sendModel = WebSocketSendModel()
        sendModel.t = CommandConnectType.CommandPing.rawValue
        sendModel.f = 1
        sendModel.v = "1"
        sendModel.d = d.toJSONString()
        
        
        if let sendString = sendModel.toJSONString() {
            WebSocketManager.shared.senMsg(msg: sendString)
        }

    }
    
    
}

//后台不包活添加需要以下逻辑
////进入后台模式，主动断开socket，防止出现处理不了的情况
//
//func applicationWillResignActive(_ application: UIApplication) {
//       if WebSocketSingle.SingletonSocket.sharedInstance.socket.isConnected {
//            reConnectTime = 5
//            webSocket.socketDisConnect()
//        }
// }
//
////进入前台模式，主动连接socket
//    func applicationDidBecomeActive(_ application: UIApplication) {
//        //解决因为网络切换或链接不稳定问题，引起socket断连问题
//        //如果app从无网络，到回复网络，需要执行重连
//        if !WebSocketSingle.SingletonSocket.sharedInstance.socket.isConnected {
//            reConnectTime = 0
//            webSocket.socketReconnect()
//        }
//    }

//let monitor = NWPathMonitor()
//monitor.pathUpdateHandler = { path in
//    
//    DispatchQueue.main.async {
//        
//        switch path.status {
//        case .satisfied: // 已连接
//            DebugLog("Transitioned from WiFi to 4G1.")
//            break
//        case .unsatisfied:
//            DebugLog("Transitioned from WiFi to 4G2.")
//            break
//        case .requiresConnection:
//            DebugLog("Transitioned from WiFi to 4G3.")
//            break
//        default:
//            DebugLog("2222")
//        }
//        
//    }
//}
//let queue = DispatchQueue(label: "Monitor")
//monitor.start(queue: queue)
