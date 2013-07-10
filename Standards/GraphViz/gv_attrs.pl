:- module(
  gv_attrs,
  [
    gv_attribute_value/2, % +Attrs:list(nvpair)
                          % ?Attr:nvpair
    gv_parse_attributes/1 % +Attributes:list(nvpair)
  ]
).

/** <module> GV_ATTRS

Attributes, their allowed values, and their default values for GraphViz.

@author Wouter Beek
@see http://www.graphviz.org/doc/info/attrs.html
@version 2011-2013/07
*/

:- use_module(generics(typecheck)).
:- use_module(library(lists)).
:- use_module(library(ordsets)).
:- use_module(svg(svg)).
:- use_module(svg(svg_colors)).
:- use_module(standards(brewer)).
:- use_module(standards(x11_colors)).

:- discontiguous(gv_attr/5).



gv_attribute_value(Attrs, Name=Value):-
  nonvar(Value), !,
  gv_attr(Attrs, Name, ValueType, _Categories, _DefaultValue),
  typecheck(ValueType, Value).
gv_attribute_value(Attrs, Name=DefaultValue):-
  var(DefaultValue), !,
  gv_attr(Attrs, Name, _ValueType, _Categories, DefaultValue).

%! gv_parse_attributes(+Attributes:list(nvpair)) is det.
% Parses a list of attributes.
%
% @arg Attributes A list of name-value pairs.

gv_parse_attributes(Attrs):-
  maplist(gv_attribute_value(Attrs), Attrs).

gv_typecheck(or(AlternativeTypes), Value):-
  member(Type, AlternativeTypes),
  gv_typecheck(Type, Value), !.
gv_typecheck(polygon_based_shape, Value):-
  findall(Shape, shape(polygon, Shape), Shapes),
  typecheck(oneof(Shapes), Value).
gv_typecheck(Type, Value):-
  typecheck(Type, Value).



% ATTRIBUTES %

%! gv_attr(
%!   +Attributes:list(nvpair),
%!   ?Name:atom,
%!   ?Type,
%!   ?Context:list(oneof([cluster,edge,node])),
%!   +Attributess:list,
%!   ?DefaultValue:term
%! ) is nondet.
% Registered GraphViz attributes.
%
% @arg Attributes A list of name-value pairs.
% @arg Name The atomic name of a GraphViz gv_attr.
% @arg Type The type of the values for this gv_attr.
% @arg Context A list representing the elements for which the gv_attr can
%      be specified. Any non-empty combination of the following values:
%      1. `edge`, the gv_attr applies to edges.
%      2. `graph`, the gv_attr applies to graphs.
%      3. `node`, the gv_attr applies to nodes.
% @arg Attributess A list of gv_attr-value pairs. Used for looking up the
%      interactions between multiple attributes.
% @arg Default The default value for the `gv_attr`.

gv_attr(_Attrs, arrowhead, oneof(ArrowTypes), [edge], normal):-
  findall(ArrowType, arrow_type(ArrowType), ArrowTypes).

arrow_type(box).
arrow_type(crow).
arrow_type(diamond).
arrow_type(dot).
arrow_type(ediamond).
arrow_type(empty).
arrow_type(halfopen).
arrow_type(inv).
arrow_type(invdot).
arrow_type(invempty).
arrow_type(invodot).
arrow_type(none).
arrow_type(normal).
arrow_type(obox).
arrow_type(odiamond).
arrow_type(odot).
arrow_type(open).
arrow_type(tee).
arrow_type(vee).

% The character encoding used to interpret text label input.
% Note that iso-8859-1 and Latin1 denote the same character encoding.
gv_attr(
  _Attrs,
  charset,
  oneof(['iso-8859-1','Latin1','UTF-8']),
  [graph],
  'UTF-8'
).

gv_attr(Attrs, color, oneof(Colors), [edge,graph,node], black):-
  gv_attribute_value(Attrs, colorscheme=ColorScheme),
  colorscheme_colors(ColorScheme, Colors).

colorscheme_colors(svg, Colors):-
  svg_colors(Colors), !.
colorscheme_colors(x11, Colors):-
  x11_colors(Colors), !.
colorscheme_colors(ColorScheme, Colors):-
  brewer_colors(ColorScheme, Colors).

% Color schemes from which values of the =color= gv_attr have to be drawn.
% For example, if `colorscheme=bugn9`, then `color=7` is interpreted as
% `/bugn9/7`.

gv_attr(_Attrs, colorscheme, oneof(ColorSchemes), [edge,graph,node], x11):-
  brewer_colorschemes(BrewerColorSchemes),
  ord_union(BrewerColorSchemes, [svg,x11], ColorSchemes).

% Note that the default value is dependent on the directionality feature.
gv_attr(Attrs, dir, oneof(DirTypes), [edge], DefaultValue):-
  (
    option(directionality(directed), Attrs)
  ->
    DefaultValue = forward
  ;
    option(directionality(undirected), Attrs)
  ->
    DefaultValue = none
  ),
  findall(DirType, dir_type(DirType), DirTypes).

dir_type(back).
dir_type(both).
dir_type(forward).
dir_type(none).

% @tbd The value type should be `between(1.0,_)` (open interval), but this is
%      not currently supported by must_be/2.
gv_attr(_Attrs, fontsize, between(1.0,_OpenInterval), [graph], 14.0).

gv_attr(_Attrs, image, atom, [node], '').

% @tbd Value type should be `lblString`.
gv_attr(_Attrs, label, atom, [edge,graph,node], '').

% Whether and how vertices are allowed to overlap.
% Boolean =false= is the same as =voronoi=.
% =scalexy= means that x and y are scaled separately.
gv_attr(_Attrs, overlap, or([boolean, oneof(OverlapTypes)]), [graph], true):-
  findall(OverlapType, overlap(OverlapType), OverlapTypes).

overlap(compress).
overlap(orthoxy).
overlap(orthoyx).
overlap(scalexy).
overlap(voronoi).
overlap(vpsc).

% @tbd The default value is not correct.
%      This should be `1` for clusters and the shape default for nodes.
gv_attr(_Attrs, peripheries, nonneg, [cluster,node], 1).

% @tbd Add typechecks for `record_based_shape` and `user_defined_shape`.
gv_attr(_Attrs, shape, polygon_based_shape, [node], ellipse).

%! shape(?Category:oneof([polygon]), ?Shape:atom) is nondet.

shape(polygon, assembly).
shape(polygon, box).
shape(polygon, box3d).
shape(polygon, cds).
shape(polygon, circle).
shape(polygon, component).
shape(polygon, diamond).
shape(polygon, doublecircle).
shape(polygon, doubleoctagon).
shape(polygon, egg).
shape(polygon, ellipse).
shape(polygon, fivepoverhang).
shape(polygon, folder).
shape(polygon, hexagon).
shape(polygon, house).
shape(polygon, insulator).
shape(polygon, invhouse).
shape(polygon, invtrapezium).
shape(polygon, invtriangle).
shape(polygon, larrow).
shape(polygon, lpromoter).
shape(polygon, 'Mcircle').
shape(polygon, 'Mdiamond').
shape(polygon, 'Msquare').
shape(polygon, none).
shape(polygon, note).
shape(polygon, noverhang).
shape(polygon, octagon).
shape(polygon, oval).
shape(polygon, parallelogram).
shape(polygon, pentagon).
shape(polygon, plaintext).
shape(polygon, point).
shape(polygon, polygon).
shape(polygon, primersite).
shape(polygon, promoter).
shape(polygon, proteasesite).
shape(polygon, proteinstab).
shape(polygon, rarrow).
shape(polygon, rect).
shape(polygon, rectangle).
shape(polygon, restrictionsite).
shape(polygon, ribosite).
shape(polygon, rnastab).
shape(polygon, rpromoter).
shape(polygon, septagon).
shape(polygon, signature).
shape(polygon, square).
shape(polygon, tab).
shape(polygon, terminator).
shape(polygon, threepoverhang).
shape(polygon, trapezium).
shape(polygon, triangle).
shape(polygon, tripleoctagon).
shape(polygon, utr).

% Styles for Graphviz edges.
gv_attr(_Attrs, style, oneof(Styles), [cluster,edge,graph,node], ''):-
  findall(Style, style(edge, Style), Styles).

% Styles for Graphviz vertices.
gv_attr(_Attrs, style, oneof(Styles), [node], ''):-
  findall(Style, style(node, Style), Styles).

%! style(?Category:oneof([cluster,edge,node]), ?Style:atom) is nondet.

style(cluster, bold).
style(cluster, dashed).
style(cluster, dotted).
style(cluster, filled).
style(cluster, rounded).
style(cluster, solid).
style(cluster, striped).
style(edge, bold).
style(edge, dashed).
style(edge, dotted).
style(edge, solid).
style(node, bold).
style(node, dashed).
style(node, diagonals).
style(node, dotted).
style(node, filled).
style(node, rounded).
style(node, solid).
style(node, striped).
style(node, wedged).
