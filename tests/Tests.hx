
package tests;

//import hxjson2.JSON;


import tests.Parse;
import tests.Submit;

class Tests {
    
  static function main(){
    var r = new haxe.unit.TestRunner();
    r.add(new Parse());
    r.add(new PackageTests());
    // r.add(new Submit());
    r.run();
  }
}
