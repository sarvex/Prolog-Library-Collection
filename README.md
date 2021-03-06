Prolog Library Collection (PLC)
===============================

This is a collection of Prolog libraries that augment the functionality
available in [SWI-Prolog](www.swi-prolog.org).

Contents
--------

This repository contains the following subcollections of Prolog modules:
  - `/generics`
  - `/math`
  - `/os`
  - `/prolog`

plDoc online documentation
--------------------------

If you want to make the dynamic tables visible in the plDoc documentation
server, you need to add the following clause to the `take_block` predicate
in `pldoc/doc_wiki.pl`. This code cannot be included in SWI-Prolog
releases because of the security implications of running arbitrary code on
a server.

```prolog
take_block(
  [_-['!', '!', w(Module), '!', '!', w(Predicate), '!', '!', w(Arity0), '!', '!'] | Lines],
  _BaseIndent,
  table([class(wiki)], Rows),
  Lines
):-
  atom_number(Arity0, Arity),
  findall(
    tr(Cells),
    (
      length(Vars, Arity),
      Call =.. [Predicate | Vars],
      call(Module:Call),
      findall(
        td([w(Atom)]),
        (
          member(Var, Vars),
          (atomic(Var) -> Atom = Var ; term_to_atom(Var, Atom))
        ),
        Cells
      )
    ),
    Rows
  ).
```
