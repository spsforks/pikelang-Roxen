#include <process.h>
#include <array.h>
#include <stdio.h>
#include <string.h>

#define error(X) throw( ({ (X), backtrace()[0..sizeof(backtrace())-2] }) )

#if !constant(_static_modules)
inherit "/precompiled/regexp";
#endif /* _static_modules */

varargs int member_array(mixed needle,mixed *haystack,int start)
{
  return search(haystack,needle,start);
}

object previous_object()
{
  int e;
  mixed **trace;
  object o,ret;
  trace=backtrace();
  o=function_object(trace[-2][2]);
  for(e=sizeof(trace)-3;e>=0;e--)
  {
    if(!trace[1][2]) continue;
    ret=function_object(trace[1][2]);
    if(o!=ret) return ret;
  }
  return 0;
}

function this_function()
{
  return backtrace()[-2][2];
}

string capitalize(string s)
{
  return upper_case(s[0..0])+s[1..sizeof(s)];
}

function get_function(object o, string a)
{
  mixed ret;
  ret=o[a];
  return functionp(ret) ? ret : 0;
}

#if !constant(_static_modules)
/* This is a #define in later versions of Pike */
string *regexp(string *s, string reg)
{
  regexp::create(reg);
  s=filter(s,match);
  regexp::create(); /* Free compiled regexp */
  return s;
}
#endif /* _static_modules */

void create()
{
  add_constant("PI",3.1415926535897932384626433832795080);
  add_constant("capitalize",capitalize);
  add_constant("explode",`/);
  add_constant("all_efuns",all_constants);

  add_constant("filter_array",filter);
  add_constant("map_array",map);

  add_constant("get_function",get_function);
  add_constant("implode",`*);
  add_constant("m_indices",indices);
  add_constant("m_sizeof",sizeof);
  add_constant("m_values",values);
  add_constant("member_array",member_array);
  add_constant("previous_object",previous_object);
#if !constant(_static_modules)
  add_constant("regexp",regexp);
#endif
  add_constant("strstr",search);
  add_constant("sum",`+);
  add_constant("this_function",this_function);
  add_constant("add_efun",add_constant);

  add_constant("l_sizeof",sizeof);
  add_constant("listp",multisetp);
  add_constant("mklist",mkmultiset);
  add_constant("aggregage_list",aggregate_multiset);
}
