:- module(
  rdf_read,
  [
% LITERALS
    rdf_datatype/5, % ?Subject:oneof([bnode,uri])
                    % ?Predicate:uri
                    % ?Datatype:oneof([atom,uri])
                    % ?Value:atomic
                    % ?Graph:graph
    rdf_has_datatype/4, % ?Subject:oneof([bnode,uri])
                        % ?Predicate:uri
                        % ?DatatypeName:atom
                        % ?Value
    rdf_literal/4, % ?Subject:oneof([bnode,uri])
                   % ?Predicate:uri
                   % ?Literal:atom
                   % ?Graph:graph
    rdf_literal/5, % ?Subject:oneof([bnode,uri])
                   % ?Predicate:uri
                   % ?Language:atom
                   % ?Literal:atom
                   % ?Graph:graph

% LIST MEMBERSHIP
    rdf_member/2, % ?Member:uri
                  % ?Members:list(uri)
    rdf_memberchk/2, % ?Member:uri
                     % ?Members:list(uri)

% STRUCTURE-BASED READS
    rdf_index/5, % ?Subject:oneof([bnode,uri])
                 % ?Predicate:uri
                 % ?Object:uri
                 % ?Graph:graph
                 % ?Index:term
    rdf_random/5, % -Subject:oneof([bnode,uri])
                  % -Predicate:uri
                  % -Object:uri
                  % +Graph:graph
                  % -Index:integer
    rdf_valuetype/2 % ?Graph:graph
                    % ?Type:uri
  ]
).

/** <module> RDF read

Predicates for reading from RDF, customized for specific datatypes and
literals.

@author Wouter Beek
@version 2011/08, 2012/01, 2012/03, 2012/09, 2012/11-2013/04, 2013/07-2013/08
*/

:- use_module(library(semweb/rdf_db)).
:- use_module(math(math_ext)).
:- use_module(rdf(rdf_graph)).
:- use_module(xml(xml_namespace)).
:- use_module(xsd(xsd)).

:- xml_register_namespace(rdf, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').

% LITERALS %
:- rdf_meta(rdf_datatype(r,r,?,?,?)).
:- rdf_meta(rdf_has_datatype(r,r,?,?)).
:- rdf_meta(rdf_literal(r,r,?,?)).
:- rdf_meta(rdf_literal(r,r,?,?,?)).
% LIST MEMBERSHIP %
:- rdf_meta(rdf_member(r,+)).
:- rdf_meta(rdf_memberchk(r,+)).
% STRUCTURE-BASED READS %
:- rdf_meta(rdf_index(r,r,r,?,?)).
:- rdf_meta(rdf_node(?,r)).
:- rdf_meta(rdf_random(r,r,r,?,-)).
:- rdf_meta(rdf_term(?,r)).
:- rdf_meta(rdf_valuetype(?,r)).



% LITERALS %

%! rdf_datatype(
%!   ?Subject:oneof([bnode,uri]),
%!   ?Predicate:uri,
%!   ?DatatypeName:atom,
%!   ?Value,
%!   ?Graph:atom
%! ) is nondet.

rdf_datatype(Subject, Predicate, DatatypeName, Value, Graph):-
  xsd_datatype(DatatypeName, Datatype),
  (
    nonvar(Value)
  ->
    % Interpret all literals, not just the canonical ones.
    xsd_lexicalMap(Datatype, LEX, Value),
    rdf(Subject, Predicate, literal(type(Datatype, LEX)), Graph)
  ;
    rdf(Subject, Predicate, literal(type(Datatype, LEX)), Graph),
    % This may be nondet!
    xsd_lexicalMap(Datatype, LEX, Value)
  ).

%! rdf_has_datatype(
%!   ?Subject:oneof([bnode,uri]),
%!   ?Predicate:uri,
%!   ?DatatypeName:atom,
%!   ?Value,
%!   ?Graph:atom
%! ) is nondet.

rdf_has_datatype(Subject, Predicate, DatatypeName, Value):-
  xsd_datatype(DatatypeName, Datatype),
  (
    nonvar(Value)
  ->
    % Interpret all literals, not just the canonical ones.
    xsd_lexicalMap(Datatype, LEX, Value),
    rdf_has(Subject, Predicate, literal(type(Datatype, LEX)))
  ;
    rdf_has(Subject, Predicate, literal(type(Datatype, LEX))),
    % This may be nondet!
    xsd_lexicalMap(Datatype, LEX, Value)
  ).

%! rdf_literal(
%!   ?Subject:oneof([bnode,uri]),
%!   ?Predicate:uri,
%!   ?Literal:atom,
%!   ?Graph:graph
%! ) is nondet.
% The RDF triple for a literal valued property.
%
% @see rdf_literal/5.

rdf_literal(Subject, Predicate, Literal, Graph):-
  rdf(Subject, Predicate, literal(Literal), Graph).
rdf_literal(Subject, Predicate, Literal, Graph):-
  rdf_literal(Subject, Predicate, en, Literal, Graph).

%! rdf_literal(
%!   ?Subject:oneof([bnode,uri]),
%!   ?Predicate:uri,
%!   ?Language:atom,
%!   ?Literal:atom,
%!   ?Graph:graph
%! ) is nondet.
% The RDF triple for a literal valued property, encoded in a certain language.
%
% @param Subject A resource.
% @param Predicate A resource.
% @param Language The atomic name of a language.
% @param Literal An atom.
% @param Graph The atomic name of an RDF graph.

rdf_literal(Subject, Predicate, Language, Literal, Graph):-
  rdf(Subject, Predicate, literal(lang(Language, Literal)), Graph).



% LIST MEMBERSHIP %

rdf_member(Member, List):-
  member(Member0, List),
  rdf_global_id(Member0, Member).

rdf_memberchk(Member, List):-
  once(rdf_member(Member, List)).



% STRUCTURE-BASED READS %

%! rdf_index(
%!   ?Subject:oneof([bnode,uri]),
%!   ?Predicate:uri,
%!   ?Object:uri,
%!   ?Graph:graph,
%!   ?Index:integer
%! ) is nondet.
% Returns the rdf triple that has the given index in the arbitrary sequence
% in which SWI-Prolog returns its triples.
%
% @param Subject A resource.
% @param Predicate A resource.
% @param Object A resource.
% @param Index A compound term of the form =Graph:Line= with =Graph= the
%        atomic name of an RDF graph and =Line= an integer.

rdf_index(Subject, Predicate, Object, Graph, Index):-
  rdf_triples(Graph, Triples),
  nth0(Index, Triples, rdf(Subject, Predicate, Object)).

%! rdf_random(
%!   -Subject:oneof([bnode,uri]),
%!   -Predicate:uri,
%!   -Object:uri,
%!   ?Graph:graph,
%!   -Index:integer
%! ) is det.
% Returns a random triple from the given graph.
%
% @param Subject A resource.
% @param Predicate A resource.
% @param Object A resource.
% @param Graph The atomic name of a graph.
% @param Index An integer representating the index of the randomly selected
%        triple.

rdf_random(Subject, Predicate, Object, Graph, RandomIndex):-
  rdf_graph_property(Graph, triples(NumberOfTriples)),
  succ(UpperIndex, NumberOfTriples),
  random_betwixt(UpperIndex, RandomIndex),
  rdf_index(Subject, Predicate, Object, Graph, RandomIndex).

rdf_valuetype(Graph, Type):-
  rdf(_Subject, _Predicate, literal(type(Type, _Value)), Graph).

