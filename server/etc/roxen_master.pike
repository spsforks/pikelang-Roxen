#define UNDEFINED (([])[0])
#if efun(version)
#define VERSION		version()
#else
#if efun(__version)
#define VERSION		__version()
#else
#define VERSION		"Pike v0.4pl2"
#endif /* __version */
#endif /* version */

string describe_backtrace(mixed *trace);

string cvs_version = "$Id: roxen_master.pike,v 1.16.2.7 1997/03/02 19:20:50 grubba Exp $";

object stdout, stdin;
mapping names=([]);
int unique_id=time();

mapping (string:string) environment=([]);

constant mm=master();
inherit mm;

varargs mixed getenv(string s)
{
  if(!s) return environment;
  return environment[s];
}

void putenv(string var, string val)
{
  environment[var]=val;
}

mapping (string:program) programs=(["/master":object_program(this_object())]);

string program_name(program p)
{
  return search(programs, p);
}

#define capitalize(X)	(upper_case((X)[..0])+(X)[1..])

/* NEW in Pike 0.4pl9
 *
 *
 */
static program low_findprog(string pname, string ext)
{
  program ret;
  string fname=pname+ext;

  if(ret=programs[fname]) return ret;

  if(file_stat(fname)) {
    switch(ext) {
    case "":
    case ".pike":
      ret = compile_file(fname);
      break;
    case ".so":
#if constant(_static_modules)
      ret = load_module(fname);
#else
      ret = object_program(load_module(fname));
#endif /* _static_modules */
    }
    return programs[fname]=ret;
  } else {
    return UNDEFINED;
  }
}

static program findprog(string pname, string ext)
{
  switch(ext)
  {
  case ".pike":
  case ".so":
    return low_findprog(pname,ext);
 
  default:
    pname+=ext;
    return
      low_findprog(pname,"") ||
      low_findprog(pname,".pike") ||
      low_findprog(pname,".so");
  }
}


/* This function is called whenever a module has built a clonable program
 * with functions written in C and wants to notify the Pike part about
 * this. It also supplies a suggested name for the program.
 *
 * OBSOLETE in Pike 0.4pl9
 */
void add_precompiled_program(string name, program p)
{
  if (p) {
    programs[name]=p;

    if(sscanf(name,"/precompiled/%s",name)) {
      string const="";
      foreach(reverse(name/"/"), string s) {
	const = capitalize(s) + const;
	add_constant(const, p);
      }
    }
  } else {
    throw(({ sprintf("add_precompiled_program(): Attempt to add NULL program \"%s\"\n",
		     name), backtrace() }));
  }
}

#if 0
/* This function is called when the driver wants to cast a string
 * to a program, this might be because of an explicit cast, an inherit
 * or a implict cast. In the future it might receive more arguments,
 * to aid the master finding the right program.
 */
program cast_to_program(string pname, string current_file)
{
  string ext;

  if (sscanf(reverse(pname),"%s.%s",ext,pname))
  {
    ext="."+reverse(ext);
    pname=reverse(pname);
  }else{
    ext="";
  }
  if(pname[0]=='/') {
    pname = combine_path("/",pname);
    return findprog(pname, ext);
  } else {
    string cwd;
    if (current_file) {
      string *tmp=current_file/"/";
      cwd=tmp[..sizeof(tmp)-2]*"/";
    }else{
      cwd=getcwd();
    }

    if (program ret=findprog(combine_path(cwd,pname),ext))
      return ret;

    foreach(pike_include_path, string path)
      if(program ret=findprog(combine_path(path,pname),ext))
        return ret;

    return 0;
  }
}

#endif /* 0 */

/* This function is called when an error occurs that is not caught
 * with catch(). It's argument consists of:
 * ({ error_string, backtrace }) where backtrace is the output from the
 * backtrace() efun.
 */
void handle_error(mixed *trace)
{
  predef::trace(0);
  catch{werror(describe_backtrace(trace));};
}

object new(mixed prog, mixed ... args)
{
  if (stringp(prog))
    prog=cast_to_program(prog,backtrace()[-2][0]);
  return prog(@args);
}

/* Note that create is called before add_precompiled_program
 */
void create()
{
  foreach(indices(mm), string varname) {
    catch(this_object()[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }
  /* make ourselves known */
  add_constant("add_include_path",add_include_path);
  add_constant("remove_include_path",remove_include_path);
  add_constant("add_module_path",add_module_path);
  add_constant("remove_module_path",remove_module_path);
  add_constant("_master",this_object());
  add_constant("master",lambda() { return this_object(); });
  add_constant("describe_backtrace",describe_backtrace);
  add_constant("version",lambda() { return VERSION + " Roxen Challenger master"; });
  add_constant("mkmultiset",lambda(mixed *a) { return aggregate_multiset(@a); });
  add_constant("strlen",sizeof);
  add_constant("new",new);
  add_constant("clone",new);

  random_seed(time() + (getpid() * 0x11111111));
}

/*
 * This function is called whenever a inherit is called for.
 * It is supposed to return the program to inherit.
 * The first argument is the argument given to inherit, and the second
 * is the file name of the program currently compiling. Note that the
 * file name can be changed with #line, or set by compile_string, so
 * it can not be 100% trusted to be a filename.
 * previous_object(), can be virtually anything in this function, as it
 * is called from the compiler.
 */
program handle_inherit(string pname, string current_file)
{
  return cast_to_program(pname, current_file);
}

mapping (program:object) objects=([object_program(this_object()):this_object()]);

/* This function is called when the drivers wants to cast a string
 * to an object because of an implict or explicit cast. This function
 * may also receive more arguments in the future.
 */
object cast_to_object(string oname, string current_file)
{
  program p;
  object o;

  p = cast_to_program(oname, current_file);
  if (!p) {
    return 0;
  }
  if (!(o = objects[p])) {
    o = objects[p]=p();
  }
  return(o);
}

class dirnode
{
  string dirname;
  void create(string name) { dirname=name; }
  object|program `[](string index)
  {
    index=dirname+"/"+index;
    if(object o=((object)"/master")->findmodule(index)) {
      if(mixed tmp=o->_module_value) {
	return tmp;
      }
      return o;
    }
    return (program) index;
  }
};

class mergenode
{
  mixed *modules;
  void create(mixed *m) { modules=m; }
  mixed `[](string index)
  {
    foreach(modules, mixed mod)
      if (mixed ret=mod[index]) return ret;
    return UNDEFINED;
  }
};

object findmodule(string fullname)
{
  mixed *stat;
  program p;

  if(mixed *stat=file_stat(fullname+".pmod"))
  {
    if(stat[1]==-2)
      return dirnode(fullname+".pmod");
    else
      return (object)(fullname+".pmod");
  }

#if constant(load_module)
  if(file_stat(fullname+".so")) {
    return (object)(fullname);
  }
#endif

#ifdef NOT_INSTALLED
  /* Hack for pre-install testing */
  if(mixed *stat=file_stat(fullname))
  {
    if(stat[1]==-2)
      return findmodule(fullname+"/module");
  }
#endif

#if constant(_static_modules)
  return(_static_modules[fullname]);
#endif /* _static_modules */

  return UNDEFINED;
}

varargs mixed resolv(string identifier, string current_file)
{
  mixed ret;
  string *tmp,path;
  multiset tested=(<>);
  mixed *modules=({});

  if (current_file) {
    tmp=current_file/"/";
    tmp[-1]=identifier;
    path=combine_path(getcwd(), tmp*"/");
    ret=findmodule(path);
  }

  if (!ret) {
    foreach(pike_module_path, path) {
      string file=combine_path(path,identifier);
      if(ret=findmodule(file)) break;
    }
  }
  
  if (!ret) {
    string path=combine_path(pike_library_path+"/modules",identifier);
    ret=findmodule(path);
  }

  if (!ret) {
    ret=findmodule(identifier);
  }

  if (ret) {
    if (programp(ret)) {
      ret = ret();
    }
    if (mixed tmp=ret->_module_value) return tmp;
    return ret;
  }
  return UNDEFINED;
}

/* This function is called when all the driver is done with all setup
 * of modules, efuns, tables etc. etc. and is ready to start executing
 * _real_ programs. It receives the arguments not meant for the driver
 * and an array containing the environment variables on the same form as
 * a C program receives them.
 */
void _main(string *argv, string *env)
{
  int i;
  object script;
  object tmp;
  string a,b;
  mixed *q;

  foreach(env,a) if(sscanf(a,"%s=%s",a,b)) environment[a]=b;
  add_constant("getenv",getenv);
  add_constant("environment",environment);
  add_constant("putenv",putenv);
  add_constant("error",lambda(string s, mixed ... args) {
    if(sizeof(args)) s=sprintf(s, @args);
    throw(({ s, backtrace()[1..] }));
  });

  /* pike_library_path must be set before idiresolv is called */
  a=backtrace()[-1][0];
  q=a/"/";
  pike_library_path = q[0..sizeof(q)-2] * "/";

  add_include_path(pike_library_path+"/include");
  add_module_path(pike_library_path+"/modules");
 
  q=(getenv("PIKE_INCLUDE_PATH")||"")/":"-({""});
  for(i=sizeof(q)-1;i>=0;i--) add_include_path(q[i]);
 
  q=(getenv("PIKE_MODULE_PATH")||"")/":"-({""});
  for(i=sizeof(q)-1;i>=0;i--) add_module_path(q[i]);

#if constant(_static_modules)
  /* Pike 0.4pl9 or later */
  add_constant("write", _static_modules.files()->file("stdout")->write);
  add_constant("stdin", _static_modules.files()->file("stdin"));
  add_constant("stdout",_static_modules.files()->file("stdout"));
  add_constant("stderr",_static_modules.files()->file("stderr"));
  /*
   * Backward compatibility
   */
#if 0
  add_precompiled_program("/precompiled/file", _static_modules.files()->file);
  add_precompiled_program("/precompiled/port", _static_modules.files()->port);
  add_precompiled_program("/precompiled/regexp", resolv("Regexp", pike_library_path+"/modules/"));
  /*  add_precompiled_program("/precompiled/image", resolv("Image", pike_library_path+"/modules/")->image); */
  add_precompiled_program("/precompiled/font", resolv("Image", pike_library_path+"/modules/")->font);
  add_precompiled_program("/precompiled/pipe", resolv("Pipe", pike_library_path+"/modules/")->pipe);
#if !efun(mark_fd)
  resolv("spider", pike_library_path+"/modules/");
#endif

#endif /* 0 */

//  add_precompiled_program("/precompiled/pipe",
//			    object_program(resolv("Pipe",
//						  pike_library_path+"/modules/")));

#else
  add_constant("write",cast_to_program("/precompiled/file","/")("stdout")->write);
  add_constant("stdin",cast_to_program("/precompiled/file","/")("stdin"));
  add_constant("stdout",cast_to_program("/precompiled/file","/")("stdout"));
  add_constant("stderr",cast_to_program("/precompiled/file","/")("stderr"));
#endif

//  clone(compile_file(pike_library_path+"/simulate.pike"));

#if efun(version) || efun(__version)
  /* In Pike 0.4pl2 and later the full command-line is passed 
   * to the master.
   *
   * The above test should work for everybody except those who
   * have Pike 0.4pl2 without __version (probably nobody).
   */

#if constant(_static_modules)
  tmp=resolv("Getopt");
#else
  tmp=new("include/getopt.pre.pike");
#endif /* _static_modules */

  q = tmp->find_all_options(argv,({
    ({"version",tmp->NO_ARG,({"-v","--version"})}),
    ({"help",tmp->NO_ARG,({"-h","--help"})}),
    ({"execute",tmp->HAS_ARG,({"-e","--execute"})}),
    ({"modpath",tmp->HAS_ARG,({"-M","--module-path"})}),
    ({"ipath",tmp->HAS_ARG,({"-I","--include-path"})}),
    ({"ignore",tmp->HAS_ARG,"-ms"}),
    ({"ignore",tmp->MAY_HAVE_ARG,"-Ddatpl",0,1})}),1);

  /* Parse -M and -I backwards */
  for(i=sizeof(q)-1;i>=0;i--)
  {
    switch(q[i][0])
    {
      case "modpath":
        add_module_path(q[i][1]);
        break;
 
      case "ipath":
        add_include_path(q[i][1]);
        break;
    }
  }

  foreach(q, mixed *opts)
    {
      switch(opts[0])
      {
      case "version":
	werror(VERSION + " Copyright (C) 1994-1997 Fredrik H�binette\n"
	       "Pike comes with ABSOLUTELY NO WARRANTY; This is free software and you are\n"
	       "welcome to redistribute it under certain conditions; Read the files\n"
	       "COPYING and DISCLAIMER in the Pike distribution for more details.\n");
	exit(0);
      case "help":
	werror("Usage: pike [-driver options] script [script arguments]\n"
	       "Driver options include:\n"
	       " -I --include-path=<p>: Add <p> to the include path\n"
	       " -M --module-path=<p> : Add <p> to the module path\n"
	       " -e --execute=<cmd>   : Run the given command instead of a script.\n"
	       " -h --help            : see this message\n"
	       " -v --version         : See what version of pike you have.\n"
	       " -s#                  : Set stack size\n"
	       " -m <file>            : Use <file> as master object.\n"
	       " -d -d#               : Increase debug (# is how much)\n"
	       " -t -t#               : Increase trace level\n"
	       );
	exit(0);

      case "execute":
	compile_string("#include <simulate.h>\nmixed create(){"+opts[1]+";}")();
	break;
      }
    }

  argv=tmp->get_args(argv,1);
  destruct(tmp);
  
  /*
   * Search base_server also
   */
  add_include_path("base_server");

  if(sizeof(argv) == 1) {
    argv=argv[0]/"/";
    argv[-1]="hilfe";
    argv=({ argv*"/" });
    if(!file_stat(argv[0])) {
      if(file_stat("/usr/local/bin/hilfe"))
	argv[0]="/usr/local/bin/hilfe";
      else if(file_stat("../bin/hilfe"))
	argv[0]="/usr/local/bin/hilfe";
      else {
	werror("Couldn't find hilfe.\n");
	exit(1);
      }
    }
  } else {
    argv=argv[1..];
  }
#endif /* version or __version */

  if (!sizeof(argv))
  {
    werror("Usage: pike [-driver options] script [script arguments]\n");
    exit(1);
  }

  program tmp = (program)argv[0];
#if 0
  if (catch(tmp=(program)argv[0]) || (!tmp)) {
    tmp = compile_file(argv[0]+".pike");
  }
#endif /* 0 */
  if(!tmp)
  {
    werror("Pike: Couldn't find script to execute.\n");
    exit(1);
  }
 
  object script=tmp();

  if(!script->main)
  {
    werror("Error: "+argv[0]+" has no main().\n");
    exit(1);
  }

  i=script->main(sizeof(argv),argv,env);
  if(i >=0) exit(i);
}

mixed inhibit_compile_errors;

string errors;
string set_inhibit_compile_errors(mixed f)
{
  mixed fr = errors||"";
  inhibit_compile_errors=f;
  errors="";
  return fr;
}

/*
 * This function is called whenever a compiling error occurs,
 * Nothing strange about it.
 * Note that previous_object cannot be trusted in ths function, because
 * the compiler calls this function.
 */

void compile_error(string file,int line,string err)
{
  if(!inhibit_compile_errors)
  {
    werror(sprintf("%s:%d:%s\n",file,line,err));
  }
  else if(functionp(inhibit_compile_errors))
  {
    inhibit_compile_errors(file,line,err);
  } else
    errors+=sprintf("%s:%d:%s\n",file,line,err);
}

#if 0
/* This function is called whenever an #include directive is encountered
 * it receives the argument for #include and should return the file name
 * of the file to include
 * Note that previous_object cannot be trusted in ths function, because
 * the compiler calls this function.
 */
string handle_include(string f,
		      string current_file,
		      int local_include)
{
  string *tmp, path;

  if(local_include)
  {
    tmp=current_file/"/";
    tmp[-1]=f;
    path=combine_path(getcwd(),tmp*"/");
    if(!file_stat(path)) {
      return 0;
    }
  }
  else
  {
    foreach(pike_include_path, path)
      {
	path=combine_path(path,f);
	if(file_stat(path))
	  break;
	else
	  path=0;
      }
    
    if(!path)
    {
      path=combine_path(pike_library_path+"/include",f);
      if(!file_stat(path)) path=0;
    }
  }

  if(path)
  {
    /* Handle preload */

    if(path[-1]=='h' && path[-2]=='.' &&
       file_stat(path[0..sizeof(path)-2]+"pre.pike"))
    {
      cast_to_object(path[0..sizeof(path)-2]+"pre.pike", "/");
    }
  }

  return path;
}

#endif /* 0 */

// FIXME
string stupid_describe(mixed m)
{
  switch(string typ=sprintf("%t",m))
  {
  case "int":
  case "float":
    return (string)m;
 
  case "string":
    if(sizeof(m) < 60 && sscanf(m,"%*[-a-zAZ0-9.~`!@#$%^&*()_]%n",int i) && i==sizeof(m))
    {
      return "\""+m+"\"";
    }
 
  case "array":
  case "mapping":
  case "multiset":
    return typ+"["+sizeof(m)+"]";
 
  default:
    return sprintf("%t",m);
  }
}

/* It is possible that this should be a real efun,
 * it is currently used by handle_error to convert a backtrace to a
 * readable message.
 */
string describe_backtrace(mixed *trace)
{
  int e;
  string ret;
  string wd = getcwd();

  if(arrayp(trace) && sizeof(trace)==2 && stringp(trace[0]))
  {
    ret=trace[0];
    trace=trace[1];
  }else{
    ret="";
  }

  if(!arrayp(trace))
  {
    ret+="No backtrace.\n";
  }else{
    for(e=sizeof(trace)-1;e>=0;e--)
    {
      mixed tmp;
      string row;

      tmp=trace[e];
      if(stringp(tmp))
      {
	row=tmp;
      }
      else if(arrayp(tmp))
      {
	row="";
	if(sizeof(tmp)>=3 && functionp(tmp[2]))
	{
#if constant(_static_modules)
	  row=function_name(tmp[2])+"(";
	  for(int v=3;v<sizeof(tmp);v++) {
	    row+=stupid_describe(tmp[v])+",";
	  }
	  row=row[..sizeof(row)-2]+") in ";
#else
	  row=function_name(tmp[2])+" in ";
#endif /* _static_modules */
	}

	if(sizeof(tmp)>=2 && stringp(tmp[0]) && intp(tmp[1]))
	{
	  row+="line "+tmp[1]+" in "+((tmp[0]-(wd+"/"))-"base_server/");
	}else{
	  row+="Unknown program";
	}
      }
      else
      {
	row="Destructed object";
      }
      ret+=row+"\n";
    }
  }

  return ret;
}

