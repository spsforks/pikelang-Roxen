/* This is a Roxen module. Copyright © 1996 - 1999, Idonex AB
 *
 * Directory listings mark 2
 *
 * Henrik Grubbström 1997-02-13
 *
 * TODO:
 * Filter out body statements and replace them with tables to simulate
 * the correct background and fontcolors.
 *
 * Make sure links work _inside_ unfolded dokuments.
 */

constant cvs_version = "$Id: directories2.pike,v 1.17 1999/12/27 13:41:49 jhs Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

void start( int num, Configuration conf )
{
  module_dependencies (conf, ({ "foldlist", "rxmltags" }));
}

array register_module()
{
  return ({ MODULE_DIRECTORIES | MODULE_PARSER,
	      "Enhanced directory listings",
	      "This module is an experimental directory parsing module. "
	      "It pretty prints a list of files much like the ordinary "
	      "directory parsing module. "
	      "The difference is that this one uses the flik-module "
	      "for the fold/unfolding, and uses relative URL's with "
	      "the help of some new tags: "
	      "&lt;rel&gt;, &lt;arel&gt; and &lt;insert-quoted&gt;.",
	      0, 1 });
}

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["rel":"<desc cont></desc>",
		  "arel":"<desc cont></desc>",
		  "insert-quoted":"<desc tag></desc>"]);
#endif

int dirlisting_not_set()
{
  return(!QUERY(dirlisting));
}

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html",
			  "index.cgi", "index.lpc", "index.pike" }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("dirlisting", 1, "Enable directory listings", TYPE_FLAG,
	 "If set, a directory listing is generated if there is "
	 "no index file for the directory.<br>\n"
	 "If disabled, a file not found error will be generated "
	 "instead.<br>\n");

  defvar("readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings",
	 0, dirlisting_not_set);

  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' or '/' to the directory name, like "
	 "this: <a href=http://www.roxen.com//>http://www.roxen.com//</a>"
	 ". It is _very_ useful for debugging, but some people regard it as a "
	 "security hole.",
	 0, dirlisting_not_set);

  defvar("size", 1, "Include file size", TYPE_FLAG,
	 "If set, include the size of the file in the listing.",
	 0, dirlisting_not_set);
}

array(string) container_rel(string t, mapping args, string contents, RequestID id)
{
  string old_base="";
  string res;

  if (id->misc->rel_base) {
    old_base = id->misc->rel_base;
  } else {
    old_base = "";
  }
  id->misc->rel_base = old_base + args->base;

  res = parse_rxml(contents, id);

  id->misc->rel_base = old_base;
  return ({res});
}

string container_arel(string t, mapping args, string contents, RequestID id)
{
  if (id->misc->rel_base) {
    args->href = id->misc->rel_base+args->href;
  }

  return make_container("a", args, contents);
}

string tag_insert_quoted(string t, mapping args, RequestID id)
{
  if (args->file) {
    string s = id->conf->try_get_file(args->file, id);

    if (s) return html_encode_string(s);

    return rxml_error(t, "Couldn't open file \""+args->file+"\".", id);
  }
  return rxml_error(t, "File not specified.", id);
}

string find_readme(string d, RequestID id)
{
  foreach(({ "README.html", "README"}), string f) {
    string readme = id->conf->try_get_file(d+f, id);

    if (readme) {
      if (f[strlen(f)-5..] != ".html") {
	readme = "<pre>" + html_encode_string(readme) +"</pre>";
      }
      return "<hr noshade>"+readme;
    }
  }
  return "";
}

string describe_directory(string d, RequestID id)
{
  array(string) path = d/"/" - ({ "" });
  array(string) dir;
  int override = (path[-1] == ".");
  string result = "";
  int toplevel;

  path -= ({ "." });
  d = "/"+path*"/" + "/";

  dir = id->conf->find_dir(d, id);

  if (dir && sizeof(dir)) {
    dir = sort(dir);
  } else {
    dir = ({});
  }

  if(id->prestate->spartan_directories)
    return sprintf("<html><head><title>Directory listing of %s</title></head>\n"
		   "<body><h1>Directory listing of %s</h1>\n"
		   "<pre>%s</pre></body</html>\n",
		   d, d,
		   Array.map(sort(dir),
			     lambda(string f, string d, object r, RequestID id)
			     {
			       array stats = r->stat_file(d+f, id);
			       if(stats && stats[1]<0)
				 return "<a href=\""+f+"/.\">"+f+"/</a>";
			       else
				 return "<a href=\""+f+"\">"+f+"</a>";
			     }, d, id->conf, id)*"\n"+"</pre></body></html>\n");

  if(toplevel = !id->misc->dir_no_head)
  {
    id->misc->dir_no_head = 1;

    result += "<html><head><title>Directory listing of "+d+"</title></head>\n"
	      "<body>\n<h1>Directory listing of "+d+"</h1>\n<p>";

    if(QUERY(readme))
      result += find_readme(d, id);
    result += "<hr noshade><pre>\n";
  }
  result += "<foldlist folded>\n";

  foreach(sort(dir), string file) {
    array stats = id->conf->stat_file(d + file, id);
    string type = "Unknown";
    string icon;
    int len = stats?stats[1]:0;

    switch(-len) {
    case 3:
    case 2:
      type = "   "+({ 0,0,"Directory","Module location" })[-stats[1]];

      /* Directory or module */
      file += "/";
      icon = "internal-gopher-menu";

      break;
    default:
      array tmp = id->conf->type_from_filename(file,1);
      if (tmp) {
	type = tmp[0];
      }
      icon = image_from_type(type);
      if (tmp && tmp[1]) {
	type += " " + tmp[1];
      }

      break;
    }
    result += sprintf("<ft><img border=\"0\" src=\"%s\" alt=\"\"> "
		      "<arel href=\"%s\">%-40s</arel> %8s %-20s\n",
		      icon, file, file, sizetostring(len), type);

    array(string) split_type = type/"/";
    string extras = "Not supported for this file type";

    switch(split_type[0]) {
    case "text":
      if (sizeof(split_type) > 1) {
	switch(split_type[1]) {
	case "html":
	  extras = "</pre>\n<insert file=\""+d+file+"\"><pre>";
	  break;
	case "plain":
	  extras = "<insert-quoted file=\""+d+file+"\">";
	  break;
	}
      }
      break;
    case "application":
      if (sizeof(split_type) > 1) {
	switch(split_type[1]) {
	case "x-include-file":
	case "x-c-code":
	  extras = "<insert-quoted file=\""+d+file+"\">";
	  break;
	}
      }
      break;
    case "image":
      extras = "<img src=\""+ replace( d, "//", "/" ) + file +"\" border=\"0\">";
      break;
    case "   Directory":
    case "   Module location":
      extras = "<rel base=\""+file+"\">"
	"<insert nocache file=\""+d+file+".\"></rel>";
      break;
    case "Unknown":
      switch(lower_case(file)) {
      case ".cvsignore":
      case "configure":
      case "configure.in":
      case "bugs":
      case "copying":
      case "copyright":
      case "changelog":
      case "disclaimer":
      case "makefile":
      case "makefile.in":
      case "readme":
	extras = "<insert-quoted file=\""+d+file+"\">";
	break;
      }
      break;
    }
    result += "<fd>"+extras+"</fd></ft>\n";
  }
  result += "</foldlist>\n";
  if (toplevel) {
    result +="</pre></body></html>\n";
  }

  return(result);
}

string|mapping parse_directory(RequestID id)
{
  string f = id->not_query;

  /* First fix the URL
   *
   * It must end with "/" or "/."
   */
  if (!(((sizeof(f) > 1) && ((f[-1] == '/') ||
			     ((f[-2] == '/') && (f[-1] == '.')))) ||
	(f == "/"))) {
    string new_query = http_encode_string(f) + "/" +
      (id->query?("?" + id->query):"");
    return(http_redirect(new_query, id));
  }
  /* If the pathname ends with '.', and the 'override' variable
   * is set, a directory listing should be sent instead of the
   * indexfile.
   */
  if(!(sizeof(f)>1 && f[-2]=='/' && f[-1]=='.' &&
       QUERY(dirlisting) && QUERY(override))) {
    /* Handle indexfiles */
    string file, old_file;
    string old_not_query;
    mapping got;
    old_file = old_not_query = id->not_query;
    if(old_file[-1]=='.') old_file = old_file[..strlen(old_file)-2];
    foreach(query("indexfiles")-({""}), file) { // Make recursion impossible
      id->not_query = old_file+file;
      if(got = id->conf->get_file(id))
	return got;
    }
    id->not_query = old_not_query;
  }
  if (!QUERY(dirlisting)) {
    return 0;
  }
  if (f[-1] != '.') {
    f += ".";
  }
  return http_string_answer(parse_rxml(describe_directory(f, id), id));
}
