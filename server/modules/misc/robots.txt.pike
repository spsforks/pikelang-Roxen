// This is a roxen module. Copyright � 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: robots.txt.pike,v 1.1 2000/11/18 04:25:25 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST;
constant module_name = "robots.txt generator";
constant module_doc  = "Generates a robots.txt on demand from various information. "
  "If there is a robots.txt file in the server root its information will be included "
  "in the final robots.txt file. Other information incorporated is location modules "
  "that does not support directory listings and paths entered under the settings tab.";

// TODO:
// - Incorporate security information, e.g. paths requiring autharization should be in
//   the robots.txt file.
// - Dependency on the real robots.txt file appears to be broken.

void start() {

  defvar("disallow",
	 Variable.StringList( ({"/cgi-bin/"}), 0,
			      "Disallow paths", "Disallow search engine access to the "
			      "listed paths in addition to what is said in the robots.txt "
			      "and what this module derives automatically.") );
}

// The cache and it's dependencies.
string _robots;
string _internal_location;
array(array(string|function)) _loc_mods;
array(string) _loc_loc;
int _stat;

string make_rules(mapping forbidden) {
  string ret="";
  foreach(indices(forbidden), string path) {
    ret += "Disallow: "+path+"\n";
    m_delete(forbidden, path);
  }
  return ret;
}

mapping first_try(RequestID id) {

  if(id->misc->internal_get)
    return 0;

  // Should we only intercept /robots.txt or continue
  // to intercept it in all paths?
  int size=sizeof(id->not_query);
  if(id->not_query[size-11..size-1]!="/robots.txt")
    return 0;

  // Handle our cache, which depends on several different things.
  array(array(string|function)) loc_mods = id->conf->location_modules();
  if(!_robots || !equal(_loc_mods, loc_mods)) {
    _robots = 0;
    _loc_mods = loc_mods;
  }
  string internal_location = query_internal_location();
  if(!_robots || _internal_location != internal_location) {
    _robots = 0;
    _internal_location = internal_location;
  }
  mixed stat = id->conf->stat_file("/robots.txt",id);
  if(stat) stat = stat[3];
  if(!_robots || stat != _stat) {
    _robots = 0;
    _stat = stat;
  }
  if(_robots)
    return (["data":_robots]);

  string robots="# This robots file is generated by Roxen WebServer\n#\n";

  array paths = internal_location/"/";
  mapping forbidden = ([ (paths[..sizeof(paths)-3]*"/"+"/"):1 ]);

  foreach(loc_mods, array(string|function) x) {
    if(!function_object(x[1])->find_dir || !x[1](x[0],id))
      forbidden[x[0]] = 1;
  }

  map(query("disallow"), lambda(string path){ forbidden[path]=1; });

  string file = id->conf->try_get_file("/robots.txt", id);
  if(file) {
    array lines = file/"\n" - ({""});
    int in_common, common_found;
    foreach(lines, string line) {

      int type=0;
      if(has_prefix(lower_case(line), "disallow"))
	type=1;
      if(has_prefix(lower_case(line), "user-agent"))
	type=2;

      // Correct keywords with wrong case
      if(type==1 && !has_prefix(line, "Disallow"))
	line = "Disallow" + line[8..];
      if(type==2 && !has_prefix(line, "User-agent"))
	line = "User-agent" + line[10..];

      // Find the first section that applies to all user agents. Note that
      // the module does not collapse several sections with the same user
      // agent to one. If you do have more than one section with
      // User-agent: * the outcome might be a little strange, although it
      // will probably work for any decent robots.txt parser. Don't bet
      // that all robots have a decent robots.txt-parser though.
      if(type==2) {
	string star;
	sscanf(line+" ", "User-agent:%*[ \t]%s%*[ \t#]", star);
	if(star=="*")
	  in_common = 1;
	else
	  in_common = 0;
      }
      if(in_common && !common_found)
	common_found = 1;

      if(type==1) {
	string path;
	sscanf(line+" ", "Disallow:%*[ \t]%s%*[ \t#]", path);
	if(in_common && path && forbidden[path])
	  m_delete(forbidden, path);
      }

      if(common_found && !in_common && forbidden)
	robots += make_rules(forbidden);

      if(type==2) robots += "\n";
      robots += line + "\n";
    }
    if(sizeof(forbidden))
      robots += make_rules(forbidden);
  }
  else if(sizeof(forbidden)) {
    robots += "\nUser-agent: *\n";
    robots += make_rules(forbidden);
  }

  _robots = robots;

  return (["data":robots]);
}
