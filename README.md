# LocalConnectionSync
LocalConnection Sync <br/>
用于本地Flash间同步.<br/>
可跨多个浏览器.<br/>

Example:
---
~~~ActionScript
var mgr:SyncManager = new SyncManager(stage); 
mgr.addEventListener("preSetServer", preSetServerHandler); 
mgr.addEventListener("setServer", setServerHandler); 
mgr.addEventListener("info", infoHandler); 
mgr.addEventListener("command", cmdHandler); 
mgr.init();

mgr.sendClientsData({command:"mycommand", value:"hello"});   

function preSetServerHandler(event:Event):void
{
  trace("Ready to change server.");
}

function setServerHandler(event:Event):void
{
  trace("This is main server now.");
}

function infoHandler(event:DynamicEvent):void
{
  trace(event.info);
}

function cmdHandler(event:DynamicEvent):void
{
  switch(event.data.command)
  {
    case "mycommand":
    {
      trace(value); //hello
      break;
    }
  }
}

~~~

