:- module(
  safe_file,
  [
    safe_copy_file/2, % +From:atom
                      % +To:atom
    safe_delete_file/1, % +File:atom
    safe_move_file/2, % +From:atom
                      % +To:atom
    safe_rename_file/2 % +From:atom
                       % +To:atom
  ]
).

/** <module> Safe file

Support for safe file operations.
A file operation is safe if files that are deleted or changed are saved
to a trashcan instead of being permanently deleted.

@author Wouter Beek
@version 2013/04-2013/06, 2013/09-2014/01, 2014/04
*/

:- use_module(library(debug)).
:- use_module(library(filesex)).

:- use_module(plc(io/dir_ext)).
:- use_module(plc(io/dir_infra)).
:- use_module(plc(io/file_ext)).





safe_copy_file(From, To):-
  access_file(From, read),
  access_file(To, write), !,
  safe_delete_file(To),
  copy_file(From, To),
  debug(safe_file, 'File ~w was safe-copied to ~w.', [From,To]).


%! safe_delete_file(+File:atom) is det.
% Delete the given file, but keep a copy around in thake trashcan.

safe_delete_file(File):-
  \+ exists_file(File), !,
  debug(
    safe_file,
    'File ~w cannot be deleted since it does not exist.',
    [File]
  ).
safe_delete_file(File):-
  access_file(File, write), !,
  absolute_file_name(project(.), ProjectDir, [file_type(directory)]),
  relative_file_name(File, ProjectDir, RelativeFile),
  trashcan(Trashcan),
  directory_file_path(Trashcan, RelativeFile, CopyFile),
  % Copying to a nonexisting directory does not work, so first
  % we need to recursively create the directory.
  file_directory_name(CopyFile, CopyDir),
  create_directory(CopyDir),
  copy_file(File, CopyFile),
  catch(
    (
      delete_file(File),
      debug(safe_file, 'File ~w was safe-deleted.', [File])
    ),
    E,
    debug(safe_file, '~w', [E])
  ).


safe_move_file(From, To):-
  safe_copy_file(From, To),
  safe_delete_file(From),
  debug(safe_file, 'File ~w was safe-moved to ~w.', [From,To]).


safe_rename_file(From, To):-
  access_file(From, write),
  \+ exists_file(To), !,
  rename_file(From, To).
safe_rename_file(From, To):-
  access_file(From, write),
  exists_file(To), !,
  safe_delete_file(To),
  safe_rename_file(From, To),
  debug(safe_file, 'File ~w was safe-renamed to ~w.', [From,To]).

