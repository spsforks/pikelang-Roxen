// This file is part of Roxen Webserver.
// Copyright � 1996 - 2000, Roxen IS.
// $Id: roxenlib.pike,v 1.203 2000/10/02 19:43:20 nilsson Exp $

//#pragma strict_types

#include <roxen.h>
#include <config.h>
#include <stat.h>

inherit "http";

#define roxen roxenp()

// Functions declared as static are not reachable through Roxen.pmod.
// These functions are to be considered deprecated.

static string gif_size(Stdio.File gif)
{
  array(int) xy=Dims.dims()->get(gif);
  return "width="+xy[0]+" height="+xy[1];
}

string extract_query(string from)
{
  if(!from) return "";
  if(sscanf(from, "%*s?%s%*[ \t\n]", from))
    return (from/"\r")[0];
  return "";
}

mapping build_env_vars(string f, RequestID id, string path_info)
{
  string addr=id->remoteaddr || "Internal";
  mapping(string:string) new = ([]);
  RequestID tmpid;

  if(id->query && strlen(id->query))
    new->INDEX=id->query;

  if(path_info && strlen(path_info))
  {
    string t, t2;
    if(path_info[0] != '/')
      path_info = "/" + path_info;

    t = t2 = "";

    // Kludge
    if ( ([mapping(string:mixed)]id->misc)->path_info == path_info ) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=
	id->not_query[0..strlen([string]id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;


    while(1)
    {
      // Fix PATH_TRANSLATED correctly.
      t2 = id->conf->real_file(path_info, id);
      if(t2)
      {
	new["PATH_TRANSLATED"] = t2 + t;
	break;
      }
      array(string) tmp = path_info/"/" - ({""});
      if(!sizeof(tmp))
	break;
      path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
      t = tmp[-1] +"/" + t;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;
  tmpid = id;
  while(tmpid->misc->orig)
    // internal get
    tmpid = tmpid->misc->orig;

  // Begin "SSI" vars.
  array(string) tmps;
  if(sizeof(tmps = tmpid->not_query/"/" - ({""})))
    new["DOCUMENT_NAME"]=tmps[-1];

  new["DOCUMENT_URI"]= tmpid->not_query;

  Stat tmpi;
  string real_file=tmpid->conf->real_file(tmpid->not_query||"", tmpid);
  if (real_file) {
    if(stringp(real_file)) {
      if ((tmpi = file_stat(real_file)) &&
	  sizeof(tmpi)) {
	new["LAST_MODIFIED"]=http_date(tmpi[3]);
      }
    } else {
      // Extra paranoia.
      report_error(sprintf("real_file(%O, %O) returned %O\n",
			   tmpid->not_query||"", tmpid, real_file));
    }
  }

  // End SSI vars.


  if(string tmp = id->conf->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;

  if(string tmp = id->conf->real_file("/", id))
    new["DOCUMENT_ROOT"] = tmp;

  if(!new["PATH_TRANSLATED"])
    m_delete(new, "PATH_TRANSLATED");
  else if(new["PATH_INFO"][-1] != '/' && new["PATH_TRANSLATED"][-1] == '/')
    new["PATH_TRANSLATED"] =
      new["PATH_TRANSLATED"][0..strlen(new["PATH_TRANSLATED"])-2];

  // HTTP_ style variables:

  mapping hdrs;

  if ((hdrs = id->request_headers)) {
    foreach(indices(hdrs) - ({ "authorization", "proxy-authorization",
			       "security-scheme", }), string h) {
      string hh = "HTTP_" + replace(upper_case(h),
				    ({ " ", "-", "\0", "=" }),
				    ({ "_", "_", "", "_" }));

      new[hh] = replace(hdrs[h], ({ "\0" }), ({ "" }));
    }
    if (!new["HTTP_HOST"]) {
      if(objectp(id->my_fd) && id->my_fd->query_address(1))
	new["HTTP_HOST"] = replace(id->my_fd->query_address(1)," ",":");
    }
  } else {
    if(id->misc->host)
      new["HTTP_HOST"]=id->misc->host;
    else if(objectp(id->my_fd) && id->my_fd->query_address(1))
      new["HTTP_HOST"]=replace(id->my_fd->query_address(1)," ",":");
    if(id->misc["proxy-connection"])
      new["HTTP_PROXY_CONNECTION"]=id->misc["proxy-connection"];
    if(id->misc->accept) {
      if (arrayp(id->misc->accept)) {
	new["HTTP_ACCEPT"]=id->misc->accept*", ";
      } else {
	new["HTTP_ACCEPT"]=(string)id->misc->accept;
      }
    }

    if(id->misc->cookies)
      new["HTTP_COOKIE"] = id->misc->cookies;

    if(sizeof(id->pragma))
      new["HTTP_PRAGMA"]=indices(id->pragma)*", ";

    if(stringp(id->misc->connection))
      new["HTTP_CONNECTION"]=id->misc->connection;

    new["HTTP_USER_AGENT"] = id->client*" ";

    if(id->referer && sizeof(id->referer))
      new["HTTP_REFERER"] = id->referer*"";
  }

  new["REMOTE_ADDR"]=addr;

  if(roxen->quick_ip_to_host(addr) != addr)
    new["REMOTE_HOST"]=roxen->quick_ip_to_host(addr);

  catch {
    if(id->my_fd)
      new["REMOTE_PORT"] = (id->my_fd->query_address()/" ")[1];
  };

  if (id->query && sizeof(id->query)) {
    new["QUERY_STRING"] = id->query;
  }

  if(id->realauth)
    new["REMOTE_USER"] = (id->realauth / ":")[0];
  if(id->auth && id->auth[0])
    new["ROXEN_AUTHENTICATED"] = "1"; // User is valid with the Roxen userdb.
  if(id->data && strlen(id->data))
  {
    if(id->misc["content-type"])
      new["CONTENT_TYPE"]=id->misc["content-type"];
    else
      new["CONTENT_TYPE"]="application/x-www-form-urlencoded";
    new["CONTENT_LENGTH"]=(string)strlen(id->data);
  }

  if(id->query && strlen(id->query))
    new["INDEX"]=id->query;

  new["REQUEST_METHOD"]=id->method||"GET";
  new["SERVER_PORT"] = id->my_fd?
    ((id->my_fd->query_address(1)||"foo unknown")/" ")[1]: "Internal";

  return new;
}

mapping build_roxen_env_vars(RequestID id)
{
  mapping(string:string) new = ([]);
  string tmp;

  if(id->cookies->RoxenUserID)
    new["ROXEN_USER_ID"]=id->cookies->RoxenUserID;

  new["COOKIES"] = "";
  foreach(indices(id->cookies), tmp)
    {
      new["COOKIE_"+tmp] = id->cookies[tmp];
      new["COOKIES"]+= tmp+" ";
    }

  foreach(indices(id->config), tmp)
    {
      new["WANTS_"+replace(tmp, " ", "_")]="true";
      if(new["CONFIGS"])
	new["CONFIGS"] += " " + replace(tmp, " ", "_");
      else
	new["CONFIGS"] = replace(tmp, " ", "_");
    }

  foreach(indices(id->variables), tmp)
  {
    string name = replace(tmp," ","_");
    if (id->variables[tmp] && (sizeof(id->variables[tmp]) < 8192)) {
      /* Some shells/OS's don't like LARGE environment variables */
      new["QUERY_"+name] = replace(id->variables[tmp],"\000"," ");
      new["VAR_"+name] = replace(id->variables[tmp],"\000","#");
    }
    if(new["VARIABLES"])
      new["VARIABLES"]+= " " + name;
    else
      new["VARIABLES"]= name;
  }

  foreach(indices(id->prestate), tmp)
  {
    new["PRESTATE_"+replace(tmp, " ", "_")]="true";
    if(new["PRESTATES"])
      new["PRESTATES"] += " " + replace(tmp, " ", "_");
    else
      new["PRESTATES"] = replace(tmp, " ", "_");
  }

  foreach(indices(id->supports), tmp)
  {
    new["SUPPORTS_"+replace(tmp-",", " ", "_")]="true";
    if (new["SUPPORTS"])
      new["SUPPORTS"] += " " + replace(tmp, " ", "_");
    else
      new["SUPPORTS"] = replace(tmp, " ", "_");
  }
  return new;
}

string decode_mode(int m)
{
  string s;
  s="";

  if(S_ISLNK(m))  s += "Symbolic link";
  else if(S_ISREG(m))  s += "File";
  else if(S_ISDIR(m))  s += "Dir";
  else if(S_ISCHR(m))  s += "Special";
  else if(S_ISBLK(m))  s += "Device";
  else if(S_ISFIFO(m)) s += "FIFO";
  else if(S_ISSOCK(m)) s += "Socket";
  else if((m&0xf000)==0xd000) s+="Door";
  else s+= "Unknown";

  s+=", ";

  if(S_ISREG(m) || S_ISDIR(m))
  {
    s+="<tt>";
    if(m&S_IRUSR) s+="r"; else s+="-";
    if(m&S_IWUSR) s+="w"; else s+="-";
    if(m&S_IXUSR) s+="x"; else s+="-";

    if(m&S_IRGRP) s+="r"; else s+="-";
    if(m&S_IWGRP) s+="w"; else s+="-";
    if(m&S_IXGRP) s+="x"; else s+="-";

    if(m&S_IROTH) s+="r"; else s+="-";
    if(m&S_IWOTH) s+="w"; else s+="-";
    if(m&S_IXOTH) s+="x"; else s+="-";
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
}

int _match(string w, array (string) a)
{
  if(!stringp(w)) // Internal request..
    return -1;
  foreach(a, string q)
    if(stringp(q) && strlen(q) && glob(q, w))
      return 1;
}

string short_name(string long_name)
{
  long_name = replace(long_name, " ", "_");
  return lower_case(long_name);
}

string strip_config(string from)
{
  sscanf(from, "/<%*s>%s", from);
  return from;
}

string strip_prestate(string from)
{
  sscanf(from, "/(%*s)%s", from);
  return from;
}

#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]

string parse_rxml(string what, RequestID id,
			 void|Stdio.File file,
			 void|mapping(string:mixed) defines)
{
  if(!objectp(id)) error("No id passed to parse_rxml\n");
  return id->conf->parse_rxml( what, id, file, defines );
}

constant iso88591
=([ "&nbsp;":   "�",
    "&iexcl;":  "�",
    "&cent;":   "�",
    "&pound;":  "�",
    "&curren;": "�",
    "&yen;":    "�",
    "&brvbar;": "�",
    "&sect;":   "�",
    "&uml;":    "�",
    "&copy;":   "�",
    "&ordf;":   "�",
    "&laquo;":  "�",
    "&not;":    "�",
    "&shy;":    "�",
    "&reg;":    "�",
    "&macr;":   "�",
    "&deg;":    "�",
    "&plusmn;": "�",
    "&sup2;":   "�",
    "&sup3;":   "�",
    "&acute;":  "�",
    "&micro;":  "�",
    "&para;":   "�",
    "&middot;": "�",
    "&cedil;":  "�",
    "&sup1;":   "�",
    "&ordm;":   "�",
    "&raquo;":  "�",
    "&frac14;": "�",
    "&frac12;": "�",
    "&frac34;": "�",
    "&iquest;": "�",
    "&Agrave;": "�",
    "&Aacute;": "�",
    "&Acirc;":  "�",
    "&Atilde;": "�",
    "&Auml;":   "�",
    "&Aring;":  "�",
    "&AElig;":  "�",
    "&Ccedil;": "�",
    "&Egrave;": "�",
    "&Eacute;": "�",
    "&Ecirc;":  "�",
    "&Euml;":   "�",
    "&Igrave;": "�",
    "&Iacute;": "�",
    "&Icirc;":  "�",
    "&Iuml;":   "�",
    "&ETH;":    "�",
    "&Ntilde;": "�",
    "&Ograve;": "�",
    "&Oacute;": "�",
    "&Ocirc;":  "�",
    "&Otilde;": "�",
    "&Ouml;":   "�",
    "&times;":  "�",
    "&Oslash;": "�",
    "&Ugrave;": "�",
    "&Uacute;": "�",
    "&Ucirc;":  "�",
    "&Uuml;":   "�",
    "&Yacute;": "�",
    "&THORN;":  "�",
    "&szlig;":  "�",
    "&agrave;": "�",
    "&aacute;": "�",
    "&acirc;":  "�",
    "&atilde;": "�",
    "&auml;":   "�",
    "&aring;":  "�",
    "&aelig;":  "�",
    "&ccedil;": "�",
    "&egrave;": "�",
    "&eacute;": "�",
    "&ecirc;":  "�",
    "&euml;":   "�",
    "&igrave;": "�",
    "&iacute;": "�",
    "&icirc;":  "�",
    "&iuml;":   "�",
    "&eth;":    "�",
    "&ntilde;": "�",
    "&ograve;": "�",
    "&oacute;": "�",
    "&ocirc;":  "�",
    "&otilde;": "�",
    "&ouml;":   "�",
    "&divide;": "�",
    "&oslash;": "�",
    "&ugrave;": "�",
    "&uacute;": "�",
    "&ucirc;":  "�",
    "&uuml;":   "�",
    "&yacute;": "�",
    "&thorn;":  "�",
    "&yuml;":   "�",
]);

constant international
=([ "&OElig;":  "\x0152",
    "&oelig;":  "\x0153",
    "&Scaron;": "\x0160",
    "&scaron;": "\x0161",
    "&Yuml;":   "\x0178",
    "&circ;":   "\x02C6",
    "&tilde;":  "\x02DC",
    "&ensp;":   "\x2002",
    "&emsp;":   "\x2003",
    "&thinsp;": "\x2009",
    "&zwnj;":   "\x200C",
    "&zwj;":    "\x200D",
    "&lrm;":    "\x200E",
    "&rlm;":    "\x200F",
    "&ndash;":  "\x2013",
    "&mdash;":  "\x2014",
    "&lsquo;":  "\x2018",
    "&rsquo;":  "\x2019",
    "&sbquo;":  "\x201A",
    "&ldquo;":  "\x201C",
    "&rdquo;":  "\x201D",
    "&bdquo;":  "\x201E",
    "&dagger;": "\x2020",
    "&Dagger;": "\x2021",
    "&permil;": "\x2030",
    "&lsaquo;": "\x2039",
    "&rsaquo;": "\x203A",
    "&euro;":   "\x20AC",
]);

constant symbols
=([ "&fnof;":     "\x0192",
    "&thetasym;": "\x03D1",
    "&upsih;":    "\x03D2",
    "&piv;":      "\x03D6",
    "&bull;":     "\x2022",
    "&hellip;":   "\x2026",
    "&prime;":    "\x2032",
    "&Prime;":    "\x2033",
    "&oline;":    "\x203E",
    "&frasl;":    "\x2044",
    "&weierp;":   "\x2118",
    "&image;":    "\x2111",
    "&real;":     "\x211C",
    "&trade;":    "\x2122",
    "&alefsym;":  "\x2135",
    "&larr;":     "\x2190",
    "&uarr;":     "\x2191",
    "&rarr;":     "\x2192",
    "&darr;":     "\x2193",
    "&harr;":     "\x2194",
    "&crarr;":    "\x21B5",
    "&lArr;":     "\x21D0",
    "&uArr;":     "\x21D1",
    "&rArr;":     "\x21D2",
    "&dArr;":     "\x21D3",
    "&hArr;":     "\x21D4",
    "&forall;":   "\x2200",
    "&part;":     "\x2202",
    "&exist;":    "\x2203",
    "&empty;":    "\x2205",
    "&nabla;":    "\x2207",
    "&isin;":     "\x2208",
    "&notin;":    "\x2209",
    "&ni;":       "\x220B",
    "&prod;":     "\x220F",
    "&sum;":      "\x2211",
    "&minus;":    "\x2212",
    "&lowast;":   "\x2217",
    "&radic;":    "\x221A",
    "&prop;":     "\x221D",
    "&infin;":    "\x221E",
    "&ang;":      "\x2220",
    "&and;":      "\x2227",
    "&or;":       "\x2228",
    "&cap;":      "\x2229",
    "&cup;":      "\x222A",
    "&int;":      "\x222B",
    "&there4;":   "\x2234",
    "&sim;":      "\x223C",
    "&cong;":     "\x2245",
    "&asymp;":    "\x2248",
    "&ne;":       "\x2260",
    "&equiv;":    "\x2261",
    "&le;":       "\x2264",
    "&ge;":       "\x2265",
    "&sub;":      "\x2282",
    "&sup;":      "\x2283",
    "&nsub;":     "\x2284",
    "&sube;":     "\x2286",
    "&supe;":     "\x2287",
    "&oplus;":    "\x2295",
    "&otimes;":   "\x2297",
    "&perp;":     "\x22A5",
    "&sdot;":     "\x22C5",
    "&lceil;":    "\x2308",
    "&rceil;":    "\x2309",
    "&lfloor;":   "\x230A",
    "&rfloor;":   "\x230B",
    "&lang;":     "\x2329",
    "&rang;":     "\x232A",
    "&loz;":      "\x25CA",
    "&spades;":   "\x2660",
    "&clubs;":    "\x2663",
    "&hearts;":   "\x2665",
    "&diams;":    "\x2666",
]);

constant greek
= ([ "&Alpha;":   "\x391",
     "&Beta;":    "\x392",
     "&Gamma;":   "\x393",
     "&Delta;":   "\x394",
     "&Epsilon;": "\x395",
     "&Zeta;":    "\x396",
     "&Eta;":     "\x397",
     "&Theta;":   "\x398",
     "&Iota;":    "\x399",
     "&Kappa;":   "\x39A",
     "&Lambda;":  "\x39B",
     "&Mu;":      "\x39C",
     "&Nu;":      "\x39D",
     "&Xi;":      "\x39E",
     "&Omicron;": "\x39F",
     "&Pi;":      "\x3A0",
     "&Rho;":     "\x3A1",
     "&Sigma;":   "\x3A3",
     "&Tau;":     "\x3A4",
     "&Upsilon;": "\x3A5",
     "&Phi;":     "\x3A6",
     "&Chi;":     "\x3A7",
     "&Psi;":     "\x3A8",
     "&Omega;":   "\x3A9",
     "&alpha;":   "\x3B1",
     "&beta;":    "\x3B2",
     "&gamma;":   "\x3B3",
     "&delta;":   "\x3B4",
     "&epsilon;": "\x3B5",
     "&zeta;":    "\x3B6",
     "&eta;":     "\x3B7",
     "&theta;":   "\x3B8",
     "&iota;":    "\x3B9",
     "&kappa;":   "\x3BA",
     "&lambda;":  "\x3BB",
     "&mu;":      "\x3BC",
     "&nu;":      "\x3BD",
     "&xi;":      "\x3BE",
     "&omicron;": "\x3BF",
     "&pi;":      "\x3C0",
     "&rho;":     "\x3C1",
     "&sigmaf;":  "\x3C2",
     "&sigma;":   "\x3C3",
     "&tau;":     "\x3C4",
     "&upsilon;": "\x3C5",
     "&phi;":     "\x3C6",
     "&chi;":     "\x3C7",
     "&psi;":     "\x3C8",
     "&omega;":   "\x3C9",
]);

constant replace_entities=indices( iso88591 )+indices( international )+indices( symbols )+indices( greek )+({"&lt;","&gt;","&amp;","&quot;","&apos;","&#x22;","&#34;","&#39;","&#0;"});
constant replace_values  =values( iso88591 )+values( international )+values( symbols )+values( greek )+({"<",">","&","\"","\'","\"","\"","\'","\000"});

constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
constant empty_strings = ({""})*sizeof(safe_characters);

int is_safe_string(string in)
{
  return strlen(in) && !strlen(replace(in, safe_characters, empty_strings));
}

string make_entity( string q )
{
  return "&"+q+";";
}

string make_tag_attributes(mapping(string:string) in)
{
  if(!in || !sizeof(in)) return "";
  string res="";
  foreach(indices(in), string a)
    res+=" "+a+"=\""+html_encode_string((string)in[a])+"\"";
  return res;
}

string make_tag(string name, mapping(string:string) args, void|int xml)
//! Returns an empty element tag `name', with the tag arguments dictated
//! by the mapping `args'. If the flag xml is set, slash character will be
//! added in the end of the tag. Use RXML.t_xml->format_tag(name, args) instead.
{
  return "<"+name+make_tag_attributes(args,xml)+(xml?" /":"")+">";
}

string make_container(string name, mapping(string:string) args, string content)
//! Returns a container tag `name' encasing the string `content', with
//! the tag arguments dictated by the mapping `args'. Use
//! RXML.t_xml->format_tag(name, args, content) instead.
{
  if(args["/"]=="/") m_delete(args, "/");
  return make_tag(name,args)+content+"</"+name+">";
}

string dirname( string file )
{
  if(!file)
    return "/";
  if(file[-1] == '/')
    if(strlen(file) > 1)
      return file[0..strlen(file)-2];
    else
      return file;
  array tmp=file/"/";
  if(sizeof(tmp)==2 && tmp[0]=="")
    return "/";
  return tmp[0..sizeof(tmp)-2]*"/";
}

string conv_hex( int color )
{
  return sprintf("#%06X", color);
}

string add_config( string url, array config, multiset prestate )
{
  if(!sizeof(config))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/<" + config * "," + ">" + add_pre_state(url, prestate);
}

string msectos(int t)
{
  if(t<1000) /* One sec. */
  {
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  /* One minute */
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { /* One hour */
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  }
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

string extension( string f, RequestID|void id)
{
  string ext, key;
  if(!f || !strlen(f)) return "";
  if(!id || !(ext = [string]id->misc[key="_ext_"+f])) {
    sscanf(reverse(f), "%s.%*s", ext);
    if(!ext) ext = "";
    else {
      ext = lower_case(reverse(ext));
      if(sizeof (ext) && (ext[-1] == '~' || ext[-1] == '#'))
        ext = ext[..strlen(ext)-2];
    }
    if(id) id->misc[key]=ext;
  }
  return ext;
}

int backup_extension( string f )
{
  if(!strlen(f))
    return 1;
  return (f[-1] == '#' || f[-1] == '~' || f[0..1]==".#"
	  || (f[-1] == 'd' && sscanf(f, "%*s.old"))
	  || (f[-1] == 'k' && sscanf(f, "%*s.bak")));
}

static int ipow(int what, int how)
{
  return (int)pow(what, how);
}

array(string) win_drive_prefix(string path)
//! Splits path into ({ prefix, path }) array. Prefix is "" for paths on
//! non-Windows systems or when no proper drive prefix is found.
{
#ifdef __NT__
  string prefix;
  if (sscanf(path, "\\\\%s%*[\\/]%s", prefix, string path_end) == 3) {
    return ({ "\\\\" + prefix, "/" + path_end });
  } else if (sscanf(path, "%1s:%s", prefix, path) == 2) {
    return ({ prefix + ":", path });
  }
#endif
  return ({ "", path });
}

string simplify_path(string file)
//! This one will remove .././ etc. in the path. The returned value
//! will be a canonic representation of the given path.
{
  // Faster for most cases since "//", "./" or "../" rarely exists.
  if(!strlen(file) || (!has_value(file, "./") && (file[-1] != '.') &&
		       !has_value (file, "//")))
    return file;

  int t2,t1;

  [string prefix, file] = win_drive_prefix(file);

  if(file[0] != '/')
    t2 = 1;

  if(strlen(file) > 1
     && file[-2]=='/'
     && ((file[-1] == '/') || (file[-1]=='.'))
	)
    t1=1;

  file=combine_path("/", file);

  if(t1) file += "/.";
  if(t2) return prefix + file[1..];

  return prefix + file;
}

string short_date(int timestamp)
//! Returns a short date string from a time-int
{
  int date = time(1);

  if(ctime(date)[20..23] != ctime(timestamp)[20..23])
    return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[20..23];

  return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[11..15];
}

string int2roman(int m)
{
  string res="";
  if (m>10000000||m<0) return "que";
  while (m>999) { res+="M"; m-=1000; }
  if (m>899) { res+="CM"; m-=900; }
  else if (m>499) { res+="D"; m-=500; }
  else if (m>399) { res+="CD"; m-=400; }
  while (m>99) { res+="C"; m-=100; }
  if (m>89) { res+="XC"; m-=90; }
  else if (m>49) { res+="L"; m-=50; }
  else if (m>39) { res+="XL"; m-=40; }
  while (m>9) { res+="X"; m-=10; }
  if (m>8) return res+"IX";
  else if (m>4) { res+="V"; m-=5; }
  else if (m>3) return res+"IV";
  while (m) { res+="I"; m--; }
  return res;
}

string number2string(int n, mapping m, array|function names)
{
  string s;
  switch (m->type)
  {
  case "string":
     if (functionp(names)) {
       s=([function(int:string)]names)(n);
       break;
     }
     if (n<0 || n>=sizeof(names))
       s="";
     else
       s=([array(string)]names)[n];
     break;
  case "roman":
    s=int2roman(n);
    break;
  default:
    return (string)n;
  }

  switch(m["case"]) {
    case "lower": return lower_case(s);
    case "upper": return upper_case(s);
    case "capitalize": return capitalize(s);
  }

#ifdef old_rxml_compat
  if (m->lower) return lower_case(s);
  if (m->upper) return upper_case(s);
  if (m->cap||m->capitalize) return capitalize(s);
#endif

  return s;
}

string image_from_type( string t )
{
  if(t)
  {
    sscanf(t, "%s/", t);
    switch(t)
    {
     case "audio":
     case "sound":
      return "internal-gopher-sound";
     case "image":
      return "internal-gopher-image";
     case "application":
      return "internal-gopher-binary";
     case "text":
      return "internal-gopher-text";
    }
  }
  return "internal-gopher-unknown";
}

#define  PREFIX ({ "bytes", "kb", "Mb", "Gb", "Tb", "Hb" })
string sizetostring( int size )
  //! Returns the size as a memory size string with suffix,
  //! e.g. 43210 is converted into "42.2 kb.
{
  if(size<0) return "--------";
  float s = (float)size;
  size=0;

  if(s<1024.0) return (int)s+" bytes";
  while( s > 1024.0 )
  {
    s /= 1024.0;
    size ++;
  }
  return sprintf("%.1f %s", s, PREFIX[ size ]);
}

mapping proxy_auth_needed(RequestID id)
{
  int|mapping res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return [mapping]res;
  }
  return 0;
}

// Please use __FILE__ if possible.
string program_filename()
{
  return master()->program_name(this_object())||"";
}

string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

string html_encode_string(string str)
//! Encodes `str' for use as a literal in html text.
{
  return replace(str, ({"&", "<", ">", "\"", "\'", "\000" }),
		 ({"&amp;", "&lt;", "&gt;", "&#34;", "&#39;", "&#0;"}));
}

string html_decode_string(string str)
//! Decodes `str', opposite to <ref>html_encode_string()</ref>
{
  return replace(str, replace_entities, replace_values);
}

string html_encode_tag_value(string str)
//! Encodes `str' for use as a value in an html tag.
{
  // '<' is not allowed in attribute values in XML 1.0.
  return "\"" + replace(str, ({"&", "\"", "<"}), ({"&amp;", "&quot;", "&lt;"})) + "\"";
}

string strftime(string fmt, int t)
//! Encodes the time `t' according to the format string `fmt'.
{
  if(!sizeof(fmt)) return "";
  mapping lt = localtime(t);
  fmt=replace(fmt, "%%", "\0");
  array(string) a = fmt/"%";
  string res = a[0];

  foreach(a[1..], string key) {
    if(key=="") continue;
    switch(key[0]) {
    case 'a':	// Abbreviated weekday name
      res += ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[lt->wday];
      break;
    case 'A':	// Weekday name
      res += ({ "Sunday", "Monday", "Tuesday", "Wednesday",
		"Thursday", "Friday", "Saturday" })[lt->wday];
      break;
    case 'b':	// Abbreviated month name
    case 'h':	// Abbreviated month name
      res += ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[lt->mon];
      break;
    case 'B':	// Month name
      res += ({ "January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December" })[lt->mon];
      break;
    case 'c':	// Date and time
      res += strftime(sprintf("%%a %%b %02d  %02d:%02d:%02d %04d",
			      lt->mday, lt->hour, lt->min, lt->sec, 1900 + lt->year), t);
      break;
    case 'C':	// Century number; 0-prefix
      res += sprintf("%02d", 19 + lt->year/100);
      break;
    case 'd':	// Day of month [1,31]; 0-prefix
      res += sprintf("%02d", lt->mday);
      break;
    case 'D':	// Date as %m/%d/%y
      res += strftime("%m/%d/%y", t);
      break;
    case 'e':	// Day of month [1,31]; space-prefix
      res += sprintf("%2d", lt->mday);
      break;
    case 'E':
    case 'O':
      key = key[1..]; // No support for E or O extension.
      break;
    case 'H':	// Hour (24-hour clock) [0,23]; 0-prefix
      res += sprintf("%02d", lt->hour);
      break;
    case 'I':	// Hour (12-hour clock) [1,12]; 0-prefix
      res += sprintf("%02d", 1 + (lt->hour + 11)%12);
      break;
    case 'j':	// Day number of year [1,366]; 0-prefix
      res += sprintf("%03d", lt->yday);
      break;
    case 'k':	// Hour (24-hour clock) [0,23]; space-prefix
      res += sprintf("%2d", lt->hour);
      break;
    case 'l':	// Hour (12-hour clock) [1,12]; space-prefix
      res += sprintf("%2d", 1 + (lt->hour + 11)%12);
      break;
    case 'm':	// Month number [1,12]; 0-prefix
      res += sprintf("%02d", lt->mon + 1);
      break;
    case 'M':	// Minute [00,59]; 0-prefix
      res += sprintf("%02d", lt->min);
      break;
    case 'n':	// Newline
      res += "\n";
      break;
    case 'p':	// a.m. or p.m.
      res += lt->hour<12 ? "a.m." : "p.m.";
      break;
    case 'r':	// Time in 12-hour clock format with %p
      res += strftime("%l:%M %p", t);
      break;
    case 'R':	// Time as %H:%M
      res += sprintf("%02d:%02d", lt->hour, lt->min);
      break;
    case 'S':	// Seconds [00,61]; 0-prefix
      res += sprintf("%02", lt->sec);
      break;
    case 't':	// Tab
      res += "\t";
      break;
    case 'T':	// Time as %H:%M:%S
    case 'X':
      res += sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'u':	// Weekday as a decimal number [1,7], Sunday == 1
      res += sprintf("%d", lt->wday + 1);
      break;
    case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
      res += sprintf("%d", lt->wday);
      break;
    case 'x':	// Date
      res += strftime("%a %b %d %Y", t);
      break;
    case 'y':	// Year [00,99]; 0-prefix
      res += sprintf("%02d", lt->year % 100);
      break;
    case 'Y':	// Year [0000.9999]; 0-prefix
      res += sprintf("%04d", 1900 + lt->year);
      break;

    case 'U':	// Week number of year as a decimal number [00,53],
		// with Sunday as the first day of week 1; 0-prefix
      res += sprintf("%02d", ((lt->yday-1+lt->wday)/7));
      break;
    case 'V':	// ISO week number of the year as a decimal number [01,53]; 0-prefix
      res += sprintf("%02d", Calendar.ISO.Second(t)->week_no());
      break;
    case 'W':	// Week number of year as a decimal number [00,53],
		// with Monday as the first day of week 1; 0-prefix
      res += sprintf("%02d", ((lt->yday+(5+lt->wday)%7)/7));
      break;
    case 'Z':	/* FIXME: Time zone name or abbreviation, or no bytes if
		 * no time zone information exists
		 */
    }
    res+=key[1..];
  }
  return replace(res, "\0", "%");
}

RoxenModule get_module (string modname)
//! Resolves a string as returned by get_modname to a module object if
//! one exists.
{
  string cname, mname;
  int mid = 0;

  if (sscanf (modname, "%s/%s", cname, mname) != 2 ||
      !sizeof (cname) || !sizeof(mname)) return 0;
  sscanf (mname, "%s#%d", mname, mid);

  if (Configuration conf = roxen->get_configuration (cname))
    if (mapping moddata = conf->modules[mname])
      return moddata->copies[mid];

  return 0;
}

string get_modname (RoxenModule module)
//! Returns a string uniquely identifying the given module on the form
//! `<config name>/<module short name>#<copy>'.
{
  if (!module) return 0;

  if (Configuration conf = module->my_configuration())
    if (string mname = conf->otomod[module])
      return conf->name + "/" + mname;

  return 0;
}

string get_modfullname (RoxenModule module)
//! This determines the full module (human-readable) name in
//! approximately the same way as the config UI. Note that the
//! returned string is text/html.
{
  if (module) {
    string|mapping(string:string) name = 0;
    if (module->query)
      catch {
	mixed res = module->query ("_name");
	if (res) name = (string) res;
      };
    if (!(name && sizeof (name)) && module->query_name)
      name = module->query_name();
    if (!(name && sizeof (name)))
      name = [string]module->register_module()[1];
    if (mappingp (name))
      // FIXME: Use locale from an id object in some standard way.
      name = name->standard;
    return name;
  }
  else return 0;
}

string roxen_encode( string val, string encoding )
//! Quote content in a multitude of ways. Used primarily by entity quoting.
{
  switch (encoding) {
   case "":
   case "none":
     //! No encoding
     return val;

   case "http":
     //! HTTP encoding.
     return http_encode_string (val);

   case "cookie":
     //! HTTP cookie encoding.
     return http_encode_cookie (val);

   case "url":
     //! HTTP encoding, including special characters in URL:s.
     return http_encode_url (val);

   case "html":
     //! For generic html text and in tag arguments.
     return html_encode_string (val);

   case "dtag":
     //! Quote quotes for a double quoted tag argument. Only
     //! for internal use, i.e. in arguments to other RXML tags.
     return replace (val, "\"", "\"'\"'\"");

   case "stag":
     //! Quote quotes for a single quoted tag argument. Only
     //! for internal use, i.e. in arguments to other RXML tags.
     return replace(val, "'", "'\"'\"'");

   case "pike":
     //! Pike string quoting (e.g. for use in a <pike> tag).
     return replace (val,
		    ({ "\"", "\\", "\n" }),
		    ({ "\\\"", "\\\\", "\\n" }));

   case "js":
   case "javascript":
     //! Javascript string quoting.
     return replace (val,
		    ({ "\b", "\014", "\n", "\r", "\t", "\\", "'", "\"" }),
		    ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
		       "\\'", "\\\"" }));

   case "mysql":
     //! MySQL quoting.
     return replace (val,
		    ({ "\"", "'", "\\" }),
		    ({ "\\\"" , "\\'", "\\\\" }) );

   case "sql":
   case "oracle":
     //! SQL/Oracle quoting.
     return replace (val, "'", "''");

   case "mysql-dtag":
     //! MySQL quoting followed by dtag quoting.
     return replace (val,
		    ({ "\"", "'", "\\" }),
		    ({ "\\\"'\"'\"", "\\'", "\\\\" }));

   case "mysql-pike":
     //! MySQL quoting followed by Pike string quoting.
     return replace (val,
		    ({ "\"", "'", "\\", "\n" }),
		    ({ "\\\\\\\"", "\\\\'",
		       "\\\\\\\\", "\\n" }) );

   case "sql-dtag":
   case "oracle-dtag":
     //! SQL/Oracle quoting followed by dtag quoting.
     return replace (val,
		    ({ "'", "\"" }),
		    ({ "''", "\"'\"'\"" }) );

   default:
     //! Unknown encoding. Let the caller decide what to do with it.
     return 0;
  }
}

static int compare( string a, string b )
// This method needs lot of work... but so do the rest of the system too
// RXML needs types
{
  if (!a)
    if (b)
      return -1;
    else
      return 0;
  else if (!b)
    return 1;
  else if ((string)(int)a == a && (string)(int)b == b)
    if ((int )a > (int )b)
      return 1;
    else if ((int )a < (int )b)
      return -1;
    else
      return 0;
  else
    if (a > b)
      return 1;
    else if (a < b)
      return -1;
    else
      return 0;
}

static string do_output_tag( mapping(string:string) args, array(mapping(string:string)) var_arr,
			     string contents, RequestID id )
//! Method for use by tags that replace variables in their content,
//! like formoutput, sqloutput and others.
//!
//! NOTE: This function is obsolete. This kind of functionality is now
//! provided intrinsicly by the new RXML parser framework, in a way
//! that avoids many of the problems that stems from this function.
{
  string quote = args->quote || "#";
  mapping(string:string) other_vars = [mapping(string:string)]id->misc->variables;
  string new_contents = "", unparsed_contents = "";
  int first;

  // multi_separator must default to \000 since one sometimes need to
  // pass multivalues through several output tags, and it's a bit
  // tricky to set it to \000 in a tag..
  string multi_separator = args->multi_separator || args->multisep || "\000";

  if (args->preprocess)
    contents = parse_rxml( contents, id );

  switch (args["debug-input"]) {
    case 0: break;
    case "log":
      report_debug ("tag input: " + contents + "\n");
      break;
    case "comment":
      new_contents = "<!--\n" + html_encode_string (contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" +
	html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  if (args->sort)
  {
    array(string) order = args->sort / "," - ({ "" });
    var_arr = Array.sort_array( var_arr,
				lambda (mapping(string:string) m1,
					mapping(string:string) m2)
				{
				  int tmp;

				  foreach (order, string field)
				  {
				    int tmp;

				    if (field[0] == '-')
				      tmp = compare( m2[field[1..]],
						     m1[field[1..]] );
				    else if (field[0] == '+')
				      tmp = compare( m1[field[1..]],
						     m2[field[1..]] );
				    else
				      tmp = compare( m1[field], m2[field] );
				    if (tmp == 1)
				      return 1;
				    else if (tmp == -1)
				      return 0;
				  }
				  return 0;
				} );
  }

  if (args->range)
  {
    int begin, end;
    string b, e;


    sscanf( args->range, "%s..%s", b, e );
    if (!b || b == "")
      begin = 0;
    else
      begin = (int )b;
    if (!e || e == "")
      end = -1;
    else
      end = (int )e;

    if (begin < 0)
      begin += sizeof( var_arr );
    if (end < 0)
      end += sizeof( var_arr );
    if (begin > end)
      return "";
    if (begin < 0)
      if (end < 0)
	return "";
      else
	begin = 0;
    var_arr = var_arr[begin..end];
  }

  first = 1;
  foreach (var_arr, mapping(string:string) vars)
  {
    if (args->set)
      foreach (indices (vars), string var) {
	array|string val = vars[var];
	if (!val) val = args->zero || "";
	else {
	  if (arrayp( val ))
	    val = Array.map (val, lambda (mixed v) {return (string) v;}) *
	      multi_separator;
	  else
	    val = replace ((string) val, "\000", multi_separator);
	  if (!sizeof (val)) val = args->empty || "";
	}
	id->variables[var] = [string]val;
      }

    id->misc->variables = vars;

    if (!args->replace || lower_case( args->replace ) != "no")
    {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
	return "<b>Content ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
	if (exploded[c] == "")
	  exploded[c] = quote;
	else
	{
	  array(string) options =  [string]exploded[c] / ":";
	  string var = String.trim_whites(options[0]);
	  mixed val = vars[var];
	  array(string) encodings = ({});
	  string multisep = multi_separator;
	  string zero = args->zero || "";
	  string empty = args->empty || "";

	  foreach(options[1..], string option) {
	    array (string) foo = option / "=";
	    string optval = String.trim_whites(foo[1..] * "=");

	    switch (lower_case (String.trim_whites( foo[0] ))) {
	      case "empty":
		empty = optval;
		break;
	      case "zero":
		zero = optval;
		break;
	      case "multisep":
	      case "multi_separator":
		multisep = optval;
		break;
	      case "quote":	// For backward compatibility.
		optval = lower_case (optval);
		switch (optval) {
		  case "mysql": case "sql": case "oracle":
		    encodings += ({optval + "-dtag"});
		    break;
		  default:
		    encodings += ({optval});
		}
		break;
	      case "encode":
		encodings += Array.map (lower_case (optval) / ",", String.trim_whites);
		break;
	      default:
		return "<b>Unknown option " + String.trim_whites(foo[0]) +
		  " in replace field " + ((c >> 1) + 1) + "</b>";
	    }
	  }

	  if (!val)
	    if (zero_type (vars[var]) && (args->debug || id->misc->debug))
	      val = "<b>No variable " + options[0] + "</b>";
	    else
	      val = zero;
	  else {
	    if (arrayp( val ))
	      val = Array.map (val, lambda (mixed v) {return (string) v;}) *
		multisep;
	    else
	      val = replace ((string) val, "\000", multisep);
	    if (!sizeof ([string]val)) val = empty;
	  }

	  if (!sizeof (encodings))
	    encodings = args->encode ?
	      Array.map (lower_case (args->encode) / ",", String.trim_whites) : ({"html"});

	  string tmp_val;
	  foreach (encodings, string encoding)
	    if( !(val = roxen_encode( [string]val, encoding )) )
	      return ("<b>Unknown encoding " + encoding
		      + " in replace field " + ((c >> 1) + 1) + "</b>");

	  exploded[c] = val;
	}

      if (first)
	first = 0;
      else if (args->delimiter)
	new_contents += args->delimiter;
      new_contents += args->preprocess ? exploded * "" :
	parse_rxml (exploded * "", id);
      if (args["debug-output"]) unparsed_contents += exploded * "";
    }
    else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, id);
      if (args["debug-output"]) unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
    case 0: break;
    case "log":
      report_debug ("tag output: " + unparsed_contents + "\n");
      break;
    case "comment":
      new_contents += "<!--\n" + html_encode_string (unparsed_contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" + html_encode_string (unparsed_contents) +
	"</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

string fix_relative( string file, RequestID id )
//! Turns a relative (or already absolute) virtual path into an
//! absolute virtual path, that is, one rooted at the virtual server's
//! root directory. The returned path is <ref>simplify_path()</ref>:ed.
{
  string path = id->not_query;
  if( !search( file, "http:" ) )
    return file;

  [string prefix, file] = win_drive_prefix(file);

  // +(id->misc->path_info?id->misc->path_info:"");
  if(file != "" && file[0] == '/')
    ;
  else if(file != "" && file[0] == '#')
    file = path + file;
  else
    file = dirname(path) + "/" +  file;
  return simplify_path(prefix + file);
}

Stdio.File open_log_file( string logfile )
{
  mapping m = localtime(time(1));
  m->year += 1900;	/* Adjust for years being counted since 1900 */
  m->mon++;		/* Adjust for months being counted 0-11 */
  if(m->mon < 10) m->mon = "0"+m->mon;
  if(m->mday < 10) m->mday = "0"+m->mday;
  if(m->hour < 10) m->hour = "0"+m->hour;
  logfile = replace(logfile,({"%d","%m","%y","%h" }),
                    ({ (string)m->mday, (string)(m->mon),
                       (string)(m->year),(string)m->hour,}));
  if(strlen(logfile))
  {
    Stdio.File lf=Stdio.File( logfile, "wac");
    if(!lf)
    {
      mkdirhier(logfile);
      if(!(lf=Stdio.File( logfile, "wac")))
      {
        report_error("Failed to open logfile. ("+logfile+"): "
                     + strerror( errno() )+"\n");
        return 0;
      }
    }
    return lf;
  }
  return Stdio.stderr;
}

string tagtime(int t, mapping(string:string) m, RequestID id,
	       function(string, string, object:function(int, mapping(string:string):string)) language)
  //! A rather complex function used as presentation function by
  //! several RXML tags. It takes a unix-time integer and a mapping
  //! with formating instructions and returns a string representation
  //! of that time. See the documentation of the date tag.
{
  string res;

  if (m->adjust) t+=(int)m->adjust;

  string lang;
  if(id->misc->defines->theme_language) lang=id->misc->defines->theme_language;
  if(m->lang) lang=m->lang;

  if(m->strftime)
    return strftime(m->strftime, t);

  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return number2string(localtime(t)->year+1900,m,
			   language(lang, sp||"number",id));
     case "month":
      return number2string(localtime(t)->mon+1,m,
			   language(lang, sp||"month",id));
     case "week":
      return number2string(Calendar.ISO.Second(t)->week_no(),
			   m, language(lang, sp||"number",id));
     case "beat":
       //FIXME This should be done inside Calendar.
       mapping lt=gmtime(t);
       int secs=3600;
       secs+=lt->hour*3600;
       secs+=lt->min*60;
       secs+=lt->sec;
       secs%=24*3600;
       float beats=secs/86.4;
       if(!sp) return sprintf("@%03d",(int)beats);
       return number2string((int)beats,m,
                            language(lang, sp||"number",id));

     case "day":
     case "wday":
      return number2string(localtime(t)->wday+1,m,
			   language(lang, sp||"day",id));
     case "date":
     case "mday":
      return number2string(localtime(t)->mday,m,
			   language(lang, sp||"number",id));
     case "hour":
      return number2string(localtime(t)->hour,m,
			   language(lang, sp||"number",id));

     case "min":  // Not part of RXML 2.0
     case "minute":
      return number2string(localtime(t)->min,m,
			   language(lang, sp||"number",id));
     case "sec":  // Not part of RXML 2.0
     case "second":
      return number2string(localtime(t)->sec,m,
			   language(lang, sp||"number",id));
     case "seconds":
      return number2string(t,m,
			   language(lang, sp||"number",id));
     case "yday":
      return number2string(localtime(t)->yday,m,
			   language(lang, sp||"number",id));
     default: return "";
    }
  }
  else if(m->type) {
    switch(m->type)
    {
     case "iso":
      mapping eris=localtime(t);
      if(m->date)
	return sprintf("%d-%02d-%02d",
		       (eris->year+1900), eris->mon+1, eris->mday);
      if(m->time)
	return sprintf("%02d:%02d:%02d", eris->hour, eris->min, eris->sec);

      return sprintf("%d-%02d-%02dT%02d:%02d:%02d",
		     (eris->year+1900), eris->mon+1, eris->mday,
		     eris->hour, eris->min, eris->sec);

     case "discordian":
#if efun(discdate)
      array(string) not=discdate(t);
      res=not[0];
      if(m->year)
	res += " in the YOLD of "+not[1];
      if(m->holiday && not[2])
	res += ". Celebrate "+not[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
    }
  }

  res=language(lang, "date", id)(t,m);

  if(m["case"])
    switch(lower_case(m["case"]))
    {
     case "upper":      return upper_case(res);
     case "lower":      return lower_case(res);
     case "capitalize": return capitalize(res);
    }

#ifdef old_rxml_compat
  // Not part of RXML 2.0
  if (m->upper) {
    res=upper_case(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains upper attribute in a tag. Use case=\"upper\" instead.");
  }
  if (m->lower) {
    res=lower_case(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains lower attribute in a tag. Use case=\"lower\" instead.");
  }
  if (m->cap||m->capitalize) {
    res=capitalize(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains capitalize or cap attribute in a tag. Use case=\"capitalize\" instead.");
  }
#endif
  return res;
}

int time_dequantifier(mapping m)
  //! Calculates an integer with how many seconds a mapping
  //! that maps from time units to an integer can be collapsed to.
  //! E.g. (["minutes":2]) results in 120.
  //! Valid units are seconds, minutes, beats, hours, days, weeks,
  //! months and years.
{
  float t = 0.0;
  if (m->seconds) t+=((float)(m->seconds));
  if (m->minutes) t+=((float)(m->minutes))*60;
  if (m->beats)   t+=((float)(m->beats))*86.4;
  if (m->hours)   t+=((float)(m->hours))*3600;
  if (m->days)    t+=((float)(m->days))*86400;
  if (m->weeks)   t+=((float)(m->weeks))*604800;
  if (m->months)  t+=((float)(m->months))*(24*3600*30.436849);
  if (m->years)   t+=((float)(m->years))*(3600*24*365.242190);
  return (int)t;
}

class _charset_decoder(_Charset.ascii cs)
{
  string decode(string what)
  {
    return cs->clear()->feed(what)->drain();
  }
}

function get_client_charset_decoder( string ���, RequestID|void id )
  //! Returns a decoder for the clients charset, given the clients
  //! encoding of the string "���". See the roxen-automatic-charset-variable
  //! tag.
{
  switch( (���/"\0")[0] )
  {
   case "edv":
     report_notice( "Warning: Non 8-bit safe client detected (%s)",
                    (id?id->client*"":"unknown client"));
     return 0;

   case "���":
     return 0;

   case "\33-A���":
     id && id->set_output_charset && id->set_output_charset( "iso-2022" );
     return _charset_decoder(Locale.Charset.decoder("iso-2022-jp"))->decode;

   case "åäö":
     id && id->set_output_charset && id->set_output_charset( "utf-8" );
     return utf8_to_string;

   case "\214\212\232":
     id && id->set_output_charset && id->set_output_charset( "mac" );
     return _charset_decoder( Locale.Charset.decoder( "mac" ) )->decode;

   case "\0�\0�\0�":
     id&&id->set_output_charset&&id->set_output_charset(string_to_unicode);
     return unicode_to_string;
  }
  report_warning( "Unable to find charset decoder for ��� == "+���+"\n" );
}
