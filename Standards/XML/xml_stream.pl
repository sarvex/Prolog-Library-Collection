:- module(
  xml_stream,
  [
    xml_stream/4 % +File:atom
                 % +Tag:atom
                 % :Goal
                 % :StoreGoal
  ]
).

/** <module> XML_STREAM

This module allows a huge XML file's DOM to be processed
using an arbitrary Prolog goal.

This would normally be impossible since it would be required
to load the DOM of the entiry file into memory all at once.

The limitation of the here presented predicate is that the user
must give the name of the XML tag that is at the granularity
level at which DOM can be read into memory.

This means that this method is only applicable to
large XML files with relatively short chunks of XML
in the same tab construct.

Everything that appears outside of the indicated tag constructs
is ignored by this methods.

@author Wouter Beek
@version 2013/06
*/

:- use_module(generics(cowspeak)).
:- use_module(generics(db_ext)).
:- use_module(os(io_ext)).

:- meta_predicate(xml_stream(+,+,1,0)).
:- meta_predicate(xml_stream0(+,+,1,0,+)).

:- db_add_novel(user:prolog_file_type(tmp, temporary)).

:- setting(
  store_number,
  integer,
  100000,
  'The number of items after which an intermediate save is made.'
).



xml_stream(File, Tag, Goal, StoreGoal):-
  is_absolute_file_name(File), !,
  setting(store_number, StoreNumber),
  format(atom(StartTag), '<~w>', [Tag]),
  format(atom(EndTag), '</~w>', [Tag]),
  setup_call_cleanup(
    open(File, read, Stream),
    xml_stream0(Stream, StartTag-EndTag, Goal, StoreGoal, StoreNumber),
    close(Stream)
  ).

% Intermediate storage of results.
xml_stream0(Stream, Tags, Goal, StoreGoal, StoreNumber):-
  flag(processed_items, StoreNumber, 0), !,
  call(StoreGoal),
  xml_stream0(Stream, Tags, Goal, StoreGoal, StoreNumber).
% End of stream.
xml_stream0(Stream, _Tags, _Goal, StoreGoal, _StoreNumber):-
  at_end_of_stream(Stream), !,
  call(StoreGoal).
% Starts an entry
xml_stream0(Stream, StartTag-EndTag, Goal, StoreGoal, StoreNumber):-
  peek_atom(Stream, StartTag), !,
  
  absolute_file_name(
    data(copybuffer),
    CopyBuffer,
    [access(write),file_type(temporary)]
  ),
  setup_call_cleanup(
    open(CopyBuffer, write, Out, [encoding(utf8)]),
    xml_stream1(Stream, StartTag-EndTag, Out),
    (
      close(Out),
      % Turn the situatiun around: from writing to reading.
      open(CopyBuffer, read, In),
      load_structure(
        In,
        DOM,
        [dialect(xml),shorttag(false),space(remove)]
      ),
      call(Goal, DOM),
      close(In),
      delete_file(CopyBuffer)
    )
  ),
  
  flag(processed_items, X, X + 1),
  xml_stream0(Stream, StartTag-EndTag, Goal, StoreGoal, StoreNumber).
% Skips a line. Notify user.
xml_stream0(Stream, Tags, Goal, StoreGoal, StoreNumber):-
  read_line_to_codes(Stream, Codes),
  line_count(Stream, Line),
  atom_codes(Atom, Codes),
  cowsay('Skipping line ~w: ~w', [Line, Atom]),
  xml_stream0(Stream, Tags, Goal, StoreGoal, StoreNumber).

% Closes an entry.
xml_stream1(Stream, _StartTag-EndTag, Out):-
  peek_atom(Stream, EndTag), !,
  copy_stream_line(Stream, Out).
% Continues an entry.
xml_stream1(Stream, Tags, Out):-
  copy_stream_line(Stream, Out),
  xml_stream1(Stream, Tags, Out).
