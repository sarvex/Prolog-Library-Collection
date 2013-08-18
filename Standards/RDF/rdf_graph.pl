:- module(
  rdf_graph,
  [
    rdf_graph_copy/2, % +From:atom
                      % +To:atom
    rdf_graph_equivalence/2, % +Graph1:atom
                             % +Graph2:atom
    rdf_graph_instance/3, % +Graph1:atom
                          % +Graph2:atom
                          % -BNodeMap:list(pair(bnode,or([iri,literal])))
    rdf_graph_proper_instance/3, % +Graph1:atom
                                 % +Graph2:atom
                                 % -BNodeMap:list(pair(bnode,or([iri,literal])))
    rdf_graph_merge/2, % +In:list(atom)
                       % +MergedGraph:atom
    rdf_ground/1, % +Graph:atom
    rdf_ground/1, % +Triple:compound
    rdf_schema/4, % +Graph:atom
                  % -RDFS_Classes:ordset(iri)
                  % -RDF_Properties:ordset(iri)
                  % -Triples:ordset(compound)
    rdf_subgraph/2, % +Graph1:atom
                    % +Graph2:atom
    rdf_triples/2 % +In:oneof([atom,uri])
                  % -Triples:list(compound)
  ]
).

/** <module> RDF_GRAPH

Predicates that apply to entire RDF graphs.

@author Wouter Beek
@see Graph theory support for RDF is found in module rdf_graph_theory.pl.
@see For conversions from/to serialization formats, see module rdf_serial.pl.
@version 2012/01-2013/05, 2013/07-2013/08
*/

:- use_module(generics(atom_ext)).
:- use_module(generics(list_ext)).
:- use_module(generics(meta_ext)).
:- use_module(generics(print_ext)).
:- use_module(generics(typecheck)).
:- use_module(graph_theory(graph_export)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(option)).
:- use_module(library(ordsets)).
:- use_module(library(plunit)).
:- use_module(library(semweb/rdf_db)).
:- use_module(library(semweb/rdfs)).
:- use_module(library(uri)).
:- use_module(rdf(rdf_graph)).
:- use_module(rdf(rdf_list)).
:- use_module(rdf(rdf_namespace)).
:- use_module(rdf(rdf_read)).
:- use_module(rdf(rdf_serial)).
:- use_module(rdf(rdf_term)).
:- use_module(rdf_graph(rdf_graph_theory)).
:- use_module(rdfs(rdfs_read)).
:- use_module(xsd(xsd)).

:- rdf_meta(rdf_triples(r,-)).



%! rdf_bnode_replace(
%!   +Triple1:compound,
%!   +Map:list(pair(bnode,or([literal,iri,var]))),
%!   -Triple2:compound
%! ) is det.
% Replaces bnodes in triples with variables.

rdf_bnode_replace(S1-P-O1, Map, S2-P-O2):- !,
  rdf_bnode_replace(S1, Map, S2),
  rdf_bnode_replace(O1, Map, O2).
% Not a blank node, do not replace.
rdf_bnode_replace(X, _Map, X):-
  \+ rdf_is_bnode(X), !.
% A blank node that is in the mapping.
rdf_bnode_replace(X, Map, Y):-
  memberchk(X-Y, Map), !.
% A blank node that is not in the mapping, replace with a Prolog variable.
rdf_bnode_replace(_X, _Map, _Var).

%! rdf_graph_copy(+From:atom, +To:atom) is det.
% Copying a graph is the same as merging a single graph
% and storing the result under a new name.

rdf_graph_copy(From, To):-
  From \== To,
  rdf_graph_merge([From], To).

%! rdf_graph_equivalence(+Graph1:atom, +Graph2:atom) is semidet.

rdf_graph_equivalence(Graph1, Graph2):-
  rdf_graph_equivalence0(Graph1, Graph2),
  rdf_graph_equivalence0(Graph2, Graph1).
rdf_graph_equivalence0(Graph1, Graph2):-
  forall(
    rdf(Subject1, Predicate, Object1, Graph1),
    (
      rdf(Subject2, Predicate, Object2, Graph2),
      rdf_graph_equivalence_subject0(Graph1, Subject1, Graph2, Subject2),
      rdf_graph_equivalence_object0(Graph1, Object1, Graph2, Object2)
    )
  ).
rdf_graph_equivalence_subject0(_Graph1, Subject, _Graph2, Subject):-
  rdf_is_resource(Subject), !.
rdf_graph_equivalence_subject0(Graph1, Subject1, Graph2, Subject2):-
  bnode_translation0(Graph1, Subject1, Graph2, Subject2).
rdf_graph_equivalence_object0(_Graph1, Object, _Graph2, Object):-
  rdf_is_resource(Object), !.
rdf_graph_equivalence_object0(_Graph1, Object, _Graph2, Object):-
  rdf_is_literal(Object), !.
rdf_graph_equivalence_object0(Graph1, Object1, Graph2, Object2):-
  bnode_translation0(Graph1, Object1, Graph2, Object2).
bnode_translation0(G1, Resource1, G2, Resource2):-
  maplist(rdf_bnode, [G1,G2], [Resource1,Resource2]), !.

rdf_graph_instance(G, H, Map):-
  rdf_graph(G), rdf_graph(H),
  rdf_triples(G, L1), rdf_triples(H, L2),
  rdf_graph_instance(L2, L1, [], Map).

rdf_graph_instance([], _L2, SolMap, SolMap):- !.
rdf_graph_instance([S1-P-O1|T1], L2, Map, SolMap):-
  rdf_bnode_replace(S1, Map, S2),
  (var(S2) -> MapExtension1 = [S1-S2] ; MapExtension1 = []),
  rdf_bnode_replace(O1, Map, O2),
  (var(O2) -> MapExtension2 = [O1-O2] ; MapExtension2 = []),
  member(S2-P-O2, L2),
  append([Map,MapExtension1,MapExtension2], NewMap),
  rdf_graph_instance(T1, L2, NewMap, SolMap).

%! rdf_graph_merge(+In:list(atom), +MergedGraph:atom) is det.
% Merges RDF graphs.
% The input is is a (possibly mixed) list of RDF graph names and
% names of files that store an RDF graph.
%
% When merging RDF graphs we have to make sure that their blank nodes are
% standardized apart.

rdf_graph_merge(FilesOrGraphs, MergedG):-
  is_list(FilesOrGraphs),
  % Be liberal with respect to the input.
  files_or_rdf_graphs(FilesOrGraphs, Gs),

  % Type checking.
  maplist(rdf_graph, Gs),
  atom(MergedG),
  !,

  % Collect the shared blank nodes.
  findall(
    G1/G2/SharedBNode,
    (
      member(G1, G2, Gs),
      % Use the natural order of atomic names.
      % The idea is that we only replace shared blank nodes in
      % the latter graph.
      G1 @< G2,
      rdf_bnode(G1, SharedBNode),
      rdf_bnode(G2, SharedBNode)
    ),
    SharedBNodes
  ),

  % Replace the blank nodes.
  (
    SharedBNodes == []
  ->
    forall(
      (
        member(G, Gs),
        rdf(S, P, O, G)
      ),
      rdf_assert(S, P, O, MergedG)
    )
  ;
    forall(
      (
        member(G, Gs),
        rdf(S, P, O, G)
      ),
      (
        rdf_bnode_replace(
          SharedBNodes,
          rdf(S, P, O, G),
          rdf(NewS, P, NewO)
        ),
        rdf_assert(NewS, P, NewO, MergedG)
      )
    )
  ).

%! rdf_graph_proper_instance(
%!   +Graph1:atom,
%!   +Graph2:atom,
%!   -BNodeMap:list(pair(bnode,or([literal,iri])))
%! ) is semidet.
% A proper instance of a graph is an instance in which a blank node
% has been replaced by a name, or two blank nodes in the graph have
% been mapped into the same node in the instance.

rdf_graph_proper_instance(G, H, Map):-
  rdf_graph_instance(G, H, Map),
  (
    % A node is mapped onto an RDF name.
    member(_-X, Map),
    rdf_name(G, X)
  ;
    % Two different blank nodes are mapped onto the same blank node.
    member(X1-Y, Map),
    member(X2-Y, Map),
    X1 \== X2
  ), !.

%! rdf_ground(+Graph:graph) is semidet.
% Succeeds if the given graph is ground, i.e., contains no blank node.
%! rdf_ground(+Triple) is semidet.
% Succeeds if the given triple is ground, i.e., contains no blank node.
% The predicate cannot be a blank node by definition.
%
% @see RDF Semantics http://www.w3.org/TR/2004/REC-rdf-mt-20040210/

rdf_ground(S-_-O):- !,
  \+ rdf_is_bnode(S),
  \+ rdf_is_bnode(O).
rdf_ground(G):-
  forall(
    rdf(S, P, O, G),
    rdf_ground(S-P-O)
  ).

rdf_schema(G, RDFS_Classes, RDF_Properties, Triples):-
  setoff(C, rdfs_individual_of(C, rdfs:'Class'), RDFS_Classes),
  setoff(P, rdfs_individual_of(P, rdf:'Property'), RDF_Properties),
  ord_union(RDFS_Classes, RDF_Properties, Vocabulary),
  setoff(S-P-O, (member(S, O, Vocabulary), rdf(S, P, O, G)), Triples).

%! rdf_subgraph(+Graph1:atom, +Graph2:atom) is semidet.
% Succeeds if the former graph is a subgraph of the latter.
%
% @see RDF Semantics http://www.w3.org/TR/2004/REC-rdf-mt-20040210/

rdf_subgraph(G, H):-
  rdf_graph(G), rdf_graph(H), !,
  \+ (rdf(S, P, O, G), \+ rdf(S, P, O, H)).

%! rdf_triples(+In:oneof([atom,uri]) -Triples:list(rdf_triple)) is det.
% Returns an unsorted list containing all the triples in a graph.
%
% @param In The atomic name of a loaded RDF graph, or a URI.
% @param Triples A list of triple compound term.

rdf_triples(G, Ts):-
  rdf_graph(G), !,
  findall(S-P-O, rdf(S, P, O, G), Ts).
% The RDF triples that describe a given URI reference.
rdf_triples(URI, Ts):-
  is_uri(URI), !,
  setoff(S-P-O, rdf(S, P, O, _G), Ts).



:- begin_tests(rdf_graph).

:- use_module(generics(print_ext)).
:- use_module(library(apply)).
:- use_module(library(semweb/rdf_db)).
:- use_module(rdf(rdf_term)).

test(rdf_graph_instance, []):-
  maplist(rdf_unload_graph, [test_graph,test_graph_instance]),
  maplist(rdf_bnode, [X1,X2,X3,X4]),
  rdf_assert(X1, rdf:p, X2, test_graph),
  rdf_assert(X3, rdf:p, X4, test_graph),
  rdf_assert(rdf:a, rdf:p, rdf:b, test_graph_instance),
  rdf_assert(rdf:c, rdf:p, rdf:d, test_graph_instance),
  findall(
    Map,
    (
      rdf_graph_instance(test_graph_instance, test_graph, Map),
      print_list(user_output, Map),
      nl(user_output)
    ),
    _Maps
  ).

:- end_tests(rdf_graph).

