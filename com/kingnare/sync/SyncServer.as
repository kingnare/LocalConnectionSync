package com.kingnare.player.mp3.sync
{
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.TimerEvent;
    import flash.utils.Dictionary;
    import flash.utils.Timer;
    import flash.utils.getTimer;
    
    import mx.events.DynamicEvent;

    /**
     * <pre>
     * <b>负责数据调控</b>
     * 
     * 每当客户端数量有变化时, 要将客户端数据同步给所有客户端
     * 定时向所有客户端同步客户数据(防止充当服务的SWF关闭后数据丢失)
     * 定时向所有向客户端发送心跳包, 检测是否断线
     * 需要单例调用: <code>SyncServer.getInstance()</code>
     * </pre>
     * @author king
     * 
     */    
    public class SyncServer extends EventDispatcher
    {
        private static var instance:SyncServer;
        
        /**
         * 获得SyncServer的单例
         * @return 
         * 
         */        
        public static function getInstance():SyncServer
        {
            if(!instance)
            {
                instance = new SyncServer();
            }
            
            return instance;
        }
        
        /**
         * 连接前缀
         */        
        protected const PREFIX:String = "kingnare_";
        /**
         * 心跳包检测时间间隔
         */
        protected const HEART_INTERVAL:int = 1000;
        /**
         * 服务端UID
         */
        protected var _serverUID:String;
        /**
         * 客户端列表
         */
        protected var _clientDict:Dictionary;
        /**
         * 心跳包检测计时器
         */
        protected var heartTimer:Timer;
        
        /**
         * 自定义数据
         */        
        protected var userData:Object = {};
        
        public function SyncServer()
        {
            trace("SyncServer Init...");
            initServer();
        }
        
        /**
         * 服务端UID
         * @return 
         * 
         */        
        public function get serverUID():String
        {
            return _serverUID;
        }
        
        public function set serverUID(value:String):void
        {
            _serverUID = value;
        }

        /**
         * 客户端列表
         * @return 
         * 
         */        
        public function get clients():Dictionary
        {
            var dict:Dictionary = new Dictionary(true);
            for(var uid:String in _clientDict)
            {
                dict[uid] = _clientDict[uid];
            }
            return dict;
        }
        
        /**
         * 初始化服务端
         * 
         */        
        protected function initServer():void
        {
            heartTimer = new Timer(HEART_INTERVAL);
            heartTimer.addEventListener(TimerEvent.TIMER, heartCheckHandler);
            _clientDict = new Dictionary(false);
        }
        
        /**
         * 服务启动
         * 
         */        
        public function start(clientList:Dictionary):void
        {
            if(clientList)
                _clientDict = clientList;
            
            heartTimer.start();
        }
        
        /**
         * 心跳包检测事件
         * @param event
         * 
         */        
        protected function heartCheckHandler(event:TimerEvent):void
        {
            //trace("Heart Check Start! ----------------------------------------------");
            dispatchEvent(new Event("onHeartCheck", false));
        }
        
        /**
         * 客户端连接错误处理, 超过1次, 从客户端列表移除
         * @param uid
         * 
         */        
        public function clientConnError(uid:String):void
        {
            if(_clientDict[uid])
            {
                _clientDict[uid].errorCount += 1;
                
                if(_clientDict[uid].errorCount > 0)
                {
                    removeClient(uid);
                }
            }
        }
        
        /**
         * 客户端连接成功, 将错误计数器清零
         * @param uid
         * 
         */        
        public function clientConnSuccess(uid:String):void
        {
            if(_clientDict[uid])
                _clientDict[uid].errorCount = 0;
        }
        
        
        /**
         * 注册客户端
         * 派发注册成功事件
         * @param uid
         * 
         */        
        public function addClient(uid:String):void
        {
            trace("addClient UID:", uid);
            
            _clientDict[uid] = {uid:uid, connStr:PREFIX+"local_"+uid, errorCount:0, data:{}};
            
            var addEvt:DynamicEvent = new DynamicEvent("onAddClient", false);
            addEvt.uid = _clientDict[uid].uid;
            dispatchEvent(addEvt);
            
            //以下事件只是用于发布登入消息日志
            var evt:DynamicEvent = new DynamicEvent("onSend", false);
            evt.uid = _clientDict[uid].uid;
            evt.connStr = _clientDict[uid].connStr;
            evt.data = {type:"info", value:"ID "+uid};
            dispatchEvent(evt);
        }
        
        /**
         * 移除客户端
         * 派发移除成功事件
         * @param uid
         * 
         */        
        public function removeClient(uid:String):void
        {
            trace("移除客户端:", uid);
            var tmpUID:String = uid;
            _clientDict[uid] = null;
            delete _clientDict[uid];
            
            var evt:DynamicEvent = new DynamicEvent("onRemoveClient", false);
            evt.uid = tmpUID;
            dispatchEvent(evt);
        }
        
    }
}