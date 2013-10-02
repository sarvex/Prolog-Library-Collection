:- module(
  humR,
  [
    r_comp_web/3, % +Predicates:list(iri)
                  % ?NumberOfColumns:positive_integer
                  % -DOM:list
    r_web/3 % +Predicate:iri
            % ?NumberOfColumns:positive_integer
            % -DOM:list
  ]
).

/** <module> humR

R-statistics generation for humanities data.

@author Wouter Beek
@tbd Use datatype ordering instead of Prolog term ordering.
@version 2013/10
*/

:- use_module(generics(list_ext)).
:- use_module(generics(meta_ext)).
:- use_module(generics(print_ext)).
:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module(library(debug)).
:- use_module(library(real)).
:- use_module(library(semweb/rdf_db)).
:- use_module(rdf(rdf_lit)).
:- use_module(rdf(rdf_name)).
:- use_module(rdf(rdf_namespace)).
:- use_module(rdf(rdf_read)).
:- use_module(rdfs(rdfs_read)).
:- use_module(svg(svg_file)).
:- use_module(xsd(xsd)).

:- rdf_meta(r_comp_web(t,?,-)).
:- rdf_meta(r_web(r,?,-)).

:- debug(humR).



r_comp_web(Ps1, N1, SVG):-
  length(Ps1, NumberOfCompares),
  NumberOfCompares >= 2,
  rdf_global_ids(Ps1, Ps2),
  default(N1, 15, N2),
  
  % For comparisons, we require the domains and ranges to be the same.
  Ps2 = [P1|Ps2_],
  once(rdf_has(SomeS1, P1, SomeO1)),
  resource_class(SomeS1, S_Class),
  resource_class(SomeO1, O_Class),
  forall(
    member(P_, Ps2_),
    (
      once(rdf_has(SomeS2, P_, SomeO2)),
      resource_class(SomeS2, S_Class),
      resource_class(SomeO2, O_Class)
    )
  ),
  
  % Axis labels.
  axis_label(SomeO1, X_Axis),
  axis_label(SomeS1, Y_Axis),
  
  % Collect the unique object terms shared by the given properties.
  setoff(
    O,
    (
      rdf_has(_S1, P1, O),
      forall(
        member(P_, Ps2_),
        once(rdf_has(_S2, P, O))
      )
    ),
    Os1
  ),
  
  % Totally ordered domains need to be discretzed before being represented
  % using bars.
  (
    is_total_order(SomeO1)
  ->
    discretize(Os1, N2, Os2)
  ;
    Os2 = Os1
  ),
  
  % Contruct the two collections of bars by counting the number of
  % subjects for the given discretized object value scale.
  findall(
    Bars_,
    (
      member(P, Ps2),
      construct_bars(P, Os2, Bars_)
    ),
    Bars
  ),
  
  % Labels for the discretized intervals on the X axis.
  maplist(interval_label, Os2, Os3),
  
  % Caption for the figure.
  maplist(rdf_term_name([]), Ps2, PsLabels),
  with_output_to(atom(Main), print_set([], PsLabels)),
  
  % Do it!
  absolute_file_name(test, File, [access(write),extensions([svg])]),
  <- svg(+File),
  <- barplot(
    Bars,
    % Columns are not stacked on top of each other,
    % but are placed beside each other.
    beside='TRUE',
    % Scaling of the font size of x-axis labels.
    cex..names=0.8,
    % Colors help distinguish between the compared properties.
    col=rainbow(NumberOfCompares),
    % Labels perpendicular to axis.
    las=2,
    % Logarithmic scale.
    %%%%log=+y,
    % Caption.
    main=+Main,
    % Text labels for x-axis.
    names..arg=Os3,
    ylab=+Y_Axis
  ),
  % Label for x-axis needs special positioning.
  <- title(xlab=+X_Axis, line=5),
  <- legend(
    +topleft,
    bg=+white,
    fill=rainbow(NumberOfCompares),
    legend=PsLabels
  ),
  <- dev..off(.),
  file_to_svg(File, SVG).

%! r_web(+Predicate:iri, ?NumberOfColumns:positive_integer, -SVG:list) is det.
% This plots the subject-object pairs that occur in triples
% with the given predicate.
%
% The subjects are plotted on the Y axis.
% The objects are plotted on the X axis.

r_web(P11, N1, SVG):-
  rdf_global_id(P11, P12),

  % Settings.
  default(N1, 15, N2),

  % Axis labels.
  once(rdf_has(SomeS, P12, SomeO)),
  axis_label(SomeO, X_Axis),
  axis_label(SomeS, Y_Axis),

  % Collect the unique object terms.
  setoff(O, rdf_has(_, P12, O), Os1),

  % Totally ordered domains need to be discretzed before being represented
  % using bars.
  (
    is_total_order(SomeO)
  ->
    discretize(Os1, N2, Os2)
  ;
    Os2 = Os1
  ),

  % Contruct the bars by counting the number of subjects for
  % the given discretized object value scale.
  construct_bars(P12, Os2, Bars),

  % Labels for the discretized intervals on the X axis.
  maplist(interval_label, Os2, Os3),

  % Caption for the figure.
  with_output_to(codes(Main), rdf_term_name([], P12)),

  % Colors.
  length(Bars, NumberOfBars),

  % Do it!
  absolute_file_name(test, File, [access(write),extensions([svg])]),
  <- svg(+File),
  <- barplot(
    Bars,
    % Scaling of the font size of x-axis labels.
    cex..names=0.8,
    col=rainbow(NumberOfBars),
    % Number of stripes in columns.
    % Incompatible with logarithmic scale!
    %%%%density=10,
    % Labels perpendicular to axis.
    las=2,
    % Logarithmic scale.
    %log=+y,
    % Caption text.
    main=+Main,
    % Text labels for x-axis.
    names..arg=Os3,
    ylab=+Y_Axis
  ),
  % Label for x-axis needs special positioning.
  <- title(xlab=+X_Axis, line=5),
  <- legend(
    +topleft,
    bg=+white,
    fill=rainbow(NumberOfBars),
    legend=Os3
  ),
  <- dev..off(.),
  file_to_svg(File, SVG).



% SUPPORT PREDICATES %

%! axis_label(+Resource:or([bnode,iri,literal]), -Label:atom) is det.
% Returns an atomic label for resources _|such as|_ the given resource.

axis_label(R, Label):-
  resource_class(R, Class),
  rdf_term_name([], Class, Label).

%! construct_bars(
%!   +Predicate:iri,
%!   +Values:or([list(ordset),ordset]),
%!   -Bars:list(nonneg)
%! ) is det.
% Bars are constructed by counting the number of subjects that occur
% for the given predicate and object pairs.
%
% The object terms are either drawn from a set or from a list of sets.
% In the latter case a count occurs if the found object term is in the
% object term set.

construct_bars(P, Os, Bars):-
  findall(
    NumberOfS,
    (
      member(O, Os),
      aggregate_all(
        count,
        (rdf_has(_, P, O0), belongs_to(O0, O)),
        NumberOfS
      )
    ),
    Bars
  ).

belongs_to(O0, O):-
  is_list(O), !,
  memberchk(O0, O).
belongs_to(O, O):- !.

%! determine_range(
%!   +Min:integer,
%!   +Max:integer,
%!   -Begin:integer,
%!   -End:integer,
%!   -Step:nonneg
%! ) is det.

determine_range(Min, Max, Begin, End, Step):-
  Min =< Max,
  Diff is Max - Min,
  Step is 10 ** ceil(log10(Diff / 100)),
  Begin is floor(Min / Step) * Step,
  End is ceil(Max / Step) * Step.

%! discretize(
%!   +Values:ordset,
%!   +Intervals:positive_integer,
%!   -Discretized:list(ordset)
%! ) is det.
% Discretized the given set of totally ordered values.

discretize(Set, N, Disc):-
  split_list_by_number_of_sublists(Set, N, Disc).

%! interval_label(+ValueOrValues, -Label:atom) is det.
% Returns a descriptive label for the given set of values.
%
% Single values are considered to be intervals of length 1.
% In these cases the label of this single value is given.

interval_label(Set, Label):-
  is_list(Set),
  length(Set, Length),
  Length > 1, !,
  first(Set, A1),
  last(Set, Z1),
  maplist(rdf_term_name([]), [A1,Z1], [A2,Z2]),
  format(atom(Label), '~w..~w', [A2,Z2]).
interval_label([SingleValue], Label):- !,
  interval_label(SingleValue, Label).
interval_label([], ''):- !.
interval_label(T, N):-
  rdf_term_name([], T, N).

%! is_total_order(+Resource:iri) is semidet.
% Succeeds if resources _|such as|_ the given resource are totally ordered.

is_total_order(R):-
  resource_class(R, C),
  rdf_memberchk(C, [xsd:decimal,xsd:gYear,xsd:integer]).

%! resource_class(+Resource:or([bnode,iri,literal]), -Class:iri) is det.
% Returns the most descriptive RDFS class for the given resource.
%
% The *|most descriptive|* class is the one of which the resource is
% a direct member, i.e. subclasses of the most descriptive class do not
% have the resource as an instance.
%
% Since RDFS reasoning (with datatype extension) is not 100% yet,
% we include some simple hacks here.

resource_class(R, C):-
  rdf_is_typed_literal(R), !,
  rdf_typed_literal(R, C, _).
resource_class(R, C):-
  rdf(R, rdf:type, C), !.
resource_class(R, C):-
  rdfs_individual(m(t,f,f), R, C, _).

