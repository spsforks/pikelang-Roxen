// This is a roxen module. Copyright � 1996 - 2000, Roxen IS.
// This module can be used to turn off logging for some files.


constant cvs_version = "$Id: nologging.pike,v 1.10 2000/03/02 04:38:12 nilsson Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_LOGGER;
constant module_name = "Logging disabler";
constant module_doc  = "This module can be used to turn off logging for some files. "
  "It is based on "/*"<a href=$docurl/regexp.html>"*/"Regular"
  " expressions"/*"</a>"*/;

void create()
{
  defvar("nlog", "", "No logging for",
	 TYPE_TEXT_FIELD,
	 "All files whose (virtual)filename match the pattern above "
	 "will be excluded from logging. This is a regular expression");

  defvar("log", ".*", "Logging for",
	 TYPE_TEXT_FIELD,
	 "All files whose (virtual)filename match the pattern above "
	 "will be logged, unless they match any of the 'No logging for'"
	 "patterns. This is a regular expression");
}

string make_regexp(array from)
{
  return "("+from*")|("+")";
}


string check_variable(string name, mixed value)
{
  if(catch(Regexp(make_regexp(QUERY(value)/"\n"-({""})))))
    return "Compile error in regular expression.\n";
  return 0;
}


function no_log_match, log_match;

void start()
{
  no_log_match = Regexp(make_regexp(QUERY(nlog)/"\n"-({""})))->match;
  log_match = Regexp(make_regexp(QUERY(log)/"\n"-({""})))->match;
}


int nolog(string what)
{
  if(no_log_match(what)) return 1;
  if(log_match(what)) return 0;
}


int log(object id, mapping file)
{
  if(nolog(id->not_query+"?"+id->query))
    return 1;
}
