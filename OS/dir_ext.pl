:- module(dir_ext,
  [
    append_directories/3, % +Dir1:atom
                          % +Dir2:atom
                          % -Dir3:atom
    create_personal_subdirectory/2, % +NestedDirectories:compound
                                    % -AbsoluteDirectory:atom
    create_project_subdirectory/2, % +NestedDirectories:compound
                                   % -AbsoluteDirectory:atom
    create_directory/1, % +Directory:atom
    create_nested_directory/1, % +NestedDirectories:compound
    create_nested_directory/2, % +NestedDirectories:compound
                               % -Absolute:atom
    directory_files/3, % +Options:list(nvpair)
                       % +Directory:atom
                       % -Absolutes:list(atom)
    directory_to_subdirectories/2, % +Directory:atom
                                   % -Subdirectories:list(atom)
    experiment_directory/1, % -Directory:atom
    safe_copy_directory/2, % +FromDirectory:atom
                           % +ToDirectory:atom
    safe_copy_experiment_data/2, % +FromDirectory:atom
                                 % -ToDirectory:atom
    safe_delete_directory/1, % +Directory:atom
    safe_delete_directory_contents/2, % +Options:list(nvpair)
                                      % +Directory:atom
    subdirectories_to_directory/2, % +Subdirectories:list(atom)
                                   % -Directory:atom
    trashcan/1 % -Directory:atom
  ]
).

/** <module> Directory extensions

Extensions for handling directories.

@author Wouter Beek
@tbd Add safe_delete_directory/1.
@version 2013/06-2013/07, 2013/09
*/

:- use_module(generics(atom_ext)).
:- use_module(generics(db_ext)).
:- use_module(generics(meta_ext)).
:- use_module(library(apply)).
:- use_module(library(debug)).
:- use_module(library(lists)).
:- use_module(os(file_ext)).

:- debug(dir_ext).



%! append_directories(+Dir1:atom, +Dir2:atom, -Dir3:atom) is det.

append_directories(Dir1, Dir2, Dir3):-
  directory_to_subdirectories(Dir1, Subdirs1),
  directory_to_subdirectories(Dir2, Subdirs2),
  append(Subdirs1, Subdirs2, Subdirs3),
  subdirectories_to_directory(Subdirs3, Dir3),
  create_directory(Dir3).

%! create_directory(+Dir:atom) is det.
% Creates a directory with the given name.
%
% @param Dir The atomic name of a directory.

% The directory already exists, so do nothing.
create_directory(Dir):-
  exists_directory(Dir), !.
% The directory does not already exist, so create it.
create_directory(Dir):-
  is_absolute_file_name(Dir), !,
  directory_to_subdirectories(Dir, SubDirs),
  % Recursively assert all subpaths.
  % The root node is indicated by the empty atom.
  create_directory('', SubDirs).

create_directory(_CurrentDir, []):- !.
create_directory(CurrentDir, [NextSubDir|SubDirs]):-
  directory_file_path(CurrentDir, NextSubDir, Dir),
  (
    exists_directory(Dir)
  ;
    make_directory(Dir)
  ), !,
  create_directory(Dir, SubDirs).

create_nested_directory(NestedDir):-
  create_nested_directory(NestedDir, _Absolute).

%! create_nested_directory(
%!   +NestedDirectory:compound,
%!   -AbsoluteDirectory:atom
%! ) is det.
% Returns a nested file path.
%
% @param NestedDir A compound term of linearly nested atoms
%      representing the subsequent subdirectories. The final atom
%      is the name of the file.
% @param Absolute The absolute path of the nested directory specification.

create_nested_directory(Absolute, Absolute):-
  atomic(Absolute), is_absolute_file_name(Absolute), !,
  create_directory(Absolute).
create_nested_directory(NestedDir, Absolute):-
  atom(NestedDir), !,
  Spec =.. [NestedDir, '.'],
  absolute_file_name(Spec, Absolute),
  create_directory(Absolute).
create_nested_directory(NestedDir, Absolute):-
  % First we construct the atomic name of the outer directory.
  NestedDir =.. [NestedOuter, NestedInner],
  create_nested_directory(NestedOuter, AbsoluteOuter),
  % Then we add the inner directories recursively.
  create_nested_directory(NestedInner, AbsoluteOuter, Absolute).

%! create_nested_directory(
%!   +NestedDirectory:compound,
%!   +OldAbsoluteDirectory:atom,
%!   -NewAbsoluteDirectory:atom
%! ) is det.
% Adds the nested directories term to the given atomic directory,
% returning another atomic directory.

create_nested_directory(SubDir, OldDir, NewDir):-
  atom(SubDir), !,
  % Note that adding the option =|file_type(directory)|= makes this clause
  % throw an exception, because this option assumed that the directory
  % exists.
  atomic_list_concat([OldDir, '/', SubDir], NewDir),
  create_directory(NewDir).
create_nested_directory(NestedDir, OldDir, NewDir):-
  NestedDir =.. [OuterDir, InnerNestedDir],
  % Note that adding the option =|file_type(directory)|= makes this clause
  % throw an exception, because this option assumes that the directory
  % exists.
  atomic_list_concat([OldDir, '/', OuterDir], TempDir),
  create_directory(TempDir),
  create_nested_directory(InnerNestedDir, TempDir, NewDir).

%! create_personal_directory is det.
% Asserts the home directory of the current user as a Prolog search path.

create_personal_directory:-
  file_search_path(personal, _), !.
create_personal_directory:-
  % Make sure that the project name has been asserted.
  current_predicate(project_name/1),
  expand_file_name('~', [Home]),
  db_add_novel(user:file_search_path(home, Home)),
  project_name(Project),
  hidden_file_name(Project, Hidden),
  create_nested_directory(home(Hidden), _Dir),
  db_add_novel(user:file_search_path(personal, home(Hidden))).

%! create_personal_subdirectory(
%!   +NestedDirectories:compound,
%!   -AbsoluteDirectory:atom
%! ) is det.
% Asserts a project-specific directory that is a direct subdirectory of the
% current user's home.
%
% This can be used to write files to. Something that is not guaranteed for
% the location where the code is run from.
%
% This requires that the project name has been set using project_name/1.

create_personal_subdirectory(Nested, Abs):-
  create_personal_directory,
  create_nested_directory(personal(Nested), Abs).

%! create_project_subdirectory(
%!   +NestedDirectories:compound,
%!   -AbsoluteDirectory:atom
%! ) is det.

create_project_subdirectory(Nested, Abs):-
  create_nested_directory(project(Nested), Abs).

%! directory_files(
%!   +Options:list(nvpair),
%!   +Directory:atom,
%!   -AbsoluteFiles:list(atom)
%! ) is det.
% Variant of directory_files/2 that returns absolute file names
% instead of relative ones and excludes non-file entries.
%
% The following options are supported:
%   * =|file_types(+FileTypes:list(atom))|=
%     A list of atomic file types that are used as a filter.
%     Default: no file type filter.
%   * =|include_directories(+Include:boolean)|=
%     Whether (sub)directories are included or not.
%     Default `false`.
%   * =|recursive(+Recursive:boolean)|=
%     Whether subdirectories are searched recursively.
%     Default `true`.
%
% @param Options A list of name-value pairs.
% @param Directory The atomic name of a directory.
% @param AbsoluteFiles a list of atomic names of absolute file names.
%
% @see directory_files/2

directory_files(O1, X, Sol):-
  \+ is_list(X), !,
  directory_files(O1, [X], Sol).
% Done!
directory_files(_O1, [], []):- !.
% Non-file entry.
directory_files(O1, [Dir|T], Sol):-
  directory_to_subdirectories(Dir, SubDirs),
  last(SubDirs, '.'), !,
  directory_files(O1, T, Sol).
% Non-file entry.
directory_files(O1, [Dir|T], Sol):-
  directory_to_subdirectories(Dir, SubDirs),
  last(SubDirs, '..'), !,
  directory_files(O1, T, Sol).
% Directories.
directory_files(O1, [Dir|T1], Sol2):-
  file_name_type(_Base1, directory, Dir), !,

  % From directory to files.
  directory_files(Dir, NewFs1),

  % Make the file names absolute.
  maplist(directory_file_path(Dir), NewFs1, NewFs2),

  % Add to stack.
  append(T1, NewFs2, T2),

  % Recurse.
  directory_files(O1, T2, Sol1),

  % Whether directories are included or not.
  (
    option(include_directories(false), O1, false)
  ->
    Sol2 = Sol1
  ;
    Sol2 = [Dir|Sol1]
  ).
% Files with matching file type.
directory_files(O1, [F|T1], [F|Sol]):-
  file_name_type(_Base, FT, F),

  % File type filter.
  option(file_types(FTs), O1, [_]),
  memberchk(FT, FTs), !,

  directory_files(O1, T1, Sol).
% Files with non-matching file type.
directory_files(O1, [_|T], Sol):-
  directory_files(O1, T, Sol).

experiment_directory(Dir):-
  experiment_directory_init,
  absolute_file_name(
    personal('Experiment'),
    Dir,
    [access(write),file_type(directory)]
  ).

experiment_directory_init:-
  file_search_path(experiment, _Dir), !.
experiment_directory_init:-
  create_personal_subdirectory('Experiment', Absolute),
  db_add_novel(user:file_search_path(experiment, Absolute)).

safe_copy_directory(FromDir, ToDir):-
  safe_delete_directory(ToDir),
  copy_directory(FromDir, ToDir),
  debug(dir_ext, 'Directory ~w was safe-copied to ~w.', [FromDir,ToDir]).

safe_copy_experiment_data(FromDir, ToDir):-
  % Make sure this is a directory name.
  exists_directory(FromDir),

  % Assemble a new directory name based on the two given directory names.
  experiment_directory(ExperimentDir),
  append_directories(ExperimentDir, FromDir, ToDir),

  % Recreate the copied directory in the context of
  % the experiment directory.
  create_directory(ToDir),

  % Now do the actual copying.
  safe_copy_directory(FromDir, ToDir).

%! directory_to_subdirectories(
%!   +Directory:atom,
%!   -Subdirectories:list(atom)
%! ) is det.

directory_to_subdirectories(Dir, Subdirs):-
  is_absolute_file_name(Dir), !,
  split_atom_exclusive(['/'], Dir, [_|Subdirs]).
directory_to_subdirectories(Dir, Subdirs):-
  split_atom_exclusive(['/'], Dir, Subdirs).

safe_delete_directory(FromDir):-
  trashcan(Trashcan),
  append_directories(Trashcan, FromDir, ToDir),
  copy_directory(FromDir, ToDir),
  delete_directory_and_contents(FromDir),
  debug(dir_ext, 'Directory ~w was safe-deleted.', [FromDir]).

%! safe_delete_directory_contents(
%!   +Options:list(nvpair),
%!   +Directory:atom
%! ) is det.
% Deletes all file in the given directory that are of the given file type.
%
% The following options are supported:
%   * =|file_types(+FileTypes:list(atom))|=
%     A list of atomic file types that are used as a filter.
%     Default: no file type filter.
%   * =|include_directories(+Include:boolean)|=
%     Whether (sub)directories are included or not.
%     Default `false`.
%   * =|recursive(+Recursive:boolean)|=
%     Whether subdirectories are searched recursively.
%     Default `true`.
%
% @param Options A list of name-value pairs.
% @param Directory The atomic name of a directory.
%
% @throws existence_error In case a file type is not registered.

safe_delete_directory_contents(O1, Dir):-
  % Recurse over the given file type, since it may be associated with
  % multiple extensions.
  directory_files(O1, Dir, Fs),

  % Delete all files.
  % This may throw permission exceptions.
  maplist(safe_delete_file, Fs).

subdirectories_to_directory(Subdirs, Dir2):-
  atomic_list_concat(Subdirs, '/', Dir1),
  atomic_concat('/', Dir1, Dir2).

trashcan(Dir):-
  trashcan_init,
  absolute_file_name(
   personal('Trash'),
    Dir,
    [access(write),file_type(directory)]
  ).

trashcan_init:-
  file_search_path(trash, _Dir), !.
trashcan_init:-
  create_personal_subdirectory('Trash', Absolute),
  db_add_novel(user:file_search_path(trash, Absolute)).

