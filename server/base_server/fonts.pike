// This file is part of Roxen Webserver.
// Copyright � 1996 - 2000, Roxen IS.
// $Id: fonts.pike,v 1.51 2000/05/26 22:20:02 per Exp $

#include <module_constants.h>
#include <module.h>

constant Font = Image.Font;

string fix_name(string in)
{
  return replace(lower_case(in), ({"-"," "}), ({ "_", " " }));
}


// name:([ version:fname, version:fname, ... ])
mapping ttf_done = ([]);
mapping ttf_font_names_cache = ([]);

string trimttfname( string n )
{
  n = lower_case(replace( n, "\t", " " ));
  return ((n/" ")*"")-"'";
}

string translate_ttf_style( string style )
{
  switch( lower_case( (style-"-")-" " ) )
  {
   case "normal":
   case "regular":
     return "nn";
   case "italic":
     return "ni";
   case "oblique":
     return "ni";
   case "bold":
     return "bn";
   case "bolditalic":
   case "italicbold":
     return "bi";
     return "bi";
   case "black":
     return "Bn";
   case "blackitalic":
   case "italicblack":
     return "Bi";
     return "Bi";
   case "light":
     return "ln";
   case "lightitalic":
   case "italiclight":
     return "li";
  }
  if(search(lower_case(style), "oblique"))
    return "ni"; // for now.
  report_debug("Unknwon ttf style: "+style+"\n");
  return "nn";
}

array available_font_versions(string name, int size)
{
  string base_dir, dir;
  array available;
#if constant(has_Image_TTF)
  int ttffound;
  int ttffontschanged;

   if(ttf_font_names_cache[ name ])
     return indices(ttf_font_names_cache[ name ]);
  foreach(roxen->query("font_dirs"), dir)
  {
    foreach(r_get_dir( dir )||({}), string fname)
    {
      catch
      {
	if(!ttf_done[combine_path(dir+"/",fname)]++)
	{
//   werror("Trying TTF: "+combine_path(dir+"/",fname)+"\n");
	  Image.TTF ttf = Image.TTF( combine_path(dir+"/",fname) );
	  if(ttf)
	  {
	    mapping n = ttf->names();
//        werror("okiedokie! "+n->family+"\n");
	    ttffontschanged++;
	    string f = lower_case(trimttfname(n->family));
	    if(!ttf_font_names_cache[f])
	      ttf_font_names_cache[f] = ([]);
	    ttf_font_names_cache[f][ translate_ttf_style(n->style) ]
	      = combine_path(dir+"/",fname);
	    if(f == lower_case( name ))  ttffound++;
	  }
	}
      };
    }
  }
  if(ttffontschanged)
    catch{
      open("$VVARDIR/ttffontcache","wct")
        ->write(encode_value(ttf_font_names_cache));
    };
  if(ttffound)
    return  indices(ttf_font_names_cache[ lower_case(name) ]);
#endif

  foreach(roxen->query("font_dirs"), dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if((available = r_get_dir(base_dir)))
      break;
    base_dir=dir+"/32/"+fix_name(name);
    if((available = r_get_dir(base_dir)))
      break;
    base_dir=dir+"/32/"+roxen->query("default_font");
    if((available = r_get_dir(base_dir)))
      break;
  }
  if(!available) return 0;
  return available;
}

string describe_font_type(string n)
{
  string res;
  if(n[1]=='i') res = "italic";
  else res="";

  switch(n[0])
  {
   case 'n': if(!strlen(res)) res="normal"; break;
   case 'B': res+=" black";  break;
   case 'b': res+=" bold";  break;
   case 'l': res+=" light";  break;
  }
  return res;
}

array get_font_italic_bold(string n)
{
  int italic,bold;
  if(n[1]=='i') italic = 1;

  switch(n[0])
  {
   case 'B': bold=2; break;
   case 'b': bold=1; break;
   case 'l': bold=-1;  break;
  }
  return ({ italic, bold });
}

string make_font_name(string name, int size, int bold, int italic)
{
  string base_dir, dir;
  mixed available = available_font_versions( name,size );
  if(r_file_stat(name)) return name;

  string bc=(bold>=0?(bold==2?"B":(bold==1?"b":"n")):"l"), ic=(italic?"i":"n");
  if(available)
    available = mkmultiset(available);
  else
    return name+"/nope";
  if(available[bc+ic])
    return name+"/"+bc+ic;
  if(bc=="l") bc="n";
  if(available[bc+ic])
    return name+"/"+bc+ic;
  if(bc=="B") bc="b";
  if(available[bc+ic])
    return name+"/"+bc+ic;
  if(bc=="b") bc="n";
  if(available[bc+ic])
    return name+"/"+bc+ic;
  if(ic=="i") ic="n";
  if(available[bc+ic])
    return name+"/"+bc+ic;

  foreach(({ "n","l","b", "B", }), bc)
    foreach(({ "n", "i" }), ic)
      if(available[bc+ic])
	return name+"/"+bc+ic;
  return 0;
}

#if constant(has_Image_TTF)
class TTFWrapper
{
  int size;
  object real;
  static object encoder;
  static function(string ... : Image.image) real_write;
  int height( )
  {
    return size;
  }

  string _sprintf()
  {
    return sprintf( "TTF(%O,%d)", real, size );
  }

  static Image.image write_encoded(string ... what)
  {
    return real->write(@(encoder?
			 Array.map(what, lambda(string s) {
					   return encoder->clear()->
					     feed(s)->drain();
					 }):what));
  }

  array text_extents( string what )
  {
    Image.Image o = real_write( what );
    return ({ o->xsize(), o->ysize() });
  }

  void create(object r, int s, string fn)
  {
    string encoding;
    real = r;
    size = s;
    real->set_height( size*2 );

    if(r_file_stat(fn+".properties"))
      parse_html(open(fn+".properties","r")->read(), ([]),
		 (["encoding":lambda(string tag, mapping m, string enc) {
				encoding = enc;
			      }]));

    if(encoding)
      encoder = Locale.Charset.encoder(encoding, "");

    real_write = (encoder? write_encoded : real->write);
  }

  Image.Image write( string ... what )
  {
    return real_write(@Array.map( (array(string))what,replace,"�",""))
           ->scale(0.5);
  }
}
#endif

object get_font(string f, int size, int bold, int italic,
		string justification, float xspace, float yspace)
{
  object fnt;
  string key, name, of;
  mixed err;
  f = replace( f, " ", "_" );
  of = f;
  key = f+size+bold+italic+justification+xspace+yspace;

  if(fnt=cache_lookup("fonts", key))
    return fnt;

  err = catch {
    name=make_font_name(f,size,bold,italic);
#if constant(has_Image_TTF)
    if(ttf_font_names_cache[ lower_case(f) ])
    {
      f = lower_case(f);
      if( ttf_font_names_cache[ lower_case(f) ][ (name/"/")[1] ] )
      {
	object fo = Image.TTF( roxen_path(f = ttf_font_names_cache[ lower_case(f) ][(name/"/")[1]] ));
	fo = TTFWrapper( fo(), size, f );
	cache_set("fonts", key, fo);
	return fo;
      }
      object fo = Image.TTF( roxen_path(f = values(ttf_font_names_cache[ lower_case(f) ])[0]));
      return TTFWrapper( fo(), size, f );
    } else if( search( lower_case(f), ".ttf" ) != -1 ) {
      catch {
	if( object fo = Image.TTF( f ) )
	{
	  fo = TTFWrapper( fo(), size, f );
	  cache_set("fonts", key, fo);
	  return fo;
	}
      };
    }
#endif
    fnt = Font();
    foreach(roxen->query("font_dirs"), string f)
    {
      name = fix_name(name);
      if(r_file_stat( f + size + "/" + name ))
      {
	name = f+size+"/"+name;
	break;
      }
    }
    if(!fnt->load( roxen_path( name ) ))
    {
      if(of == replace(roxen->query("default_font")," ","_"))
      {
	report_error("Failed to load the default font ("+f+") in size " + size + ".\n");
	return 0;
      }
      if( search( of, "_" ) != -1 )
        return get_font(of-"_",
                        size,bold,italic,justification,xspace,yspace);
      else
        return get_font(roxen->query("default_font"),
                        size,bold,italic,justification,xspace,yspace);
    }
    if(justification=="right") fnt->right();
    if(justification=="center") fnt->center();
    fnt->set_x_spacing((100.0+(float)xspace)/100.0);
    fnt->set_y_spacing((100.0+(float)yspace)/100.0);
    cache_set("fonts", key, fnt);
    return fnt;
  };
  report_error(sprintf("get_font(): Error opening font %O:\n"
		       "%s\n", f, describe_backtrace(err)));
  // Error if the font-file is not really a font-file...
  return 0;
}

object resolve_font(string f, string|void justification)
{
  int bold, italic;
  float xspace=0.0;
  string a,b;
  if( !f )
    f = roxen->query("default_font");
  f = lower_case( f );
  if(sscanf(f, "%sbold%s", a,b)==2)
  {
    bold=1;
    f = a+b;
  }
  if(sscanf(f, "%sblack%s", a,b)==2)
  {
    bold=2;
    f = a+b;
  }
  if(sscanf(f, "%slight%s", a,b)==2)
  {
    bold=-1;
    f = a+b;
  }
  if(sscanf(f, "%sitalic%s", a,b)==2)
  {
    italic=1;
    f = a+b;
  }
  if(sscanf(f, "%sslant%s", a,b)==2)
  {
    italic=-1;
    f = a+b;
  }
  if(sscanf(f, "%scompressed%s", a,b)==2)
  {
    xspace = -20.0;
    f = a+b;
  }
  if(sscanf(f, "%sspaced%s", a,b)==2)
  {
    xspace = 20.0;
    f = a+b;
  }
  if(sscanf(f, "%scenter%s", a, b)==2)
  {
    justification="center";
  }
  if(sscanf(f, "%sright%s", a, b)==2)
  {
    justification="right";
  }
  int size=32;
  sscanf(f, "%s %d", f, size);
  object fn;
  fn = get_font(f, size, bold, italic,
	      justification||"left",xspace, 0.0);
  if(!fn)
    fn = get_font(roxen->query("default_font"),size,bold,italic,
		  justification||"left",xspace, 0.0);
  if(!fn)
    report_error("failed miserably to open the default font ("+
                 roxen->query("default_font")+")\n");
  return fn;
}

array available_fonts( )
{
  array res = ({});
#if constant(has_Image_TTF)
  // Populate the TTF font cache.
  available_font_versions( "No, there is no such font as this",32 );
#endif
  foreach(roxen->query("font_dirs"), string dir)
  {
    dir+="32/";
    array d;
    if(array d = r_get_dir(dir))
    {
      foreach(d,string f)
      {
	if(f=="CVS") continue;
	array a;
	if((a=r_file_stat(dir+f)) && (a[1]==-2))
	  res |= ({ replace(f,"_"," ") });
      }
    }
  }
  return sort(res|indices(ttf_font_names_cache));
}


void create()
{
  add_constant("get_font", get_font);
  add_constant("available_font_versions", available_font_versions);
  add_constant("describe_font_type", describe_font_type);
  add_constant("get_font_italic_bold", get_font_italic_bold);
  add_constant("resolve_font", resolve_font);
  add_constant("available_fonts", available_fonts);

#if constant(has_Image_TTF)
  catch {
    ttf_font_names_cache =
      decode_value(open("$VVARDIR/ttffontcache","r")->read());
  };
#endif
}
