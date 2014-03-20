:- module(
  rdf_tabular,
  [
    rdf_tabular_triples//4 % ?Subject:or([bnode,iri])
                           % ?Predicate:iri
                           % ?Object:or([bnode,iri,literal])
                           % ?Graph:atom
  ]
).

/** <module> RDF tabular

Generated RDF HTML tables.

@author Wouter Beek
@tbd Add blank node map.
@tbd Add namespace legend.
@tbd Add local/remote distinction.
@tbd Include images.
@version 2013/12-2014/03
*/

:- use_module(dcg(dcg_content)).
:- use_module(dcg(dcg_generic)).
:- use_module(generics(list_ext)).
:- use_module(generics(meta_ext)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(semweb/rdf_db)).
:- use_module(rdf(rdf_parse)).
:- use_module(rdf_web(rdf_tabular_graph)).
:- use_module(rdf_web(rdf_tabular_term)).
:- use_module(rdf_web(rdf_html_table)).
:- use_module(rdf_web(rdf_term_html)).
:- use_module(server(app_ui)).
:- use_module(server(web_modules)).

http:location(rdf_tabular, root(rdf_tabular), []).
:- http_handler(root(rdf_tabular), rdf_tabular, [priority(-1)]).

:- web_module_add('RDF Tabular', rdf_tabular).



%! rdf_tabular(+Request:list(nvpair)) is det.
% Serves an HTML page describing RDF data.
%
% The following variants are supported, based on the URL search string:
%   * =|graph=Graph|=
%     Serves a description of the given RDF graph.
%   * =|term=Term|=
%     Serves a description of the given RDF term.
%     The atom `Term` is parsed by a grammar rule
%     that extract the corresponding RDF term.
%     This also allows atomic renditions of prefix-abbreviated IRIs as input,
%     e.g. `'dbpedia:Monkey'`.
%   * No search string.
%     Serves a description of all currently loaded RDF graphs.

% RDF term.
rdf_tabular(Request):-
  memberchk(search(Search), Request),
  memberchk(term=Term, Search), !,
  
  % Parse the tern atom to extract the corresponding RDF term.
  once(dcg_phrase(rdf_parse_term(RdfTerm1), Term)),
  rdf_global_id(RdfTerm1, RdfTerm2),
  
  % The graph parameter is optional
  % (in which case it is left uninstantiated).
  ignore(memberchk(graph=Graph, Search)),

  reply_html_page(
    app_style,
    title(['Overview of RDF resource ',Term]),
    [
      h1(['Description of RDF term ',\rdf_term_html(RdfTerm2)]),
      \rdf_tabular_term(Graph, RdfTerm2)
    ]
  ).
% RDF graph.
rdf_tabular(Request):-
  memberchk(search(Search), Request),
  memberchk(graph=Graph, Search), !,
  
  reply_html_page(
    app_style,
    title(['Overview of RDF graph ',\rdf_term_html(Graph)]),
    [
      h1(['Description of RDF graph ',\rdf_term_html(Graph)]),
      \rdf_tabular_graph(Graph)
    ]
  ).
% Default: RDF graphs.
rdf_tabular(_Request):-
  reply_html_page(
    app_style,
    title('Overview of RDF graphs'),
    [
      h1('Overview of RDF graphs'),
      \rdf_tabular_graphs
    ]
  ).


%! rdf_tabular_triples(
%!   +Subject:or([bnode,iri]),
%!   +Predicate:iri,
%!   +Object:or([bnode,iri,literal]),
%!   ?Graph:atom
%! )// is det.

rdf_tabular_triples(S, P, O, Graph) -->
  {
    setoff(
      [S,P,O,Graph],
      rdf(S, P, O, Graph),
      Rows1
    ),
    % Restrict the number of rows in the table arbitrarily.
    list_truncate(Rows1, 1000, Rows2)
  },
  rdf_html_table([header_row(spog)], html('RDF triples'), Rows2).

