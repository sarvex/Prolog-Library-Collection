:- module(
  math_ext,
  [
    absolute/2, % ?Number:number
                % ?Absolute:number
    average/2, % +Numbers:list(number)
               % -Average:number
    betwixt/3, % +Low:integer
               % +High:integer
               % ?Value:integer
    betwixt/4, % +Low:integer
               % +High:integer
               % +Interval:integer
               % ?Value:integer
    binomial_coefficient/3, % +M:integer
                            % +N:integer
                            % -BinomialCoefficient:integer
    circumfence/2, % +Radius:float
                   % -Circumfence:float
    combinations/3, % +NumberOfObjects:integer
                    % +CombinationLength:integer
                    % -NumberOfCombinations:integer
    count_down/2, % ?From:or([integer,oneof([inf])])
                  % ?To:or([integer,oneof([inf])])
    cyclic_numlist/4, % +Low:integer
                      % +High:integer
                      % +CycleLength:integer
                      % -NumList:list(integer)
    decimal_parts/3, % ?Decimal:compound
                     % ?Integer:integer
                     % ?Fraction:compound
    div/3,
    div_zero/3,
    euclidean_distance/3, % +Coordinate1:coordinate
                          % +Coordinate2:coordinate
                          % -EuclideanDistance:float
    even/1, % +Integer:integer
    factorial/2, % +N:integer
                 % -F:integer
    fibonacci/2, % ?Index:integer
                 % ?Fibonacci:integer
    fractional_integer/2, % +Number:or([float,integer,rational])
                          % -Fractional:integer
    is_fresh_age/2, % +Age:between(0.0,inf)
                    % +FreshnessLifetime:between(0.0,inf)
    is_stale_age/2, % +Age:between(0.0,inf)
                    % +FreshnessLifetime:between(0.0,inf)
    log/3, % +Base:integer
           % +X:float
           % +Y:float
    minus/3, % ?X:number
             % ?Y:number
             % ?Z:number
    minus_list/3, % +N:number
                  % +Ms:list(number)
                  % -N_Minus_Ms:number
    mod/3,
    multiply_list/2, % +Numbers:list(number)
                     % -Multiplication:number
    normalized_number/3, % +Decimal:compound
                         % -NormalizedDecimal:compound
                         % -Exponent:nonneg
    number_length/2, % +Number:number
                     % -Length:integer
    number_length/3, % +Number:number
                     % +Radix:integer
                     % -Length:integer
    odd/1, % +Integer:integer
    permutations/2, % +NumberOfObjects:integer
                    % -NumberOfPermutations:integer
    permutations/3, % +NumbersOfObjects:list(integer)
                    % +PermutationLength:integer
                    % -NumberOfPermutations:integer
    permutations/3, % +NumberOfObjects:integer
                    % +PermutationLength:integer
                    % -NumberOfPermutations:integer
    pred/2, % +X:integer
            % -Y:integer
    square/2, % +X:float
              % -Square:float
    succ_inf/2 % ?X:integer
               % ?Y:integer
  ]
).

/** <module> Math extensions

Extra arithmetic operations for use in SWI-Prolog.

@author Wouter Beek
@version 2011/08-2012/02, 2012/09-2012/10, 2012/12, 2013/07-2013/09, 2014/05,
         2014/10, 2015/02
*/

:- use_module(library(apply)).
:- use_module(library(error)).
:- use_module(library(lists), except([delete/3,subset/2])).

:- use_module(plc(generics/typecheck)).
:- use_module(plc(math/float_ext)).
:- use_module(plc(math/int_ext)).
:- use_module(plc(math/rational_ext)).





%! absolute(+Number:number, +Absolute:number) is semidet.
%! absolute(+Number:number, -Absolute:number) is det.
%! absolute(-Number:number, +Absolute:number) is multi.
% @throws instantiation_error If both arguments are uninstantiated.

absolute(N, Abs):-
  nonvar(N), !,
  Abs is abs(N).
absolute(N, Abs):-
  nonvar(Abs), !,
  (   N is Abs
  ;   N is -1 * Abs
  ).
absolute(_, _):-
  instantiation_error(_).



average([], 0.0):- !.
average(Numbers, Average):-
  sum_list(Numbers, Sum),
  length(Numbers, NumberOfNumbers),
  Average is Sum / NumberOfNumbers.



%! betwixt(+Low:integer, +High:integer, +Value:integer) is semidet.
%! betwixt(+Low:integer, +High:integer, -Value:integer) is multi.
%! betwixt(-Low:integer, +High:integer, +Value:integer) is semidet.
%! betwixt(-Low:integer, +High:integer, -Value:integer) is multi.
%! betwixt(+Low:integer, -High:integer, +Value:integer) is semidet.
%! betwixt(+Low:integer, -High:integer, -Value:integer) is multi.
% Like ISO between/3, but allowing either `Low` or `High`
% to be uninstantiated.
%
% We allow `Low` to be instantiated to `minf` and `High` to be
% instantiated to `inf`. In these cases, their values are replaced by
% fresh variables.

betwixt(Low1, High1, Value):-
  betwixt_lower_bound(Low1, Low2),
  betwixt_higher_bound(High1, High2),
  betwixt0(Low2, High2, Value).

% Instantiation error: at least one bound must be present.
betwixt0(Low, High, Value):-
  var(Low),
  var(High), !,
  instantiation_error(betwixt(Low, High, Value)).
% Behavior of ISO between/3.
betwixt0(Low, High, Value):-
  nonvar(Low),
  nonvar(High), !,
  between(Low, High, Value).
% The higher bound is missing.
betwixt0(Low, High, Value):-
  nonvar(Low), !,
  betwixt_low(Low, Low, High, Value).
% The lower bound is missing.
betwixt0(Low, High, Value):-
  nonvar(High), !,
  betwixt_high(Low, High, High, Value).

betwixt_high(_, Value, _, Value).
betwixt_high(Low, Between1, High, Value):-
  succ(Between2, Between1),
  betwixt_high(Low, Between2, High, Value).

betwixt_higher_bound(inf, _):- !.
betwixt_higher_bound(High, High).

betwixt_low(_, Value, _, Value).
betwixt_low(Low, Between1, High, Value):-
  succ(Between1, Between2),
  betwixt_low(Low, Between2, High, Value).

betwixt_lower_bound(minf, _):- !.
betwixt_lower_bound(Low, Low).



%! betwixt(
%!   +Low:integer,
%!   +High:integer,
%!   +Interval:integer,
%!   +Value:integer
%! ) is semidet.
%! betwixt(
%!   +Low:integer,
%!   +High:integer,
%!   +Interval:integer,
%!   -Value:integer
%! ) is nondet.

betwixt(Low, _, _, Low).
betwixt(Low0, High, Interval, Value):-
  Low is Low0 + Interval,
  (   High == inf
  ->  true
  ;   Low =< High
  ),
  betwixt(Low, High, Interval, Value).



binomial_coefficient(M, N, BC):-
  factorial(M, F_M),
  factorial(N, F_N),
  MminN is M - N,
  factorial(MminN, F_MminN),
  BC is F_M / (F_N * F_MminN).


%! circumfence(+Radius:float, -Circumfence:float) is det.
% Returns the circumfence of a circle with the given radius.

circumfence(Radius, Circumfence):-
  Circumfence is Radius * pi * 2.

%! combinations(
%!   +NumberOfObjects:integer,
%!   +CombinationLength:integer,
%!   -NumberOfCombinations:integer
%! ) is det.
% Returns the number of combinations from the given objects and
% of the given size.
%
% *Definition*: A combination is a permutation in which the order
%               neglected. Therefore, $r!$ permutations correspond to
%               one combination (with r the combination length).

combinations(NumberOfObjects, CombinationLength, NumberOfCombinations):-
  permutations(NumberOfObjects, CombinationLength, NumberOfPermutations),
  factorial(CombinationLength, F),
  NumberOfCombinations is NumberOfPermutations / F.


%! count_down(
%!   +From:or([integer,oneof([inf])]),
%!   -To:or([integer,oneof([inf])])
%! ) is det.
%! count_down(
%!   -From:or([integer,oneof([inf])]),
%!   +To:or([integer,oneof([inf])])
%! ) is det.
% Decrements an integer, allowing the value `inf` as well.

count_down(inf, inf):- !.
count_down(N1, N2):-
  succ(N2, N1).


%! cyclic_numlist(
%!   +Low:integer,
%!   +High:integer,
%!   +CycleLength:integer,
%!   -NumList:list(integer)
%! ) is det.
% Generates a number list for a cyclic list of numbers.
% This method works on a off-by-zero basis.
% We return the numbers in a sorted order.

cyclic_numlist(Low, High, _CycleLength, NumList):-
  Low < High, !,
  numlist(Low, High, NumList).
cyclic_numlist(Low, High, CycleLength, NumList):-
  Top is CycleLength - 1,
  numlist(Low, Top, HigherNumList),
  numlist(0, High, LowerNumList),
  append(LowerNumList, HigherNumList, NumList).



%! decimal_parts(
%!   +Decimal:compound,
%!   -Integer:integer,
%!   -Fractional:integer
%! ) is det.
%! decimal_parts(
%!   -Decimal:compound,
%!   +Integer:integer,
%!   +Fractional:integer
%! ) is det.
% @throws domain_error If `Fractional` is negative.

decimal_parts(_, _, Fractional):-
  nonvar(Fractional),
  Fractional < 0, !,
  domain_error(nonneg, Fractional).
decimal_parts(Decimal, Integer, Fractional):-
  nonvar(Decimal), !,
  Integer is floor(float_integer_part(Decimal)),
  fractional_integer(Decimal, Fractional).
decimal_parts(Number, Integer, Fractional):-
  number_length(Fractional, Length),
  Number is copysign(abs(Integer) + (Fractional rdiv (10 ^ Length)), Integer).



% @tbd
div(X, Y, Z):-
  rational(X), rational(Y), !,
  rational_div(X, Y, Z).
div(X, Y, Z):-
  float_div(X, Y, Z).


div_zero(X, 0, 0):-
  integer(X), !.
div_zero(X, 0.0, 0.0):-
  float(X), !.
div_zero(X, Y, Z):-
  Z is X / Y.


%! euclidean_distance(
%!   +Coordinate1:coordinate,
%!   +Coordinate2:coordinate,
%!   -EuclideanDistance:float
%! ) is det.
% Returns the Euclidean distance between two coordinates.

euclidean_distance(
  coordinate(Dimension, Args1),
  coordinate(Dimension, Args2),
  EuclideanDistance
):-
  maplist(minus, Args1, Args2, X1s),
  maplist(square, X1s, X2s),
  sum_list(X2s, X2),
  EuclideanDistance is sqrt(X2).


%! even(+Number:number) is semidet.
% Succeeds if the integer is even.

even(N):-
  mod(N, 2, 0).


%! factorial(+N:integer, -F:integer) is det.
% Returns the factorial of the given number.
%
% The standard notation for the factorial of _|n|_ is _|n!|_.
%
% *Definition*: $n! = \prod_{i = 1}^n i$

factorial(N, F):-
  numlist(1, N, Numbers), !,
  multiply_list(Numbers, F).
% E.g., $0!$.
factorial(_N, 1).

fibonacci(0, 1):- !.
fibonacci(1, 1):- !.
fibonacci(N, F):-
  N1 is N - 1,
  N2 is N - 2,
  fibonacci(N1, F1),
  fibonacci(N2, F2),
  F is F1 + F2.


%! fractional_integer(
%!   +Number:or([float,integer,rational]),
%!   -Fractional:integer
%! ) is det.
% Variant of float_fractional_part/2,
% where the integer value of the fractional part is returned.

fractional_integer(Number, Fractional):-
  atom_number(NumberAtom, Number),
  % We assume that there is at most one occurrence of `.`.
  sub_atom(NumberAtom, IndexOfDot, 1, _, '.'), !,
  succ(IndexOfDot, Skip),
  sub_atom(NumberAtom, Skip, _, 0, FractionalAtom),
  atom_number(FractionalAtom, Fractional).
fractional_integer(_, 0).


%! is_fresh_age(
%!   +Age:between(0.0,inf),
%!   +FreshnessLifetime:between(0.0,inf)
%! ) is semidet.

is_fresh_age(_, inf):- !.
is_fresh_age(Age, FreshnessLifetime):-
  Age =< FreshnessLifetime.


%! is_stale_age(
%!   +Age:between(0.0,inf),
%!   +FreshnessLifetime:between(0.0,inf)
%! ) is semidet.

is_stale_age(_, inf):- !, fail.
is_stale_age(Age, FreshnessLifetime):-
  Age > FreshnessLifetime.


%! log(+Base:integer, +X:integer, -Y:double) is det.
% Logarithm with arbitrary base `Y = log_{Base}(X)`.
%
% @arg Base An integer.
% @arg X An integer.
% @arg Y A double.

log(Base, X, Y):-
  Numerator is log(X),
  Denominator is log(Base),
  Y is Numerator / Denominator.


%! minus(+X:number, +Y:number, +Z:number) is semidet.
%! minus(+X:number, +Y:number, -Z:number) is det.
%! minus(+X:number, -Y:number, +Z:number) is det.
%! minus(-X:number, +Y:number, +Z:number) is det.

minus(X, Y, Z):-
  nonvar(X), nonvar(Y), !,
  Z is X - Y.
minus(X, Y, Z):-
  nonvar(X), nonvar(Z), !,
  Y is X - Z.
minus(X, Y, Z):-
  nonvar(Y), nonvar(Z), !,
  X is Y + Z.


%! minus_list(+N:number, +Ms:list(number), -N_Minus_Ms:number) is det.
% Subtracts the given numbers for the given start number
% and returns the result.

minus_list(N, Ms, N_Minus_Ms):-
  sum_list(Ms, M),
  N_Minus_Ms is N - M.


mod(X, Y, Z):-
  rational(X), rational(Y), !,
  rational_mod(X, Y, Z).
mod(X, Y, Z):-
  float_mod(X, Y, Z).


%! multiply_list(+List:list(number), -Multiplication:number) is det.
% Multiplies the numbers in the given list.
%
% @arg List A list of numbers.
% @arg Multiplication A number.
%
% @see Extends the builtin list manipulators sum_list/2, max_list/2
%      and min_list/2.

multiply_list([], 0).
multiply_list([H|T], M2):-
  multiply_list(T, M1),
  M2 is H * M1.



%! normalized_number(
%!   +Decimal:compound,
%!   -NormalizedDecimal:compound,
%!   -Exponent:integer
%! ) is det.
% A form of **Scientific notation**, i.e., $a \times 10^b$,
% in which $0 \leq a < 10$.
%
% The exponent $b$ is negative for a number with absolute value between
% $0$ and $1$ (e.g. $0.5$ is written as $5×10^{-1}$).
%
% The $10$ and exponent are often omitted when the exponent is $0$.

normalized_number(D, D, 0):-
  1.0 =< D,
  D < 10.0, !.
normalized_number(D1, ND, Exp1):-
  D1 >= 10.0, !,
  D2 is D1 / 10.0,
  normalized_number(D2, ND, Exp2),
  Exp1 is Exp2 + 1.
normalized_number(D1, ND, Exp1):-
  D1 < 1.0, !,
  D2 is D1 * 10.0,
  normalized_number(D2, ND, Exp2),
  Exp1 is Exp2 - 1.



%! number_length(+Number:number, -Length:integer) is det.
% @see number_length/3 with radix set to `10` (decimal).

number_length(M, L):-
  number_length(M, 10.0, L).

%! number_length(+Number:number, +Radix:integer, -Length:integer) is det.
% Returns the length of the given number 'before the dot'.
% The number is in decimal notation.
%
% @arg An integer representing a decimal number.
% @arg Radix An integer representing the radix used.
%      Common values are `2` (binary), `8` (octal),
%      `10` (decimal), and `16` (hexadecimal).
% @arg Length An integer representing the number of digits in
%      the given number.

number_length(N1, Radix, L1):-
  N2 is N1 / Radix,
  N2 >= 1.0, !,
  number_length(N2, Radix, L2),
  L1 is L2 + 1.
number_length(_N, _Radix, 1):- !.



%! odd(?Number:number) is semidet.
% Succeeds if the integer is odd.

odd(N):-
  mod(N, 2, 1).



%! permutations(
%!   +NumbersOfObjects:list(integer),
%!   -NumberOfPermutations:integer
%! ) is det.
%! permutations(
%!   +NumberOfObjects:integer,
%!   -NumberOfPermutations:integer
%! ) is det.
% Returns the number of permutations that can be created with
% the given number of distinct objects.
%
% @see permutations/3

permutations(NumbersOfObjects, NumberOfPermutations):-
  is_list(NumbersOfObjects), !,
  sum_list(NumbersOfObjects, NumberOfObjects),
  permutations(NumbersOfObjects, NumberOfObjects, NumberOfPermutations).
permutations(NumberOfObjects, NumberOfPermutations):-
  permutations([NumberOfObjects], NumberOfPermutations).

%! permutations(
%!   +NumbersOfObjects:list(integer),
%!   +PermutationLength:integer,
%!   -NumberOfPermutations:integer
%! ) is det.
%! permutations(
%!   +NumberOfObjects:integer,
%!   +PermutationLength:integer,
%!   -NumberOfPermutations:integer
%! ) is det.
% Returns the number of permutations that can be created with
% the given numbers of distinct objects and that have (exactly)
% the given length.
%
% *Definition*: The number of permutations of _|m|_ groups of unique objects
%               (i.e., types) and with _|n_i|_ group members or occurences
%               (i.e., tokens), for $0 \leq i \leq m$ and that are (exactly)
%               of length _|r|_ is $\frac{n!}{\mult_{i = 1}^m(n_i!)(n - r)!}$.
%
% @arg NumbersOfObject A list of numbers, each indicating the number of
%        objects in a certain group.
% @arg PermutationLength The (exact) number of objects that occur
%        in a permutation.
% @arg NumberOfPermutations The number of permutations that can be created.

permutations(NumbersOfObjects, PermutationLength, NumberOfPermutations):-
  is_list(NumbersOfObjects), !,

  % The objects.
  sum_list(NumbersOfObjects, NumberOfObjects),
  factorial(NumberOfObjects, F1),

  % The length compensation.
  Compensation is NumberOfObjects - PermutationLength,
  factorial(Compensation, F3),

  % The groups.
  maplist(factorial, NumbersOfObjects, F2s),
  multiply_list([F3 | F2s], F23),

  NumberOfPermutations is F1 / F23.
permutations(NumberOfObjects, PermutationLength, NumberOfPermutations):-
  factorial(NumberOfObjects, F1),
  Compensation is NumberOfObjects - PermutationLength,
  factorial(Compensation, F2),
  NumberOfPermutations is F1 / F2.


%! pred(?Integer:integer, ?Predecessor:integer)
% A integer and its direct predecessor integer.
%
% This is used by meta-predicates that require uniform instantiation patterns.
%
% @arg Integer An integer.
% @arg Predecessor An integer.
% @see This extends the builin succ/2.

pred(Integer, Predecessor):-
  succ(Predecessor, Integer).


%! square(+X:float, -Square:float) is det.
% Returns the square of the given number.

square(X, Square):-
  Square is X ** 2.


%! succ_inf(+X:or([oneof([inf]),nonneg]), +Y:or([oneof([inf]),nonneg])) is semidet.
%! succ_inf(+X:or([oneof([inf]),nonneg]), -Y:or([oneof([inf]),nonneg])) is det.
%! succ_inf(-X:or([oneof([inf]),nonneg]), +Y:or([oneof([inf]),nonneg])) is det.
% Variant of succ/2 that allows the value `inf` to be used.

succ_inf(inf, inf):- !.
succ_inf(X, Y):-
  succ(X, Y).

