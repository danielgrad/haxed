package tools.haxelib;

class RemoteRepos {
  // files can be found in repo + "/"+REPO_URI
  public static var REPO_URI = "files"; 
  static var repos:List<String>;
  static var client:ClientCore;
  
  public static
  function init(c:ClientCore) {
    client = c;
    repos = new List<String>();
    repos.add("localhost:8200");
    repos.add("lib.ipowerhouse.com");
    //repos.add("lib.haxelib.org");
    //repos.add("www.bazaarware.com");
  }
  
  static
  function doRepo(cmd:String,prms:Dynamic,rps:List<String>,
                  userFn:String->Dynamic->Bool) {
    var next = rps.pop();
    if (next == null)
      return;

    var u = client.url(next,cmd),
      wrapper = function(d) {
      if (!userFn(next,d)) {
          // userFn did not handle repo, pass to next
          doRepo(cmd,prms,rps,userFn);
        }
      }

    // start off the server chain ...
    client.request(u,prms,wrapper);
  }
  
  public static
  function each(cmd:String,prms:Dynamic,fn:String->Dynamic->Bool) {
    if (repos == null) throw "must call RemoteRepos.init() first";
    
    var tmpRepos = Lambda.list(repos);
    doRepo(cmd,prms,tmpRepos,fn);
  }  
}

class Options {
  var switches:Hash<String>;
  
  public function new() {
    switches = new Hash<String>();
  }

  public var repo(getRepo,null):String;

  public function addSwitch(k:String,v:String) {
    // neko.Lib.println("setting "+k +"="+v);
    switches.set(k,v);
  }

  public function getRepo():String {
    return switches.get("-R");
  }

  public function getSwitch(s:String):String {
    return switches.get(s);
  }

  public function addSwitches(d:Dynamic):Dynamic {
    var n = Reflect.copy(d);
    for(s in switches.keys()) {
      Reflect.setField(n,s,switches.get(s));
    }
    return n;
  }
  
  public function flag(s:String):Bool {
    return switches.exists(s);
  }
}

enum Command {
  NOOP;
  LIST(options:Options);
  REMOVE(options:Options,pkg:String,ver:String);
  SET(options:Options,prj:String,ver:String);
  SETUP(options:Options,path:String);
  CONFIG(options:Options);
  PATH(options:Options,paths:Array<{project:String,version:String}>);
  RUN(options:Options,param:String);
  TEST(options:Options,pkg:String);
  INSTALL(options:Options,prj:String,ver:String);
  SEARCH(options:Options,query:String);
  INFO(options:Options,project:String);
  USER(options:Options,email:String);
  REGISTER(options:Options,email:String,password:String,fullName:String);
  SUBMIT(options:Options,password:String,pkgPath:String);
  DEV(options:Options,prj:String,dir:String);
  PACKAGE(options:Options,hblFile:String);
  ACCOUNT(options:Options,cemail:String,cpass:String,nemail:String,npass:String,nname:String);
  LICENSE(options:Options);
  PROJECTS(options:Options);
}
