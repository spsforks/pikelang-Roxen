/*
 * http.pike: HTTP convenience functions.
 * inherited by roxenlib, and thus by all files inheriting roxenlib.
 * $Id: http.pike,v 1.35 2000/02/17 05:28:12 per Exp $
 */

#include <config.h>
#include <variables.h>

#if !efun(roxen)
#define roxen roxenp()
class RequestID {};
#endif

#ifdef HTTP_DEBUG
# define HTTP_WERR(X) werror("HTTP: "+X+"\n");
#else
# define HTTP_WERR(X)
#endif

string http_res_to_string( mapping file, RequestID id )
{
  mapping heads=
    ([
      "Content-type":file["type"],
      "Server":replace(id->version(), " ", "�"),
      "Date":http_date(id->time)
      ]);

  if(file->encoding)
    heads["Content-Encoding"] = file->encoding;

  if(!file->error)
    file->error=200;

  if(file->expires)
      heads->Expires = http_date(file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=id->misc->stat))
	file->stat = (array(int))file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];

      heads["Last-Modified"] = http_date(fstat[3]);
    }
    if(stringp(file->data))
      file->len += strlen(file->data);
  }

  if(mappingp(file->extra_heads))
    heads |= file->extra_heads;

  if(mappingp(id->misc->moreheads))
    heads |= id->misc->moreheads;

  array myheads=({id->prot+" "+(file->rettext||errors[file->error])});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach(heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});


  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read(0x7ffffff):"");
  return head_string;
}


/* Return a filled out struct with the error and data specified.  The
 * error is infact the status response, so '200' is HTTP Document
 * follows, and 500 Internal Server error, etc.
 */

mapping http_low_answer( int errno, string data )
{
  if(!data) data="";
  HTTP_WERR("Return code "+errno+" ("+data+")");
  return
    ([
      "error" : errno,
      "data"  : data,
      "len"   : strlen( data ),
      "type"  : "text/html",
      ]);
}

mapping http_pipe_in_progress()
{
  HTTP_WERR("Pipe in progress");
  return ([ "file":-1, "pipe":1, ]);
}



/* Convenience functions to use in Roxen modules. When you just want
 * to return a string of data, with an optional type, this is the
 * easiest way to do it if you don't want to worry about the internal
 * roxen structures.
 */
mapping http_rxml_answer( string rxml, RequestID id,
                          void|Stdio.File file,
                          void|string type )
{
  rxml = id->conf->parse_rxml(rxml, id, file);
  HTTP_WERR("RXML answer ("+(type||"text/html")+")");
  return (["data":rxml,
	   "type":(type||"text/html"),
	   "stat":id->misc->defines[" _stat"],
	   "error":id->misc->defines[" _error"],
	   "rettext":id->misc->defines[" _rettext"],
	   "extra_heads":id->misc->defines[" _extra_heads"],
	   ]);
}


mapping http_string_answer(string text, string|void type)
{
  HTTP_WERR("String answer ("+(type||"text/html")+")");
  return ([ "data":text, "type":(type||"text/html") ]);
}

mapping http_file_answer(Stdio.File text, string|void type, void|int len)
{
  HTTP_WERR("file answer ("+(type||"text/html")+")");
  return ([ "file":text, "type":(type||"text/html"), "len":len ]);
}

constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

/* Return a date, used in the common log format */
string cern_http_date(int t)
{
  string c;
  mapping lt = localtime(t);
  int tzh = lt->timezone/3600 - lt->isdst;

  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }

  return(sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		 lt->mday, months[lt->mon], 1900+lt->year,
		 lt->hour, lt->min, lt->sec, c, tzh));
}

/* Returns a http_date, as specified by the HTTP-protocol standard.
 * This is used for logging as well as the Last-Modified and Time
 * heads in the reply.  */

string http_date(int t)
{
#if constant(gmtime)
  mapping l = gmtime( t );
#else
  mapping l = localtime( t );
  t += l->timezone - 3600*l->isdst;
  l = localtime(t);
#endif
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, months[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));
}


string http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22"}));
}

string http_encode_cookie(string f)
{
  return replace(f, ({ "=", ",", ";", "%" }), ({ "%3d", "%2c", "%3b", "%25"}));
}

string http_encode_url (string f)
{
  return replace (f, ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"", "#",
		       "&", "?", "=", "/", ":"}),
		  ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22", "%23",
		    "%26", "%3f", "%3d", "%2f", "%3a"}));
}

string http_roxen_config_cookie(string from)
{
  return "RoxenConfig="+http_encode_cookie(from)
    +"; expires=" + http_date (3600*24*365*2 + time (1)) + "; path=/";
}

string http_roxen_id_cookie()
{
  return sprintf("RoxenUserID=0x%x; expires=" +
		 http_date (3600*24*365*2 + time (1)) + "; path=/",
		 roxen->increase_id());
}

static string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

/* Simply returns a http-redirect message to the specified URL.  */
mapping http_redirect( string url, RequestID|void id )
{
  if(strlen(url) && url[0] == '/')
  {
    if(id)
    {
      if( id->misc->site_prefix_path )
        url = replace( id->misc->site_prefix_path + url, "//", "/" );
      url = add_pre_state(url, id->prestate);
      if(id->misc->host)
      {
	array h;
	HTTP_WERR(sprintf("(REDIR) id->port_obj:%O", id->port_obj));
	string prot = id->port_obj->name + "://";
	string p = ":" + id->port_obj->default_port;

	h = id->misc->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+id->misc->host+url;
      } else
	url = id->conf->query("MyWorldLocation") + url[1..];
    }
  }
  HTTP_WERR("Redirect -> "+http_encode_string(url));
  return http_low_answer( 302, "")
    + ([ "extra_heads":([ "Location":http_encode_string( url ) ]) ]);
}

mapping http_stream(Stdio.File from)
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}


mapping http_auth_required(string realm, string|void message)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
  HTTP_WERR("Auth required ("+realm+")");
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

#ifdef API_COMPAT
mapping http_auth_failed(string realm)
{
  HTTP_WERR("Auth failed ("+realm+")");
  return http_low_answer(401, "<h1>Authentication failed.\n</h1>")
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}
#else
function http_auth_failed = http_auth_required;
#endif


mapping http_proxy_auth_required(string realm, void|string message)
{
  HTTP_WERR("Proxy auth required ("+realm+")");
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

static string add_http_header(mapping to, string name, string value)
{
  if(to[name])
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  else
    to[name] = value;
}
