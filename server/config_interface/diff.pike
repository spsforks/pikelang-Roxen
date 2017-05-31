#include <config_interface.h>
#include <module.h>
#include <module_constants.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string parse( RequestID id )
{
  Variable.Variable v =
    Variable.get_variables(id->variables->variable);

  if(!v)
    return " Error in URL ";

  return sprintf( "<use file='/template' />\n"
                  "<tmpl title=' %s '>"
                  "<content><div class='diff'>%s</div></content></tmpl>",
		  LOCALE(466,"Difference"),
                  Roxen.html_encode_string((v->diff(2)||"")) );
}
