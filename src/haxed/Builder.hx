package haxed;

import haxed.Common;
import haxed.Os;
import haxed.ClientCore;

using Lambda;
using StringTools;


class Builder {

  static var libs:String;

  /*
    Convert any library references to classpaths, so that when the haxe compiler is
    called it's not called with -lib which will relies on executing haxelib -path which
    could be the old exectutable
  */
  static function
  getLibs(d:Array<PrjVer>) {
    var
      paths = ClientCore.internalPath(d),
      sb = new StringBuf();

    for (p in paths) {
      sb.add(" -cp ");
      sb.add(p) ;
    }
    
    return sb.toString();
  }

  static function
  getCps(classpaths:Array<String>,libRoot = "") {
    var f = new StringBuf();
    if (classpaths != null) {
      for (c in classpaths) {
        var cp = (c.startsWith("./")) ? libRoot + c.substr(2) : c;
        f.add(" -cp " + cp);
      }
    } else
      f.add("");
    return f.toString();
  }

  public static function
  compile(c:Config,target:String,fromLib:Bool) {
    var
      builds = c.build(),
      libRoot:String = null;

    if (fromLib) {
      var prj = c.globals().name;
      libRoot = ClientCore
        .internalPath([{prj:prj,ver:ClientCore.currentVersion(prj),op:null}])
        .first();
    }
      
    for (b in builds) {
      if (b.name == target || b.name == null || target == "all") {
        
        var ctx = { MAIN:b.mainClass,
                LIBS:getLibs(b.depends),
                CPS:getCps(b.classPath,libRoot),
                TT:b.target,
                TARGET: b.targetFile ,
                OTHER: (b.options != null) ? b.options.join(" ") : ""};

      neko.Lib.println("Building "+target);
    
      var o = (Os.shell("haxe ::OTHER:: -main ::MAIN:: ::LIBS:: ::CPS:: -::TT:: ::TARGET::",true,ctx)),
        filtered = o.split("\n")
        .filter(function(l) {return l.trim() != ""; })
        .array()
        .join("\n");
      
    }
    }
  }
  
}
