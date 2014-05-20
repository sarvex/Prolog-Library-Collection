:- module(
  sparql_update,
  [
    sparql_update/1 % +Graph:atom
  ]
).

/** <module> SPARQL update

Support for the SPARQL 1.1 Update recommendation.

@author Wouter Beek
@version 2014/05
*/

:- use_module(dcg(dcg_content)).



%! 'PN_CHARS_BASE'// .
% ~~~{.ebnf}
% [164]    PN_CHARS_BASE ::= [A-Z] |
%                            [a-z] |
%                            [#x00C0-#x00D6] |
%                            [#x00D8-#x00F6] |
%                            [#x00F8-#x02FF] |
%                            [#x0370-#x037D] |
%                            [#x037F-#x1FFF] |
%                            [#x200C-#x200D] |
%                            [#x2070-#x218F] |
%                            [#x2C00-#x2FEF] |
%                            [#x3001-#xD7FF] |
%                            [#xF900-#xFDCF] |
%                            [#xFDF0-#xFFFD] |
%                            [#x10000-#xEFFFF]
% ~~~




%! 'PN_CHARS_U'// .
% ~~~{.ebnf}
% [165]    PN_CHARS_U ::= PN_CHARS_BASE | '_'
% ~~~

'PN_CHARS_U' --> 'PN_CHARS_BASE'.
'PN_CHARS_U' --> `_`.


%! 'QuadData'(Data)// .
% ~~~{.ebnf}
% [49]    QuadData ::= '{' Quads '}'
% ~~~

'QuadData' -->
  bracketed(curly, 'Quads').


%! 'Quads'(+Data)// .
% ~~~{.ebnf}
% [50]    Quads ::= TriplesTemplate? ( QuadsNotTriples '.'? TriplesTemplate? )*
% ~~~

'Quads' -->
  

%! 'TriplesSameSubject'// .
% ~~~{.ebnf}
% [75]    TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList
% ~~~

'TriplesSameSubject' -->
  


% ~~~{.ebfn}
% [52]    TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?
% ~~~

'TriplesTemplate' -->

%! 'Var'// .
% ~~~{.ebnf}
% [108]    Var ::= VAR1 | VAR2
% ~~~

'Var' --> 'VAR1'.
'Var' --> 'VAR2'.

%! 'VAR1'// .
% ~~~{.ebnf}
% [143]    VAR1 ::= '?' VARNAME
% ~~~

'VAR1' --> `?`, 'VARNAME'.


%! 'VAR2'// .
% ~~~{.ebnf}
% [144]    VAR2 ::= '$' VARNAME
% ~~~

'VAR2' --> `$`, 'VARNAME'.

%! 'VARNAME'// .
% ~~~{.ebnf}
% [166]    VARNAME ::= ( PN_CHARS_U | [0-9] )
%                      ( PN_CHARS_U | [0-9] | #x00B7 | [#x0300-#x036F]
%                      | [#x203F-#x2040] )*
% ~~~

'VARNAME' -->
  'PN_CHARS_U'


%! 'VarOrTerm'// .
% ~~~{.ebnf}
% [106]    VarOrTerm ::= Var | GraphTerm
% ~~~

'VarOrTerm' --> 'Var'.
'VarOrTerm' --> 'GraphTerm'.

