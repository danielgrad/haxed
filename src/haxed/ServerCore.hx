
package haxed;

import haxed.Common;
import haxed.ServerData;
import haxed.ZipReader;
import haxed.License;

using Lambda;

#if php
import php.io.File;
import php.Web;
import php.Lib;
import php.db.Manager;
import db.Sqlite;
#elseif neko
import neko.io.File;
import neko.Web;
import neko.Lib;
import neko.db.Manager;
import neko.db.Sqlite;
#end

class Mail {
  public static function
  reminder(email:String) {
    var u = User.manager.search({ email : email }).first();
    if (u == null) return ERR_REMINDER;
    var password = u.pass;
#if php
    untyped __php__("mail(email, 'Haxelib Password Reminder', password, null,
   '"+ServerMain.config.adminEmail+"');");
#elseif neko
    Os.shell('send-reminder '+email+' '+ServerMain.config.adminEmail+' "'+ServerMain.config.serverName +'"');
#end
    return OK_REMINDER;
  }
}

class ServerCore {
  static var DB = "haxed.db";
  
  var dataDir:String;
  var repo:String;
  
  public function new(dd) {
    dataDir = Common.slash(dd);

    if (!Os.exists(dataDir)) throw "Datadir " + dataDir + " does not exist";
    if (!Os.exists(dataDir + DB)) throw DB+" does not exist in data dir";

    repo = dataDir + "repo/";
    Os.mkdir(repo);
      
    var db = Sqlite.open(dataDir + DB);
    Manager.cnx = db;
	Manager.initialize();
  }

  public function
  cleanup() {
    try {
      Manager.cnx.close();
      Manager.cnx = null;
    } catch(exc:Dynamic) {
      trace("problem closing db");
    }
  } 

  public function
  submit(password:String):Status {
    var
      TMP_DIR = "/tmp",
      file = null,
	  sid = null,
      bytes = 0;
    
    Web.parseMultipart(function(p,filename) {
        if( p == "file" ) {
          sid = filename;
          file = File.write(TMP_DIR+"/"+filename+".tmp",true);
        } else
          throw p+" not accepted";
      },function(data,pos,len) {
        bytes += len;
        file.writeFullBytes(haxe.io.Bytes.ofString(data),pos,len);
      });
    if( file != null ) {
      file.close();
      return processUploaded(password,TMP_DIR+"/"+sid+".tmp");
    }
    return ERR_UNKNOWN;
  }

  private function
  processUploaded(password:String,tmpFile:String):Status {
    var
      json = ZipReader.content(tmpFile,Common.CONFIG_FILE) ;
    
    if (json == null)
      return ERR_HAXELIBJSON;
        
    var
      conf = new ConfigJson(json),
      glbs = conf.globals(),
      email = glbs.authorEmail,  
      user = User.manager.search({ email : email }).first();
    
    if (user == null)
      return ERR_USER(email);

    if (user.pass != password)
      return ERR_PASSWORD("");

    var lc = checkLicense(glbs.license);
    if (lc != null)
      return lc;
    
    var prj = Project.manager.search({ name : glbs.name }).first();
    if (prj == null)
      prj = createProject(user,glbs) ;

    if(!developer(user,prj))
      return ERR_DEVELOPER;

    version(prj,glbs,json);

    Os.mv(tmpFile,repo+Common.pkgName(prj.name,glbs.version));
    
    return OK_SUBMIT;
  }
  
  public function
  register(email:String,pass:String,fullName:String):Status {
    if (user(email) != ERR_UNKNOWN)
      return ERR_REGISTERED;

    var u = new User();
    u.pass = pass;
    u.email = email;
    u.fullname = fullName;
    u.insert();
    return OK_REGISTER;
  }

  public function
  user(email:String):Status {
    var u = User.manager.search({ email : email }).first();

    if( u == null )
      return ERR_UNKNOWN;

    var
      pl = Project.manager.search({ owner : u.id }),
      projects = new Array<{name:String}>();

    for( p in pl )
      projects.push({name:p.name});

    return OK_USER({
        fullname : u.fullname,
        email : u.email,
        projects : projects
    });
  }

  function checkLicense(lic:String):Status {
    var
      licenses= License.getAll(),
      l = Lambda.filter(licenses,function(el) {
        return Reflect.field(el,"name").toUpperCase() == lic.toUpperCase();
      });

    if (l.first() == null) return ERR_LICENSE({licenses:licenses,given:lic});

    return null;

  }
                                  
  function
  createProject(u:User,g:Global):Project {
    var p = new Project();

    p.name = g.name;
    p.description = g.description;
    p.website = g.website;
    p.license = g.license;
    p.owner = u;
    p.downloads = 0;
    p.insert();

    // TODO - more than one dev!
    var devs = new List<User>();
    devs.push(u);
      
    for( u in devs ) {
      var d = new Developer();
      d.user = u;
      d.project = p;
      d.insert();
    }
      
    if (!Reflect.hasField(g, "tags")) g.tags = new Array<String>();
    for( tag in g.tags ) {
     var t = new Tag();
      t.tag = tag;
      t.project = p;
      t.insert();
    }

    return p;
  }

  function
  developer(u:User,p:Project) {
    var
      pdevs = Developer.manager.search({ project : p.id }),
      isdev = false;

    for( d in pdevs ) {
      if( d.user.id == u.id ) {
        isdev = true;
        break;
      }
    }

    return isdev;
  }

  function
  version(p:Project,glbs:Global,json:String) {
    var v = new Version();
    v.project = p;
    v.name =  Std.string(glbs.version);
    v.comments = glbs.comments;
    v.downloads = 0;
    v.date = Date.now().toString();
    v.documentation = "docs"; // TODO
    v.meta = json;
    v.insert();

    p.version = v;
    p.update();
  }

  function
  eachVersion(project:Project,fn:Version->Void) {
	for( v in Version.manager.search({ project : project.id }) )
      fn(v);
  }

  public function
  topTags(n:Int):Status {
    return OK_TOPTAGS({tags:Tag.manager.topTags(n).map(function(el) {
        return {count:el.count,tag:el.tag};
          }).array() });
  }

  static function
  getInfo(p:Project):ProjectInfo {
    p.sync();
    
    var
      u = p.owner,
    
      iv = Version.manager.search({project:p.id})
            .map(function(v) {
                 return { date: v.date, name:v.name, comments:v.comments };
              }),
      tags = Tag.manager.search({project:p.id})
     		.map(function(el){
         		return {tag:el.tag};
              });

     return {
      name: p.name,
      desc:p.description,
      website:p.website,
      owner: u.email,
      license:p.license,
      curversion:(p.version != null) ? p.version.name : "",
      tags:(tags != null) ? tags.array() : null,
      versions:(iv != null) ? iv.array() : null
      };    
  }
  
  public function
  info(prj:String):Status {
    var p = Project.manager.search({ name : prj }).first();
    
    if (p == null)
      return ERR_PROJECTNOTFOUND;
    return OK_PROJECT(getInfo(p));   
  }

  static function
  getObj(o:Dynamic,path:Array<String>):Dynamic {
    var
      hd = path.shift(),
      obj = Reflect.field(o,hd);

    if (obj == null)
      return null;

    if (path.length > 0)
      obj = getObj(obj,path);

    return obj;
  }
  
  public function
  search(query:String,opts:Options):Status {
    var found ;

    // tag query
    if (opts.getSwitch("-St") != null) {
      found = Project.manager.all()
         .map(function(p) {
            return getInfo(p);
          })
        .filter(function(p) {
            return p.tags.exists(function(el) { return el.tag == query; });
          })
        .array();
        
      if (found.length > 0)
        return OK_SEARCH(found);

      return ERR_PROJECTNOTFOUND;
    }

    // search within the json meta field
    var path = opts.getSwitch("-Sm");
    if (path != null) {
         found = Project.manager.all()
            .map(function(p) {
                var
                  j = hxjson2.JSON.decode(p.version.meta),
                  obj = getObj(j,path.split("."));

                if (obj != null) {
                  var recode = hxjson2.JSON.encode(obj);
                  if (recode.indexOf(query) != -1) {
                    return getInfo(p);
                  }
                }
                
                return {
                	name:null,
                    desc:null,
                    website:null,
                    owner:null,
                    license:null,
                    curversion:null,
                    versions:null,
                    tags:null};
                
              })
            .filter(function(el) {
                return el.name != null;
              })
           .array();

         if (found.length > 0)
           return OK_SEARCH(found);
         return ERR_PROJECTNOTFOUND;
    }

    // check description and name
    found = Project.manager.containing(query)
      .map(function(p) {
          return getInfo(p);
        }).array();

    if (found.length > 0)
      return OK_SEARCH(found);
    
     return ERR_PROJECTNOTFOUND;
  }

  public function license():Status {
    return OK_LICENSES(License.getAll());
  }
  
  public function
  account(cemail:String,cpass:String,nemail:String,npass:String,
          nName:String):Status {

    var u = User.manager.search({ email : cemail,pass: cpass }).first();

    if( u == null )
      return ERR_UNKNOWN;

    if (npass != null)
      u.pass = npass;
    if (nemail != null)
      u.email = nemail;
    if (nName != null)
      u.fullname = nName;

    u.update();
    
    return OK_ACCOUNT;
  }

  public function
  projects(options) {
    return OK_PROJECTS(
              Project.manager
                 .all()
                 .map(function(p) {
                     return getInfo(p);
                   })
                 .array());
  }

  public function
  reminder(email:String) {
    return Mail.reminder(email);
  }
}
