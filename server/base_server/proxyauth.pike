// This file is part of Roxen WebServer.
// Copyright � 1996 - 2001, Roxen IS.
// $Id: proxyauth.pike,v 1.8 2001/09/06 11:40:27 per Exp $

// Mostly compatibility file
mapping proxy_auth_needed(RequestID id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return Roxen.http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return res;
  }
  return 0;
}
