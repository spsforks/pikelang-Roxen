/*
 * $Id: configtablist.pike,v 1.3 1997/08/31 02:49:23 peter Exp $
 *
 * Makes a tab-list like the one in the config-interface.
 *
 * $Author: peter $
 */

constant cvs_version="$Id: configtablist.pike,v 1.3 1997/08/31 02:49:23 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

/*
 * Functions
 */

array register_module()
{
  return(({ MODULE_PARSER|MODULE_LOCATION, "Config tab-list", 
	      "Adds some tags for making a config-interface "
	      "look-alike tab-list.<br>\n"
	      "Usage:<br>\n"
	      "<ul><pre>&lt;config_tablist&gt;\n"
	      "&lt;tab href=\"/tab1/\"&gt;Some text&lt;/tab&gt;\n"
	      "&lt;tab href=\"/tab2/\"&gt;Some more text&lt;/tab&gt;\n"
	      "&lt;tab href=\"a/strange/place/\"&gt;Tab 3&lt;/tab&gt;\n"
	      "&lt;/config_tablist&gt;\n"
	      "</pre></ul>Attributes for the &lt;tab&gt; tag:<br>\n"
	      "<ul><table border=0>\n"
	      "<tr><td><b>selected</b></td><td>Whether the tab is selected "
	      "or not.</td></tr>\n"
	      "<tr><td><b>alt</b></td><td>Alt-text for the image (default: "
	      "\"_/\" + text + \"\\_\").</td></tr>\n"
	      "<tr><td><b>border</b></td><td>Border for the image (default: "
	      "0).</td></tr>\n"
	      "</table></ul>\n", 0, 1 }));
}

void create()
{
  defvar("location", "/configtabs/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the buttons.");
}

string tag_config_tab(string t, mapping a, string contents)
{
  string dir = "u/";
  mapping img_attrs = ([]);
  if (a->selected) {
    dir = "s/";
  }
  m_delete(a, "selected");

  img_attrs->src = QUERY(location) + dir + replace(contents,
						   ({ "\"", "\'", "%" }),
						   ({ "%22", "%27", "%25" }));
  if (a->alt) {
    img_attrs->alt = a->alt;
    m_delete(a, "alt");
  } else {
    img_attrs->alt = "_/" + html_encode_string(contents) + "\\_";
  }
  if (a->border) {
    img_attrs->border = a->border;
    m_delete(a, "border");
  } else {
    img_attrs->border="0";
  }
  return make_container("a", a, make_container("b", ([]),
					       make_tag("img", img_attrs)));
}

string tag_config_tablist(string t, mapping a, string contents)
{
  return(replace(parse_html(contents, ([]), (["tab":tag_config_tab])),
		 ({ "\n", "\r" }), ({ "", "" })));
}

mapping query_container_callers()
{
  return ([ "config_tablist":tag_config_tablist ]);
}

mapping find_file(string f, object id)
{
  array(string) arr = f/"/";
  if (sizeof(arr) > 1) {
    object interface = roxen->configuration_interface();
    object(Image.image) button;
    switch (arr[0]) {
    case "s":	/* Selected */
      button = interface->draw_selected_button(arr[1..]*"/",
					       interface->button_font);
      break;
    case "u":	/* Unselected */
      button = interface->draw_unselected_button(arr[1..]*"/",
						 interface->button_font);
      break;
    default:
      return 0;
    }
    return http_string_answer(button->togif(), "image/gif");
  }
  return 0;
}
