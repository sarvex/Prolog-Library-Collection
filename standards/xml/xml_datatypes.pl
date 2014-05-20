:- module(
  xml_datatypes,
  [
    xml_boolean//2, % -Tree:compound
                    % ?Value:boolean
    xml_char_10//1, % ?Char:code
    xml_char_11//1, % ?Char:code
    xml_chars_10//1, % ?Chars:list(code)
    xml_chars_11//1, % ?Chars:list(code)
    'Name'//1, % ?Name:atom
    xml_namespaced_name//2, % :DCG_Namespace
                            % :DCG_Name
    xml_space//0,
    xml_space//1, % ?Code:code
    xml_yes_no//2 % -Tree:compound
                  % ?Boolean:boolean
  ]
).

/** <module> XML datatypes

DCG rules for XML datatypes.

@author Wouter Beek
@version 2013/07-2013/08, 2014/02-2014/05
*/

:- use_module(dcg(dcg_ascii)).
:- use_module(dcg(dcg_cardinal)).
:- use_module(dcg(dcg_content)).
:- use_module(dcg(dcg_unicode)).
:- use_module(sparql(sparql_update)).

:- meta_predicate(xml_namespaced_name(//,//,?,?)).



xml_boolean(xml_boolean(false), false) --> "false".
xml_boolean(xml_boolean(true),  true) --> "true".


%! xml_char_10(?Char:between(9,1114111))//
% An **XML Character** is an atomic unit of text specified by ISO/IEC 10646.
%
% ~~~{.bnf}
% Char ::= #x9               | // Horizontal tab
%          #xA               | // Line feed
%          #xD               | // Carriage return
%          [#x20-#xD7FF]     | // Space, punctuation, numbers, letters
%          [#xE000-#xFFFD]   |
%          [#x10000-#x10FFFF]
% ~~~
%
% Avoid comapatibility characters [Unicode, section 2.3].
% Avoid the following characters (control characters,
% permanently undefined Unicode characters):
%
% ~~~{.txt}
% [#x7F-#x84] // Delete, ...
% [#x86-#x9F]
% [#xFDD0-#xFDEF],
% [#x1FFFE-#x1FFFF]
% [#x2FFFE-#x2FFFF]
% [#x3FFFE-#x3FFFF]
% [#x4FFFE-#x4FFFF]
% [#x5FFFE-#x5FFFF]
% [#x6FFFE-#x6FFFF]
% [#x7FFFE-#x7FFFF]
% [#x8FFFE-#x8FFFF]
% [#x9FFFE-#x9FFFF]
% [#xAFFFE-#xAFFFF]
% [#xBFFFE-#xBFFFF]
% [#xCFFFE-#xCFFFF]
% [#xDFFFE-#xDFFFF]
% [#xEFFFE-#xEFFFF]
% [#xFFFFE-#xFFFFF]
% [#x10FFFE-#x10FFFF]
% ~~~
%
% @see XML 1.0 Fifth Edition
% @tbd Add Unicode support and make sure the right character ranges
%      are selected.

% Horizontal tab =|#x9|=
xml_char_10(X) -->
  horizontal_tab(X).
% Line feed =|#xA|=
xml_char_10(X) -->
  line_feed(X).
% Carriage return =|#xD|=
xml_char_10(X) -->
  carriage_return(X).
% Space, punctuation, numbers, letters
% =|#x20-#xD7FF|=
xml_char_10(X) -->
  between(20, 55295, X).
% =|#xE000-#xFFFD|=
xml_char_10(X) -->
  between(57344, 65533, X).
% =|#x10000-#x10FFFF|=
xml_char_10(X) -->
  between(65536, 1114111, X).


%! xml_char_11(?Code:between(1,1114111))// is nondet.
% ~~~{.bnf}
% [2] Char ::= [#x1-#xD7FF]
%            | [#xE000-#xFFFD]
%            | [#x10000-#x10FFFF]
%            /* any Unicode character, excluding the surrogate blocks,
%               FFFE, and FFFF. */
% ~~~
%
% @see XML 1.1 Second Edition

% =|#x1-#xD7FF|=
xml_char_11(X) -->
  between(1, 55295, X).
% =|#xE000-#xFFFD|=
xml_char_11(X) -->
  between(57344, 65533, X).
% =|#x10000-#x10FFFF|=
xml_char_11(X) -->
  between(65536, 1114111, X).


xml_chars_10([H|T]) -->
  xml_char_10(H),
  xml_chars_10(T).
xml_chars_10([]) --> [].


xml_chars_11([H|T]) -->
  xml_char_11(H),
  xml_chars_11(T).
xml_chars_11([]) --> [].


%! 'Name'(?Name:atom)//
% A **XML Name** is an Nmtoken with a restricted set of initial characters.
%
% Disallowed initial characters for names include digits, diacritics,
% the full stop and the hyphen.
%
% ~~~{.bnf}
% [5]    Name ::= NameStartChar (NameChar)*
% ~~~
%
% ## Reserved names
%
% Names beginning with `(x,m,l)` are reserved for standardization in this
% or future versions of this specification.
%
% ## XML Namespaces
%
% The Namespaces in XML Recommendation assigns a meaning to names containing
% colon characters. Therefore, authors should not use the colon in XML names
% except for namespace purposes, but XML processors must accept the colon as
% a name character.
%
% @compat XML 1.0.5, XML 1.1.2.

'Name'(Name) -->
  {nonvar(Name)}, !,
  {atom_codes(Name, Codes)},
  'Name'_(Codes).
'Name'(Name) -->
  'Name'_(Codes),
  {atom_codes(Name, Codes)}.

'Name'_([H|T]) -->
  'NameStartChar'(H),
  'NameChar*'([T]).


%! 'NameChar'(?Char:code)//
% ~~~{.bnf}
% [4a]    NameChar ::= NameStartChar |
%                      "-" |
%                      "." |
%                      [0-9] |
%                      #xB7 |
%                      [#x0300-#x036F] |
%                      [#x203F-#x2040]
% ~~~
%
% @compat XML 1.0.5, XML 1.1.2.

'NameChar'(C) --> 'NameStartChar'(C).
'NameChar'(C) --> hyphen_minus(C).
'NameChar'(C) --> dot(C).
'NameChar'(C) --> decimal_digit(C).
% #x00B7
'NameChar'(C) --> middle_dot(C).
% #x0300-#x036F
'NameChar'(C) --> between_hex('0300', '036F', C).
% #x203F
'NameChar'(C) --> undertie(C).
% #x2040
'NameChar'(C) --> character_tie(C).

'NameChar*'([H|T]) -->
  'NameChar'(H),
  'NameChar*'(T).
'NameChar*'([]) --> [].


%! 'Names'(?Names:list(atom))// .
% ~~~{.ebnf}
% [6]    Names	 ::= Name (#x20 Name)*
% ~~~

'Names'([H|T]) -->
  'Name'(H),
  '(#x20 Name)*'(T).

'(#x20 Name)*'([]) --> [].
'(#x20 Name)*'([H|T]) -->
  ` `,
  'Name'(H),
  '(#x20 Name)*'(T).


%! 'NameStartChar'(?Code:code)//
% ~~~{.bnf}
% [4]    NameStartChar ::= ":" |
%                          [A-Z] |
%                          "_" |
%                          [a-z] |
%                          [#xC0-#xD6] |
%                          [#xD8-#xF6] |
%                          [#xF8-#x2FF] |
%                          [#x370-#x37D] |
%                          [#x37F-#x1FFF] |
%                          [#x200C-#x200D] |
%                          [#x2070-#x218F] |
%                          [#x2C00-#x2FEF] |
%                          [#x3001-#xD7FF] |
%                          [#xF900-#xFDCF] |
%                          [#xFDF0-#xFFFD] |
%                          [#x10000-#xEFFFF]
% ~~~
%
% @compat XML 1.0.5, XML 1.1.2.
% @compat We reuse SPARQL 1.1 Query [164].

'NameStartChar'(C) --> colon(C).
'NameStartChar'(C) --> underscore(C).
'NameStartChar'(C) --> 'PN_CHARS_BASE'(C).


%! 'Nmtoken'(?Code:code)// .
% ~~~{.ebnf}
% [7]    Nmtoken ::= (NameChar)+
% ~~~
%
% @compat XML 1.0.5, XML 1.1.2.

'Nmtoken'(Token) -->
  {nonvar(Token)}, !,
  {atom_codes(Token, Codes)},
  'Nmtoken_'(Codes).
'Nmtoken'(Token) -->
  'Nmtoken_'(Codes),
  {atom_codes(Token, Codes)}.

'Nmtoken_'([H|T]) -->
  'NameChar'(H),
  'NameChar*'(T).

'NameChar*'([]) --> [].
'NameChar*'([H|T]) -->
  'NameChar'(H),
  'NameChar*'(T).


%! 'Nmtokens'(?Codes:list(code))// .
% ~~~{.ebnf}
% [8]    Nmtokens ::= Nmtoken (#x20 Nmtoken)*
% ~~~
%
% @compat XML 1.0.5, XML 1.1.2.

'Nmtokens'([H|T]) -->
  'Nmtoken'(H),
  '(#x20 Nmtoken)*'(T).

'(#x20 Nmtoken)*'([]) --> [].
'(#x20 Nmtoken)*'([H|T]) -->
  ` `,
  'Nmtoken'(H),
  '(#x20 Nmtoken)*'(T).


%! xml_namespaced_name(:DCG_Namespace, :DCG_Name)//

xml_namespaced_name(DCG_Namespace, DCG_Name) -->
  {phrase(DCG_Namespace, [])},
  DCG_Name.
xml_namespaced_name(DCG_Namespace, DCG_Name) -->
  DCG_Namespace,
  colon,
  DCG_Name.


%! xml_restricted_char(?Char:code)//
% ~~~{.bnf}
% RestrictedChar ::= [#x1-#x8] |
%                    [#xB-#xC] |
%                    [#xE-#x1F] |
%                    [#x7F-#x84] |
%                    [#x86-#x9F]
% ~~~
%
% @see XML 1.1 Second Edition

xml_restricted_char(C) -->
  xml_char_11(C),
  % Not a start of heading, start of text, end of text, end of transmission,
  % enquiry, positive_acknowledgement, bell, backspace.
  {\+ between(1, 8, C)},
  % Not a vertical tab, form feed.
  {\+ between(11, 12, C)},
  % Not a shift out, shift in, data link escape, device control (1, 2, 3, 4),
  % negative acknowledgement, synchronous idle, end of transmission block,
  % cancel, end of medium, substitute, escape, file separator,
  % group separator, record separator, unit separator.
  {\+ between(14, 31, C)},
  % Not delete, ...
  {\+ between(127, 132, C)},
  % Not ..
  {\+ between(134, 159, C)}.


%! xml_space// .
%! xml_space(?Code:code)// .
% White space.
%
% ~~~{.bnf}
% S ::= (#x20 | #x9 | #xD | #xA)+   // Any consecutive number of spaces,
%                                   // carriage returns, line feeds, and
%                                   // horizontal tabs.
% ~~~
%
% The presence of carriage_return// in the above production is maintained
% purely for backward compatibility with the First Edition.
% All `#xD` characters literally present in an XML document are either removed
% or replaced by line_feed// (i.e., `#xA`) characters before any other
% processing is done.

xml_space -->
  xml_space(_).

xml_space(C) --> carriage_return(C).
xml_space(C) --> horizontal_tab(C).
xml_space(C) --> line_feed(C).
xml_space(C) --> space(C).

xml_yes_no(xml_yes_no(no), false) --> "no".
xml_yes_no(xml_yes_no(yes), true) --> "yes".

