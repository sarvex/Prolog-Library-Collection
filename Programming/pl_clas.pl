:- module(
  pl_clas,
  [
    process_options/1, % -RemainingOptions:list(nvpair)
    read_options/1, % -Options:list(nvpair)
    set_data_path/0
  ]
).

/** <module> Prolog command line arguments

Support for command line arguments given at Prolog startup.

@author Wouter Beek
@version 2014/03
*/

:- use_module(generics(typecheck)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(lists)).

:- multifile(prolog:message//1).

%! cmd_option(?Short:atom, ?Long:atom, ?Type:atom, ?Comment:atom) is nondet.
% Command line options registration.
%
% @arg Short The short, i.e. one-character, name of the command-line option.
% @arg Long The long, i.e. multi-character, name of the command-line option.
% @arg Type The type of a command-line option.
%      These types are registered in module [typecheck].
% @arg Comment A human-readable description of the command-line option.

:- multifile(user:cmd_option/4).


%! process_cmd_option(+Options:nvpair) is semidet.
% Processes a single option.

:- multifile(user:process_cmd_option/1).


%! process_cmd_options(+Options1:list(nvpair), -Options2:list(nvpair)) is det.
% Runs on all options at once.
%
% This can be used to remove duplicates,
% to check whether some option does not occur,
% or to remove options based on the presence of others.

:- multifile(user:process_cmd_options/2).



% Option: data.

user:cmd_option(_, data, atom, 'Directory where data is read and written.').

user:process_cmd_option(data(Dir1)):-
  absolute_file_name(Dir1, Dir2, [access(write),file_type(directory)]), !,
  set_data_path(Dir2).
user:process_cmd_option(data(Dir)):-
  print_message(warning, incorrect_path(Dir)).

prolog:message(incorrect_path(Dir)) -->
  `The given value could not be resolved to a directory: ~w`,
  atom(Dir), nl.


% Option: debug.

user:cmd_option(d, debug, boolean,
    'Run in debug mode. This shows debug messages and loads debug tools.').

user:process_cmd_option(debug(true)):-
  assert(user:debug_mode).
user:process_cmd_option(debug(false)).


% Option: help.

user:cmd_option(h, help, boolean,
    'Gives an overview of supported command-line options.').

user:process_cmd_option(help(true)):-
  forall(
    user:cmd_option(Short, Long, _, Comment),
    describe_option(Short, Long, Comment)
  ).
user:process_cmd_option(help(false)).

% Help obsoletes all other options.
% (Help takes priority over version.)
user:process_cmd_options(O1, [help(true)]):-
  memberchk(help(true), O1), !.


% Option: version.

user:cmd_option(v, version, boolean, 'Display version information.').

user:process_cmd_option(version(true)):-
  forall(
    user:project(ProjectName, ProjectDescription),
    format(user_output, '    ~w~t~w\n', [ProjectName,ProjectDescription])
  ).
user:process_cmd_option(version(false)).

% Version obsoletes all other options.
% (Help takes priority over version.)
user:process_cmd_options(O1, [version(true)]):-
  memberchk(version(true), O1), !.



%! describe_option(?Short:atom, +Long:atom, +Comment:atom) is det.
% Writes a description for the given command-line option.

describe_option(Short, Long, Comment):-
  var(Short), !,
  format(user_output, '    --~w~t~40|~w~n', [Long,Comment]).
describe_option(Short, Long, Comment):-
  format(user_output, '    -~w, --~w~t~40|~w~n', [Short,Long,Comment]).


%! long_option(+Name:atom, +Value:atom, -Option:compound) is det.
% Constructs a long option compound term of the form `NAME=VALUE`,
% where `VALUE` can be of any type.

long_option(Long, Value1, Option) :-
  user:cmd_option(_, Long, Type, _),
  atom_to_value(Value1, Type, Value2),
  Option =.. [Long,Value2].


%! long_option(+Name:atom, -Option:compound) is det.
% Constructs a long option compound term of the form `NAME` or `no-NAME`,
% representing a boolean value of either `true` or `false` respectively.
%
% This *only* works for options of type boolean.

% Option with boolean value `false`.
long_option(Long1, Option):-
  atom_concat('no-', Long2, Long1),
  user:cmd_option(_, Long2, boolean, _), !,
  Option =.. [Long2,false].
% Option with boolean value `true`.
long_option(Long, Option):-
  user:cmd_option(_, Long, boolean, _),
  Option =.. [Long,true].


%! parse_options(
%!   +CommandLineArguments:list,
%!   -ParsedOptions:list,
%!   -Rest:list
%! ) is det.

parse_options([], [], []):- !.
% A singular `--` that does not prefix a long option
% separates the parsed options from the rest.
parse_options([--|Rest], [], Rest):- !.
% A long option.
parse_options([H|T], [Option|Options], Rest):-
  sub_atom(H, 0, _, _, --), !,
  % A long name-value option,
  % or a name option.
  (
    sub_atom(H, B, _, A, =)
  ->
    B2 is B - 2,
    sub_atom(H, 2, B2, _, Long),
    sub_atom(H, _, A,  0, Value),
    long_option(Long, Value, Option)
  ;
    sub_atom(H, 2, _, 0, Long),
    long_option(Long, Option)
  ),
  parse_options(T, Options, Rest).
% A short option.
parse_options([H|T], [Option|Options], Rest):-
  atom_chars(H, [-|Short]), !,
  short_option(Short, Option),
  parse_options(T, Options, Rest).
% Unrecognized options are returned in `Rest`.
parse_options(Rest, [], Rest).


%! process_options(-RemainingOptions:list(nvpair)) is det.
% Reads the command-line arguments and executes those that are common
% among the PGC-using projects,
% e.g. setting the directory for reading/writing data files
% using `--data=DIR`.
%
% Only the options that are not processed in a generic way,
% i.e. those that are application-specific, are returned.

process_options(O3):-
gtrace,
  read_options(O1),
  process_options(O1, O2),
  exclude(user:process_cmd_option, O2, O3).


%! process_options(+Options1:list(nvpair), -Options2:list(nvpair)) is det.

process_options(O1, O3):-
  user:process_cmd_options(O1, O2),
  O1 \== O2, !,
  process_options(O2, O3).
process_options(O1, O1).


%! read_options(-Options:list(nvpair)) is det.
% Returns the command-line arguments, either long (`--`) or short (`-`)
% notation, in the form of name-value pairs / options.

read_options(Options):-
  current_prolog_flag(argv, Argv),
  parse_options(Argv, Options, _).


%! short_option(+Short:atom, -Option:compound) is det.
% Constructs a short option.
%
% Short options are always abbreviations of long options
% and always have the type boolean.
%
% The value of a short option, when used, is `true`,
% and `false` otherwise, i.e. when not used.

short_option(Short1, Option):-
  user:cmd_option(Short2, Long, boolean, _),
  % Do not match against options with no short name.
  Short1 == Short2,
  Option =.. [Long,true].


% Data directory was already set.
set_data_path:-
  user:file_search_path(data, _), !.
% Set default data directory.
set_data_path:-
  absolute_file_name(
    project('.'),
    Dir1,
    [access(write),file_type(directory)]
  ),
  directory_file_path(Dir1, 'Data', Dir2),
  set_data_path(Dir2).

set_data_path(Dir):-
  make_directory_path(Dir),
  assert(user:file_search_path(data, Dir)).

