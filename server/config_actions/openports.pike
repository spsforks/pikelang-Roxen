/*
 * $Id: openports.pike,v 1.2 1997/08/13 22:27:26 grubba Exp $
 */

inherit "roxenlib";
constant name= "Show all open ports...";

constant doc = ("Show all open ports on any, or all, interfaces.");

mixed all_ports(object id)
{
  string res = "<h1>All open ports on this computer</h1><br>\n";
  mapping ports_by_ip = ([ ]);
  string s;

  if(!(s=popen("lsof -i -P -n -b -F cLpPnf")) || !strlen(s))
  {
    s = popen("netstat -n -a");
    if(!s || !strlen(s)) return "I cannot understand the output of netstat -a";
    foreach(s/"\n", s)
    {
      string ip,tmp;
      int port;
      if(search(s, "LISTEN")!=-1)
      {
	s=((replace(s,"\t"," ")/" "-({""})))[0];
	sscanf(reverse(s), "%[^.].%s", tmp, ip);
	ip=reverse(ip);
	port=(int)reverse(tmp);
	if(ip=="*") ip="ANY";
	if(!ports_by_ip[ip])
	  ports_by_ip[ip]=({({port,0,"Install <a href=ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/lsof.tar.gz>'lsof'</a>","for this info"})});
	else
	  ports_by_ip[ip]+=({({port,0,"Install <a href=ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/lsof.tar.gz>'lsof'</a>","for this info"})});
      }
    }
  } else {
    int pid, port, last, ok;
    string cmd, ip;
    string user;
    mapping used = ([]);
    foreach(s/"\n", s)
    {
      if(!strlen(s)) continue;
      switch(s[0])
      {
       case 'P':
	if(s[1..]=="TCP") ok=1; else ok=0;
	break;
       case 'p': pid = (int)s[1..];break;
       case 'c': cmd = s[1..];break;
       case 'L': user = s[1..]; break;
       case 'n':
	last=0;
	s=s[1..];
	if(ok && search(s,"->")==-1)
	{
//	  write(s+"\n");
	  sscanf(s, "%s:%d", ip, port);
	  if(ip=="*") ip="ANY";
	  if(!used[ip] || !used[ip][port])
	  {
	    if(!used[ip]) used[ip]=(<>);
	    used[ip][port]=1;
	    last=1;
	    if(!ports_by_ip[ip])
	      ports_by_ip[ip]=({({port,pid,cmd,user})});
	    else
	      ports_by_ip[ip]+=({({port,pid,cmd,user})});
	  }
	}
      }
    }
  }


  foreach(sort(indices(ports_by_ip)), string ip)
  {
    string su;
    string oip = ip;
    if(ip != "ANY") ip = su = roxen->blocking_ip_to_host(ip);
    else { su = gethostname(); ip="All interfaces"; }
    res += "<h2>"+ip+"</h2>";

    res += "<table cellpadding=3 cellspacing=0 border=0><tr bgcolor=lightblue><td><b>Port number</b></td><td><b>Program</b></td><td><b>User</b></td><td><b>PID</b></td></tr>\n";
    array a = ports_by_ip[oip];
    sort(column(a,0),a);
    int i;
    foreach(a, array port)
    {
      string bg=((i++/3)%2)?"white":"#e0e0ff";

      if(port[1]!=getpid())
	res += sprintf("<tr bgcolor=\""+bg+"\"><td align=right>%d</td><td>%s</td><td>%s</td>"
		       "<td>%d</td></tr>",
		       port[0],port[2],port[3],port[1]);
      else
	res += sprintf("<tr  bgcolor=\""+bg+"\"><td align=right><b>%d</b></td><td><b>%s</b></td>"
		       "<td><b>%s</b></td><td><b>%d</b></td></tr>",
		       port[0],port[2],port[3],port[1]);
    }
    res+="</table>";
  }
  return res;

}

mixed roxen_ports(object id)
{
  string res = "<h1>All open ports in this Roxen</h1><br>\n";
  mapping ports_by_ip = ([ ]);

  mapping used = ([]);
  foreach(roxen->configurations, object c)
  {
    mapping p = c->open_ports;
    foreach(indices(p), array port)
    {
      // num, protocol, ip
      if(!used[p[port][2]] || !used[p[port][2]][p[port][0]])
      {
	if(!used[p[port][2]]) used[p[port][2]]=(<>);
	used[p[port][2]][p[port][0]]=1;
	if(!ports_by_ip[p[port][2]])
	  ports_by_ip[p[port][2]]=({({p[port][0],p[port][1],c})});
	else
	  ports_by_ip[p[port][2]]+=({({p[port][0],p[port][1],c})});
      }
    }
  }

  foreach(roxen->configuration_ports, object o)
  {
    string port, ip;
    sscanf(o->query_address(1), "%s %s", ip, port);
    if(ip=="0.0.0.0") ip="ANY";
    if(!ports_by_ip[ip])
      ports_by_ip[ip]=({({(int)port,"http",0})});
    else
      ports_by_ip[ip]+=({({(int)port,"http",0})});
  }
  
  foreach(sort(indices(ports_by_ip)), string ip)
  {
    string su;
    string oip = ip;
    if(ip != "ANY") ip = su = roxen->blocking_ip_to_host(ip);
    else { su = gethostname(); ip="All interfaces"; }
    res += "<h2>"+ip+"</h2>";
    res += "<table><tr bgcolor=lightblue><td><b>Port number</b></td><td><b>Protocol</b></td><td><b>Server</b></td><td><b>URL</b></td></tr>\n";
    array a;
    a = ports_by_ip[oip];
    sort(column(a,0), a);
    foreach(a, array port)
    {
      string url = (port[1][0]=='s'?"https":port[1]) + "://" + su + ":"+port[0];
      res += sprintf("<tr><td align=right>%d</td><td>%s</td><td><a href=\"%s\">"
		     "%s</a></td><td><a target=remote href=\"%s\">%s</a>"
		     "</td></tr>",
		     port[0],port[1],
		     port[2]?"/Configurations/"+http_encode_string(port[2]->name)+"?"+time():"/Globals/", port[2]?port[2]->name:"Configuration interface", url, url);
    }
    res += "</table>";
  }
  return res;
}

mixed first_form(object id)
{
  return ("<table bgcolor=black cellpadding=1><tr><td>"
	  "<table cellpadding=10 cellspacing=0 border=0 bgcolor=#eeeeff>"
	  "<tr><td align=center valign=center colspan=2>"
	  "<h1>What information do you want?</h1>"
	  "<form>\n"
	  "<font size=+1>Please select one of the pages below</font><br>"
	  "</tr><tr><td  colspan=2>"
	  "<input type=hidden name=action value="+id->variables->action+">"
	  "<input type=radio name=page checked value=roxen_ports> Show all ports allocated by Roxen<br>"
	  "<input type=radio name=page value=all_ports> Show all ports<br>"
	  "</tr><tr><td>"
	  "<input type=submit name=ok value=\" Ok \"></form>"
	  "</td><td align=right>"
	  "<form>"
	  "<input type=submit name=cancel value=\" Cancel \"></form>"
	  "</td></tr></table></table>");
}

mixed handle(object id, object mc)
{
  function fun;
  if((fun=this_object()[id->variables->page||""])&&fun!=handle&&functionp(fun))
    return fun(id,mc);
  return first_form(id);
}
