%%% Copyright (C) 2006 - 2008 Willem de Jong
%%%
%%% This file is part of Erlsom.
%%%
%%% Erlsom is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU Lesser General Public License as 
%%% published by the Free Software Foundation, either version 3 of 
%%% the License, or (at your option) any later version.
%%%
%%% Erlsom is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU Lesser General Public License for more details.
%%%
%%% You should have received a copy of the GNU Lesser General Public 
%%% License along with Erlsom.  If not, see 
%%% <http://www.gnu.org/licenses/>.
%%%
%%% Author contact: w.a.de.jong@gmail.com

%%% ====================================================================
%%% Writes record definitions, to be used with Erlsom.
%%% ====================================================================

%%% Writes record defintions, taking a 'model' (from erlsom_compile) as
%%% input.

-module(erlsom_writeHrl).
-export([writeHrl/1]).
-export([writeHrlFile/3]).
-export([writeXsdHrlFile/2]).

-include("erlsom_parse.hrl").
-include("erlsom.hrl").

%% debug(Text) -> io:format("writeHrl: ~p~n", [Text]).

%% debug(Text1, Text2) ->
  %% io:format("~p ~p~n", [Text1, Text2]).

writeHrl(#model{tps = Types}) ->
  Acc = header(),
  writeTypes(Types, Acc).

writeHrlFile(Xsd, Prefix, Namespaces) ->
%% compile file
  Result = erlsom:compile(Xsd, Prefix, Namespaces),
  case Result of
    {ok, Model} -> 
      writeHrl(Model);
    {error, Error} -> 
      io:format("Error while compiling file: ~p~n", [Error])
  end.

writeXsdHrlFile(Xsd, Options) ->
%% compile file
  Result = erlsom:compile_xsd(Xsd, Options),
  case Result of
    {ok, Model} -> 
      writeHrl(Model);
    {error, Error} -> 
      throw({error, Error})
  end.

header() ->
"%% HRL file generated by ERLSOM\n"
"%%\n"
"%% It is possible to change the name of the record fields.\n"
"%%\n"
"%% It is possible to add default values, but be aware that these will\n"
"%% only be used when *writing* an xml document.\n\n".

writeTypes(Types, Acc) ->
  Acc ++ lists:foldl(fun writeType/2, [], erlsom_lib:unique(Types)).

writeType(#type{nm = '_document'}, Acc) ->
  Acc;
%% writeType(Type, []) -> writeType2(Type);
writeType(Type, Acc) ->
  Acc ++ writeType2(Type).

writeType2(#type{nm = Name, els = Elements, atts = Attributes}) ->
  "-record('" ++ atom_to_list(Name)
  ++ joinStrings("', {anyAttribs",
                 joinStrings(writeAttributes(Attributes), 
		             writeElements(Elements)))
  ++ "}).\n".

writeElements(Elements) ->
  writeElements(Elements, [], 0).
writeElements([], String, _) ->
  String;
writeElements([Element], Acc, CountChoices) ->
  {String, _} = writeElement(Element, CountChoices),
  Acc ++ String;
writeElements([Element | Tail], Acc, CountChoices) ->
  {String, CountChoices2} = writeElement(Element, CountChoices),
  writeElements(Tail, Acc  ++ String ++ ", ", CountChoices2).

writeElement(#el{alts = Alternatives}, CountChoices) ->
  writeAlternatives(Alternatives, CountChoices).

%% easy case: 1 alternative (not a choice), 'real' element (not a group)
writeAlternatives([], CountChoices) ->
  {"any_strict_but_none_defined", CountChoices};
writeAlternatives([#alt{tag = '#any'}], CountChoices) ->
  {"any", CountChoices};
writeAlternatives([#alt{tag = Tag, rl = true}], CountChoices) ->
  {"'" ++ erlsom_lib:nameWithoutPrefix(atom_to_list(Tag)) ++ "'", CountChoices};
writeAlternatives([#alt{tag = Tag, rl = false, tp = {_,_}}], CountChoices) ->
  {"'" ++ erlsom_lib:nameWithoutPrefix(atom_to_list(Tag)) ++ "'", CountChoices};
writeAlternatives([#alt{rl = false, tp=Tp}], CountChoices) ->
  {"'" ++ erlsom_lib:nameWithoutPrefix(atom_to_list(Tp)) ++ "'", CountChoices};
%% more than 1 alternative: a choice
writeAlternatives([#alt{} | _Tail], CountChoices) ->
  Acc = case CountChoices of
         0 ->
           "choice";
         _ -> 
           "choice" ++ integer_to_list(CountChoices)
       end,
  {Acc, CountChoices +1}.
      

writeAttributes(Attributes) ->
  lists:foldl(fun writeAttribute/2, [], Attributes).

writeAttribute(#att{nm = Name}, []) -> "'" ++ atom_to_list(Name) ++ "'";
writeAttribute(#att{nm = Name}, Acc) -> Acc  ++ ", '" ++ atom_to_list(Name) ++ "'".

joinStrings([], StringB) ->
  StringB;
joinStrings(StringA, []) ->
  StringA;
joinStrings(StringA, StringB) ->
  StringA ++ ", " ++ StringB.
