package com.kingnare.player.mp3.sync
{
    import com.cw.war.uicenter.RenderManager;
    import mx.events.DynamicEvent;
    import com.kingnare.player.mp3.data.AudioSyncData;
    
    import flash.display.Stage;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.StatusEvent;
    import flash.events.TimerEvent;
    import flash.net.LocalConnection;
    import flash.utils.Dictionary;
    import flash.utils.Timer;
    import flash.utils.getTimer;
    
    import mx.utils.UIDUtil;
    
    /**
     * 负责连接管理
     * @author king
     * 
     */    
    public class SyncManager extends EventDispatcher
    {
        /**
         * 连接前缀
         */        
        private const PREFIX:String = "kingnare_";
        
        /**
         * 数据服务
         */        
        private var server:SyncServer;
        /**
         * 服务连接可用检测计时器
         */
        private var connTryTimer:Timer;
        /**
         * 服务连接
         */        
        private var connServer:LocalConnection;
        /**
         * 本地连接
         */        
        private var connLocal:LocalConnection;
        /**
         * 是否已经在服务中注册本地UID
         */        
        private var regAlready:Boolean = false;
        /**
         * UID
         */        
        private var _uid:String;
        /**
         * 备用客户端列表
         * 当前服务端关闭时, 下一接替者使用此数据进行初始化
         */        
        private var backcopyClients:Dictionary;
        
        /**
         * 服务检测间隔时间
         */        
        private const SERVER_CHK_INTERVAL:int = 500;
        /**
         * FPS保持器, 最小8fps
         */        
        private var fpsKeeper:RenderManager;
        
        
        public function SyncManager(stage:Stage)
        {
            trace("SyncManager");
            
            if(stage)
                fpsKeeper = new RenderManager(stage);
        }
        
        /**
         * 本地UID
         */
        public function get localUID():String
        {
            return _uid;
        }

        /**
         * 初始化 
         * 
         */        
        public function init():void
        {
            _uid = UIDUtil.createUID().replace(/-/g, "");
            
            initServerConn();
            initLocalConn();
        }
        
        /**
         * 初始化服务器连接
         * 
         */        
        private function initServerConn():void
        {
            connTryTimer = new Timer(SERVER_CHK_INTERVAL);
            connTryTimer.addEventListener(TimerEvent.TIMER, tryConnTimerHandler);
            connServer = new LocalConnection();
            connServer.allowDomain("*");
            connServer.client = this;
            connServer.addEventListener(StatusEvent.STATUS, connServerStatusHandler);
            
            tryConn();
            connTryTimer.start();
        }
        
        /**
         * 初始化本地连接
         * 
         */        
        private function initLocalConn():void
        {
            connLocal = new LocalConnection();
            connLocal.allowDomain("*");
            connLocal.client = this;
            connLocal.addEventListener(StatusEvent.STATUS, connLocalStatusHandler);
            connLocal.connect(PREFIX+"local_"+_uid);
            
            if(!regAlready)
            {
                //向服务端发送注册ID请求
                connLocal.send(PREFIX+"server", "addClient", _uid);
                regAlready = true;
            }
        }
        
        /**
         * 测试服务连接
         * @param event
         * 
         */        
        protected function tryConnTimerHandler(event:TimerEvent):void
        {
            tryConn();
        }
        
        /**
         * 如果服务连接成功, 则充当服务器负责管理其他客户端及收发命令
         * 
         */        
        private function tryConn():void
        {
            var connected:Boolean = true;
            try
            {
                connServer.connect(PREFIX+"server");
            } 
            catch(error:Error) 
            {
                //trace(error);
                connected = false;
            }
            
            if(connected)
            {
                dispatchEvent(new Event("preSetServer", false));
                server = SyncServer.getInstance();
                server.addEventListener("onSend", sendToClient);
                server.addEventListener("onHeartCheck", heartCheckHandler);
                server.addEventListener("onRemoveClient", clientRemovedHandler);
                server.addEventListener("onAddClient",clientAddedHandler);
                server.serverUID = _uid;
                server.start(backcopyClients);
                dispatchEvent(new Event("setServer", false));
            }
        }
        
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////
        //
        //                                  作为客户端时的处理方法
        //
        ///////////////////////////////////////////////////////////////////////////////////////////////////
        /**
         * 本地接收服务器调用的函数
         * @param value
         * 
         */        
        public function serverToClient(value:Object):void
        {
            var evt:DynamicEvent;
            
            switch(value.type)
            {
                case "info":
                {
                    //trace(value.value);
                    evt = new DynamicEvent("info");
                    evt.info = value.value;
                    dispatchEvent(evt);
                    break;
                }  
                case "command":
                {
                    evt = new DynamicEvent("command");
                    evt.data = value;
                    dispatchEvent(evt);
                    break;
                }
            }
        }
        
        
        protected function connLocalStatusHandler(event:StatusEvent):void
        {
            //trace("Status:",event.level, event.code, event.eventPhase, event.type);//Status: status null 2 status
        }
        
        
        
        /**
         * 向其他客户端发送数据
         * @param data
         * @param sourceUID
         * 
         */        
        public function sendClientsData(data:Object):void
        {
            connLocal.send(PREFIX+"server", "sendToAllClients", data, _uid);
        }
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////
        //
        //                                  作为服务端时的处理方法
        //
        ///////////////////////////////////////////////////////////////////////////////////////////////////
        public function get clientCount():int
        {
            var re:int = 0;
            for(var uid:String in server.clients)
            {
                re++;
            }
            
            return re;
        }
        
        /**
         * 发送消息给所有客户端
         * @param data
         * 
         */        
        public function sendToAllClients(data:Object, senderID:String):void
        {
            //trace(data);
            
            for(var uid:String in server.clients)
            {
                //后期这里要去掉此判断, 因为所有的指令都是通过服务器中心进行处理的, 即使是发送者, 也要接到服务器的指令才能行动
                //if(uid != senderID)
                //{
                    //connServer.send(server.clients[uid].connStr, "serverToClient", {type:"info", value:data});
                //}
                data.type = "command";
                connServer.send(server.clients[uid].connStr, "serverToClient", data);
            }
        }
        
        /**
         * 增加客户端
         * @param uid
         * 
         */        
        public function addClient(uid:String):void
        {
            server.addClient(uid);
        }
        
        /**
         * 心跳包检测中出现的通讯错误处理
         * @param uid
         * 
         */        
        public function communicateErrorClient(uid:String):void
        {
            server.clientConnError(uid);
        }
        
        /**
         * 心跳包检测中出现的正常连接处理
         * @param uid
         * 
         */        
        public function communicateSuccessClient(uid:String):void
        {
            server.clientConnSuccess(uid);
        }
        /**
         * 对所有连接的客户端进行心跳包检测
         * @param event
         * 
         */        
        protected function heartCheckHandler(event:Event):void
        {
            var dict:Dictionary = SyncServer.getInstance().clients;
            for each (var obj:Object in dict) 
            {
                checkClientConn(obj, dict);
            }
        }
        
        /**
         * 对单一客户端进行心跳包检测
         * @param obj
         * 
         */        
        protected function checkClientConn(obj:Object, clients:Dictionary):void
        {
            //trace("CHECKING: ", obj.uid);
            
            var connectError:Boolean = false;
            var conn:LocalConnection = new LocalConnection();
            conn.allowDomain("*");
            try
            {
                conn.connect(PREFIX+"local_"+obj.uid);
            } 
            catch(error:Error) 
            {
                connectError = true;
            }
            
            if(connectError)
            {
                //trace("连接失败, 此客户端存在");
                SyncServer.getInstance().clientConnSuccess(obj.uid);
                //向这个客户端同步客户端列表
                connServer.send(PREFIX+"local_"+obj.uid, "syncClientList", clients);
            }
            else
            {
                conn.close();
                conn = null;
                //trace("连接成功, 此客户端已经关闭");
                SyncServer.getInstance().clientConnError(obj.uid);
            }
        }
        
        /**
         * 
         * @param clients
         * 
         */        
        public function syncClientList(clients:Dictionary):void
        {
            //trace(clients);
            backcopyClients = clients;
        }
        
        /**
         * 客户注册成功事件
         * @param event
         * 
         */        
        protected function clientAddedHandler(event:DynamicEvent):void
        {
            var evt:DynamicEvent = new DynamicEvent("info");
            evt.info = "播放器 "+event.uid+" 进入.";
            dispatchEvent(evt);
            
            connServer.send(server.clients[event.uid].connStr, "serverToClient", {type:"command", command:"syncData", value:AudioSyncData.getInstance()});
        }      
        
        /**
         * 客户移除事件
         * @param event
         * 
         */        
        protected function clientRemovedHandler(event:DynamicEvent):void
        {
            var evt:DynamicEvent = new DynamicEvent("info");
            evt.info = "播放器 "+event.uid+" 退出.";
            dispatchEvent(evt);
        }
        
        /**
         * 发送数据给客户端
         * <pre>
         * e.g:
         * var evt:DynamicEvent = new DynamicEvent("onSend", true);
         * evt.uid = _clientDict[uid].uid;
         * evt.connStr = _clientDict[uid].connStr;
         * evt.data = {type:"info", value:"Hello,Client "+uid};
         * </pre>
         * @param event
         * 
         */        
        public function sendToClient(event:DynamicEvent):void
        {
            //向客户端发送数据
            connServer.send(event.connStr, "serverToClient", event.data);
        }
        
        /**
         * 连接状态事件
         * @param event
         * 
         */        
        protected function connServerStatusHandler(event:StatusEvent):void
        {
            //trace("Status:",event.level, event.code, event.eventPhase, event.type);//Status: status null 2 status
        }
    }
}