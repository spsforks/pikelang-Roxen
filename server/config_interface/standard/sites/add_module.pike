#include <config_interface.h>
#include <module.h>
#include <module_constants.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

// Class is the name of the directory.
array(string) class_description( string d, RequestID id )
{
  string name, doc;
  while(!(< "", "/" >)[d] && !file_stat( d+"/INFO" ))
    d = dirname(d);
  if((< "", "/" >)[d])
    return ({"Local modules", "" });

  string n = Stdio.read_bytes( d+"/INFO" );
  sscanf( n, "<"+id->misc->config_locale+">%s"
          "</"+id->misc->config_locale+">", n );
  sscanf( n, "%*s<name>%s</name>", name  );
  sscanf( n, "%*s<doc>%s</doc>", doc  );
  if( search(n, "<noshow/>" ) != -1 )
    return ({ "", "" });

  if(!name)
    return ({"Local modules", "" });

  if(!doc)
    doc ="";

  return ({ name, doc });
}

array(string) module_class( object m, RequestID id )
{
  return class_description( m->filename, id );
}

object module_nomore(string name, object modinfo, object conf)
{
  mapping module;
  object o;

  if(!modinfo)
    return 0;

  if(!modinfo->multiple_copies && (module = conf->modules[name]) &&
     sizeof(module->copies) )
    return modinfo;

  if(((modinfo->type & MODULE_DIRECTORIES) && (o=conf->dir_module))
     || ((modinfo->type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((modinfo->type & MODULE_TYPES) && (o=conf->types_module)))
    return roxen->find_module( conf->otomod[o] );
}

// To redirect to when done with module addition
string site_url( RequestID id, string site )
{
  return "/"+id->misc->cf_locale+"/sites/site.html/"+site+"/";
}

string page_base( RequestID id, string content )
{
  return sprintf( "<use file='/standard/template' />\n"
                  "<tmpl title=' %s'>"
                  "<topmenu base='&cf.num-dotdots;' selected='sites'/>\n"
                  "<content><cv-split>"
                  "<subtablist width='100%%'>"
                  "<st-tabs></st-tabs>"
                  "<st-page>"
                  "<gbutton preparse='' "
                  "href='add_module.pike?config=&form.config:http;"
                  "&reload_module_list=yes' > %s </gbutton><p>"
                  "\n%s\n</p>\n"
                  "</st-page></subtablist></td></tr></table>"
                  "</cv-split></content></tmpl>", 
		  LOCALE(258,"Add module"), 
		  LOCALE(272,"Reload module list"), content );
}

array(string) get_module_list( function describe_module,
                               function class_visible,
                               RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  int do_reload;
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
    roxen->clear_all_modules_cache();

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  string res = "";

  string doubles="", already="";

  array w = map(mods, module_class, id);

  mapping classes = ([
  ]);
  sort(w,mods);
  for(int i=0; i<sizeof(w); i++)
  {
    mixed r = w[i];
    if(!classes[r[0]])
      classes[r[0]] = ([ "doc":r[1], "modules":({}) ]);
    classes[r[0]]->modules += ({ mods[i] });
  }

  foreach( sort(indices(classes)), string c )
  {
    mixed r;
    if( c == "" )
      continue;
    if( (r = class_visible( c, classes[c]->doc, id )) && r[0] )
    {
      res += r[1];
      foreach(classes[c]->modules, object q)
      {
        if( q->get_description() == "Undocumented" &&
            q->type == 0 )
          continue;
        object b = module_nomore(q->sname, q, conf);
        res += describe_module( q, b );
      }
    } else
      res += r[1];
  }
  master()->set_inhibit_compile_errors( 0 );
  if( ec->get_warnings() )
    report_warning( ec->get_warnings() );
  return ({ res, ec->get() });
}

string module_image( int type )
{
  return "";
}

function describe_module_normal( int image )
{
  return lambda( object module, object block)
  {
    if(!block)
    {
return sprintf(
#"
  <tr>
   <td colspan='2'>
     <table width='100%%'>
      <tr>
       <td><font size='+2'>%s</font></td>
       <td align='right'>%s</td>
      </tr>
     </table>
     </td>
   </tr>
   <tr>
     <td valign='top'>
       <form method='post' action='add_module.pike'>
         <input type='hidden' name='module_to_add' value='%s'>
         <input type='hidden' name='config' value='&form.config;'>
         <submit-gbutton preparse=''>%s</submit-gbutton>
       </form>
     </td>
     <td valign=top>
        %s
       <p>
         %s
       </p>
    </td>
  </tr>
",
     module->get_name(),
     (image?module_image(module->type):""),
     module->sname,
   LOCALE(251, "Add Module"),
     module->get_description(),
     LOCALE(266, "Will be loaded from: ")+module->filename
);
    } else {
      if( block == module )
        return "";
      return "";
    }
  };
}

array(int|string) class_visible_normal( string c, string d, RequestID id )
{
  int x;
  string header = ("<tr><td colspan='2'><table width='100%' "
                   "cellspacing='0' border='0' cellpadding='3' "
                   "bgcolor='&usr.content-titlebg;'><tr><td>");

  if( id->variables->unfolded == c ) {
    header+=("<a name="+Roxen.http_encode_string(c)+
	     "></a><gbutton preparse='' dim=''> "+LOCALE(267, "View")+" </gbutton>");
    x=1;
  }
  else
    header+=("<gbutton preparse='' "
	     "href='add_module.pike?config=&form.config;"
	     "&unfolded="+Roxen.http_encode_string(c)+
	     "#"+Roxen.http_encode_string(c)+"' > "+
	     LOCALE(267, "View")+" </gbutton>");

  header+=("</td><td width='100%'>"
	   "<font color='&usr.content-titlefg;' size='+2'>"+c+"</font>"
	   "<br />"+d+"</td></tr></table></td></tr>\n");

  return ({ x, header });
}

string page_normal( RequestID id, int|void noimage )
{
  string content = "";
  content += "<table>";
  string desc, err;
  [desc,err] = get_module_list( describe_module_normal(!noimage),
                                class_visible_normal, id );
  content += (desc+"</table>"+
              "<pre>"+Roxen.html_encode_string(err)+"</pre>");
  return page_base( id, content );
}

string page_fast( RequestID id )
{
  return page_normal( id, 1 );
}

string describe_module_faster( object module, object block)
{
  if(!block)
  {
return sprintf(
#"
    <tr><td colspan='2'><table width='100%%'><td><font size='+2'>%s</font></td>
        <td align='right'>%s</td></table></td></tr>
    <tr><td valign='top'><select multiple='multiple' name='module_to_add'>
                       <option value='%s'>%s</option></select>
        </td><td valign='top'>%s<p>%s</p></td>
    </tr>
",
   module->get_name(),
   module_image(module->type),
   module->sname,
   module->get_name(),
   module->get_description(),
   LOCALE(266, "Will be loaded from: ")+module->filename
  );
  } else {
    if( block == module )
      return "";
    return "";
  }
}

array(int|string) class_visible_faster( string c, string d, RequestID id )
{
  int x;
  string header = ("<tr><td colspan='2'><table width='100%' cellspacing='0' "
                   "border='0' cellpadding='3' bgcolor='&usr.content-titlebg;'>"
                   "<tr><td>");

  if( id->variables->unfolded == c ) {
    header+=("<a name="+Roxen.http_encode_string(c)+
	     "></a><gbutton preparse='' dim=''> "+LOCALE(267, "View")+" </gbutton>"
	     "<tr><td><submit-gbutton> "+LOCALE(251, "Add Module")+
	     " </submit-gbutton></td></tr>");
    x=1;
  }
  else
    header+=("<gbutton preparse='' "
	     "href='add_module.pike?config=&form.config;"
	     "&unfolded="+Roxen.http_encode_string(c)+
	     "#"+Roxen.http_encode_string(c)+"' > "+
	     LOCALE(267, "View")+" </gbutton>");

  header+=("</td><td width='100%'>"
	   "<font color='&usr.content-titlefg;' size='+2'>"+c+"</font>"
	   "<br />"+d+"</td></tr></table></td></tr>\n");

  return ({ x, header });
}

string page_faster( RequestID id )
{
  string content = "";
  content += "<form method='post' action='add_module.pike'>"
             "<input type='hidden' name='config' value='&form.config;'>"
             "<table>";
  string desc, err;
  [desc,err] = get_module_list( describe_module_faster,
                                class_visible_faster, id );
  content += (desc+"</table></form>"+
              "<pre>"+Roxen.html_encode_string(err)+"</pre>");
  return page_base( id, content );
}

int first;

array(int|string) class_visible_compact( string c, string d, RequestID id )
{
  string res="";
  if(first++)
    res = "</select><br /><submit-gbutton> "+LOCALE(251, "Add Module")+" </submit-gbutton> ";
  res += "<p><font size='+2'>"+c+"</font><br />"+d+"<p><select multiple name='module_to_add'>";
  return ({ 1, res });
}

string describe_module_compact( object module, object block )
{
  if(!block)
    return "<option value='"+module->sname+"'>"+module->get_name()+"</option>";
  return "";
}

string page_compact( RequestID id )
{
  first=0;
  string desc, err;
  [desc,err] = get_module_list( describe_module_compact,
                                class_visible_compact, id );
  return page_base(id,
                   "<form action='add_module.pike' method='POST'>"
                   "<input type='hidden' name='config' value='&form.config;'>"+
                   desc+"</select><br /><submit-gbutton> "
                   +LOCALE(251, "Add Module")+" </submit-gbutton><p><pre>"
                   +Roxen.html_encode_string(err)+"</pre></form>",
                   );
}

string page_really_compact( RequestID id )
{
  first=0;
  string desc, err;


  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
    roxen->clear_all_modules_cache();

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  string res = "";

  mixed r;
  if( (r = class_visible_compact( LOCALE(258,"Add module"), 
				  LOCALE(273,"Select one or several modules to add.")
				  , id )) && r[0] ) {
    res += r[1];
    foreach(mods, object q) {
      if( q->get_description() == "Undocumented" &&
	  q->type == 0 )
	continue;
      object b = module_nomore(q->sname, q, conf);
      res += describe_module_compact( q, b );
    }
  } else
    res += r[1];

  master()->set_inhibit_compile_errors( 0 );
  desc=res;
  err=ec->get();

  return page_base(id,
                   "<form action=\"add_module.pike\" method=\"post\">"
                   "<input type=\"hidden\" name=\"config\" value=\"&form.config;\" />"+
                   desc+"</select><br /><submit-gbutton> "
                   +LOCALE(251, "Add Module")+" </submit-gbutton><br /><pre>"
                   +Roxen.html_encode_string(err)+"</pre></form>",
                   );
}

string decode_site_name( string what )
{
  if( (int)what ) 
    return (string)((array(int))(what/","-({""})));
  return what;
}

mixed do_it( RequestID id )
{

  if( id->variables->encoded )
    id->variables->config = decode_site_name( id->variables->config );

  object conf = roxen.find_configuration( id->variables->config );
  string last_module = "";
  array(string) initial_modules = ({});
  int got_initial = 0;
  if(!conf)
    return LOCALE(268, "Configuration gone!")+"\n";

  if( !conf->inited )
    conf->enable_all_modules();

  //werror("%O\n", id->variables->mod_init_vars);
  foreach( id->variables->module_to_add/"\0", string mod ) {
    if (RoxenModule m = conf->enable_module( mod )) {
      mod = conf->otomod[m];
      last_module = replace(mod, "#", "!" );
      /*
      if (id->variables->mod_init_vars) {
	foreach (indices (m->variables), string var)
	  roxen.change_configurable (m->variables[var], VAR_INITIAL, 0);
	foreach (id->variables->init_var / "\0", string var) {
	  array(string) split = array_sscanf (replace (var, "!", "#"), "%s/%s");
	  if (sizeof (split) == 2 && split[0] == mod && m->variables[split[1]]) {
	    roxen.change_configurable (m->variables[split[1]], VAR_INITIAL, VAR_INITIAL);
	    got_initial = 1;
	    initial_modules += ({ last_module });
	  }
	}
      }
      else
      */
      foreach (indices (m->variables), string var)
	if ( m->variables[var]->get_flags()&VAR_INITIAL ) {
	  got_initial = 1;
	  initial_modules += ({ last_module });
	}
    }
    else last_module = "";
  }

  if( strlen( last_module ) )
    if (got_initial)
      return Roxen.http_redirect( site_url( id, id->variables->config )+
			    "modules/?initial=1&mod="+Array.uniq(initial_modules)*",", id );
    else
      return Roxen.http_redirect( site_url( id, id->variables->config )+
			    "modules/"+last_module+"/", id );
  return Roxen.http_redirect( site_url( id, id->variables->config )+"modules/",id);
}

mixed parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return LOCALE(226, "Permission denied");

  if( id->variables->module_to_add )
    return do_it( id );

  object conf = roxen.find_configuration( id->variables->config );
  
  if( !conf->inited )
    conf->enable_all_modules();

  return this_object()["page_"+replace(config_setting( "addmodulemethod" )," ","_")]( id );
}
