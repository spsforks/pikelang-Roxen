/* IMAP.requests
 *
 */

import .types;

class request
{
  string tag;
  object line;
  
  void create(string t, object l)
    {
      tag = t;
      line = l;
    }

  string process(object|mapping session, object server, function send)
    {
      send(tag, "OK");
      return "finished";
    }

#if 0
  string format(string tag, object|string ... args)
    {
      return tag + " "
	+ Array.map(args, lambda (mixed x)
			    {
			      if (stringp(x))
				return x;
			      else
				return x->format();
			    })
	* " " + "\r\n";
    }

  string untagged_response(object|string ... args)
    {
      return format("*", @args);
    }
  
  string response_ok(object|string ... args)
    {
      format(tag, "OK", @args);
    }

  string response_no(object|string ... args)
    {
      format(tag, "NO", @args);
    }

  string response_BAD(object|string ... args)
    {
      format(tag, "BAD", @args);
    }
#endif
}

class easy_request
{
  inherit request;

  constant arg_info = ({ });

  array args;
  int argc;

  string expects;
  int expected_length;
  
  string easy_process(object|mapping session, object server,
		      function send, mixed ... args)
    { return "foo"; }

  string process_literal(object|mapping session, object server,
			 string literal, function send)
    {
#if 0
      if ( (arg_info[argc][0] == "mailbox")
	   && (lower_case(literal) == "inbox") )
	literal = "INBOX";
#endif   
      args[argc++] = literal;
      if (argc == sizeof(args))
	return easy_process(session, server, send, @args);
      else
      {
	expects = "line";
	return "progress";
      }
    }

  string process_line(object|mapping session, object server,
		      object l, function send)
    {
      line = l;
      return process(session, server, send);
    }

  string request_literal(function send)
    {
      send("+", ( (sizeof(arg_info[argc]) > 1)
		  ? arg_info[argc][1] : "Ready") );
      expects = "literal";
      expected_length = args[argc]->length;
      return "progress";
    }
  
  string process(object|mapping session, object server, function send)
    {
      while(argc < sizeof(args))
      {
	switch(arg_info[argc][0])
	{
	case "number":
	  if ( (args[argc++] = line->get_number()) < 0)
	  {
	    send(tag, "BAD", "Invalid number");
	    return "finished";
	  }
	  break;
	case "string":
	  if (!(args[argc] = line->get_string()))
	  {
	    send(tag, "BAD", "Missing or invalid argument");
	    return "finished";
	  }
	  if (objectp(args[argc]))
	    return request_literal(send);
	  argc++;
	  break;
	case "astring":
	  if (!(args[argc] = line->get_astring()))
	  {
	    send(tag, "BAD", "Missing or invalid argument");
	    return "finished";
	  }
	  if (objectp(args[argc]))
	    return request_literal(send);
	  argc++;
	  break;
	default:
	  throw( ({ sprintf("IMAP.requests: Unknown argument type %O\n",
			    arg_info[argc]), backtrace() }) );
	}
      }
      return easy_process(session, server, send, @args);
    }
  
  void create(string tag, object line)
    {
      ::create(tag, line);
      args = allocate(sizeof(arg_info));
      argc = 0;
    }
}


class noop
{
  inherit request;

  string process(object session, object server, function send)
    {
      array status = server->update(session);
      
      if (status)
	foreach(status, array a)
	  send("*", @a);
      
      send(tag, "OK");
      return "finished";
    }
}

class capability
{
  inherit request;

  string process(object|mixed session, object server, function send)
    {
      send("*", "CAPABILITY", @server->capabilities(session));
      send(tag, "OK");
      return "finished";
    }
}

class login
{
  inherit easy_request;

  constant arg_info = ({
    ({ "astring", "Ready for user name" }),
    ({ "astring", "Ready for pass word" }) });
  
  mixed uid;
  mixed get_uid() { return uid; }
  
  string easy_process(object|mapping session, object server,
		      function send, string name, string passwd)
    {
      /* Got name and passwd. Attempt authentication. */
      uid = server->login(session, name, passwd);
      
      if (!uid)
      {
	send(tag, "NO");
	return "finished";
      }
      send(tag, "OK");
      return "login";
    }
}

class logout
{
  inherit request;

  string process(object|mapping session, object server, function send)
    {
      send("*", "BYE");
      send(tag, "OK");
      return "close";
    }
}

class list
{
  inherit easy_request;
  constant arg_info = ({ ({ "astring", "Ready for mailbox name" }),
			 ({ "astring" }) });

  string easy_process(object|mapping session, object server,
		      function send, string reference, string glob)
    {
      /* Each element of the array should be an array with three elements,
       * attributes, hierarchy delimiter, and the name. */

      if ( (reference == "")
	   && (lower_case(glob) == "inbox") )
	glob = "INBOX";
      
      array mailboxes = server->list(session, reference, glob);
      
      if (mailboxes)
	foreach(mailboxes, array a)
	  send("*", @a);
      
      send(tag, "OK");
      return "finished";
    }
}

class lsub
{
  inherit easy_request;
  constant arg_info = ({ ({ "astring", "Ready for mailbox name" }),
			 ({ "astring" }) });

  string easy_process(object|mapping session, object server,
		      function send, string reference, string glob)
    {
      /* Each element of the array should be an array with three elements,
       * attributes, hierarchy delimiter, and the name. */

      if ( (reference == "")
	   && (lower_case(glob) == "inbox") )
	glob = "INBOX";
      
      array mailboxes = server->lsub(session, reference, glob);
      
      if (mailboxes)
	foreach(mailboxes, array a)
	  send("*", @a);
      
      send(tag, "OK");
      return "finished";
    }
}

class select
{
  inherit easy_request;

  constant arg_info = ({ ({ "astring" }) });

  string easy_process(object|mapping session, object server,
		      function send, string mailbox)
    {
      if (lower_case(mailbox) == "inbox")
	mailbox = "INBOX";

      array info = server->select(session, mailbox);

      if (info)
      {
	foreach(info, array a)
	  send("*", @a);
	send(tag, "OK", imap_prefix( ({ "READ-WRITE" }) ) );
	return "select";
      } else {
	send(tag, "NO");
	return "login";
      }
    }
}
