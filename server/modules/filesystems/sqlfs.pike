// This is a ChiliMoon module. Copyright � 1996 - 2001, Roxen IS.

inherit "module";

constant cvs_version= "$Id: sqlfs.pike,v 1.6 2002/11/11 01:52:34 mani Exp $";

#include <module.h>
#include <roxen.h>
#include <stat.h>

constant thread_safe = 1;
constant module_type = MODULE_LOCATION;
constant module_name = "File systems: SQL File system";
constant module_doc  = "Access files stored in a SQL database";
constant module_unique = 0;

string table, charset, path_encoding;


void create()
{
  defvar("location", "/", "Mount point",
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 "Where the module will be mounted in the site's virtual file system.");

  defvar("db", Variable.DatabaseChoice( "docs", 0,
					"Filesystem database",
					"The database to use") )
    ->set_configuration_pointer( my_configuration );
  
  defvar("table", Variable.TableChoice( "docs", 0, "Filesystem table",
					("The table that cotains the files."
					 " The table should contain at least the "
					 "columns 'name' and 'contents'. Optionally "
					 "you can also have the fields 'mtime', "
					 "'uid' and 'gid'."),
					getvar("db") ) );

  defvar("charset", "iso-8859-1", "File contents charset",
	 TYPE_STRING,
	 ("The charset of the contents of the files on this file "
	  "system. This variable makes it possible for ChiliMoon to use "
	  "any text file, no matter what charset it is written in. If"
	  " necessary, ChiliMoon will convert the file to Unicode before "
	  "processing the file."));

  defvar("path_encoding", "iso-8859-1", "Filename charset",
	 TYPE_STRING,
	 ("The charset of the file names of the files on this file "
	  "system. Unlike the <i>File contents charset</i> variable, "
	  "this might not work for all charsets simply because not "
	  "all browsers support anything except ISO-8859-1 "
	  "in URLs."));
}

void start( )
{
  set_my_db( query( "db" ) );
  table = query("table");
  charset = query("charset");
  path_encoding = query("path_encoding");
}
  


private mapping last_file;
#ifdef THREADS
private Thread.Mutex lfm = Thread.Mutex();
#endif

static string decode_path( string p )
{
  if( path_encoding != "iso-8859-1" )
    p = Locale.Charset.encoder( path_encoding )->feed( p )->drain();

  if( String.width( p ) != 8 )
    p = string_to_utf8( p );

  return p;
}

static array low_stat_file( string f, RequestID id )
{
  if( f == "/" )
    return dir_stat;
  if( has_value( f, "%" ) )
    return 0;
#ifdef THREADS
  Thread.MutexKey k = lfm->lock();
#endif
  if( !last_file || last_file->name != f )
  {
    array r = sql_query( "SELECT * FROM "+table+" WHERE name=%s", f );
    if( sizeof( r ) )
    {
      last_file = r[0];
      if( charset != "iso-8859-1" )
      {
	if( id->set_output_charset )
	  id->set_output_charset( charset, 2 );
        id->misc->input_charset = charset;
      }
    }
  }
  if( last_file && last_file->name == f )
    return
      ({
	({
	  0777,
	  strlen(last_file->contents||""),
	  time(),
	  ((int)last_file->mtime)+1,
	  ((int)last_file->mtime)+1,
	  (int)last_file->uid,
	  (int)last_file->gid,
	}),
	last_file
      });

  if( f[-1] != '/' ) f+= "/";
  if( sizeof( sql_query( "SELECT name FROM  "+
			 table+" WHERE name LIKE %s  LIMIT 1",
			 f+"%" ) ) )
    return ({ dir_stat, 0 });
  return ({ 0, 0 });
}

constant dir_stat = ({	0777|S_IFDIR, -1, 10, 10, 10, 0, 0 });

//  --- MODULE_LOCATION API

Stat stat_file( string f, RequestID id )
{
  return low_stat_file( decode_path( "/"+f ), id )[0];
}

int|object find_file(  string f, RequestID id )
{
  if( !strlen( f ) )
    return -1;
  f = decode_path( "/"+f );
  [array st,mapping d] = low_stat_file( f, id );
  if( !st )            return 0;
  if( st[1] == -1 )    return -1;
  id->misc->stat = st;
  return StringFile( d->contents||"" );
}

array(string) find_dir( string f, RequestID id )
{
  f = decode_path( "/"+f );

  if(  f[-1] != '/' )
    f += "/";

  multiset dir = (<>);

  foreach( sql_query( "SELECT name FROM "+table+" WHERE name LIKE %s",f+"%")
	   ->name, string p )
    dir[ (p[ strlen(f) .. ] / "/")[0] ] = 1;

  return (array)dir;
}
