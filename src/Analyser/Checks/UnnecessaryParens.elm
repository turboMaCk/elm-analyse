module Analyser.Checks.UnnecessaryParens exposing (scan)

import AST.Types
    exposing
        ( Exposure(All, Explicit, None)
        , Expose(TypeExpose)
        , Expression(ParenthesizedExpression, OperatorApplicationExpression, FunctionOrValue, Integer, Floatable, Literal, CharLiteral, Application)
        , Parenthesized
        , File
        , Range
        , OperatorApplication
        )
import AST.Util exposing (getParenthesized, isOperatorApplication, isLambda)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages exposing (Message(UnnecessaryParens))
import Inspector exposing (Action(Post), defaultConfig)
import Maybe.Extra as Maybe
import List.Extra as List


type alias Context =
    List Range


rangetoTuple : Range -> ( Int, Int, Int, Int )
rangetoTuple x =
    ( x.start.row, x.start.column, x.end.row, x.end.column )


scan : FileContext -> List Message
scan fileContext =
    let
        x : Context
        x =
            Inspector.inspect
                { defaultConfig | onExpression = Post onExpression }
                fileContext.ast
                []
    in
        x
            |> List.uniqueBy rangetoTuple
            |> List.map (UnnecessaryParens fileContext.path)


onExpression : Expression -> Context -> Context
onExpression expression context =
    case expression of
        ParenthesizedExpression inner ->
            onParenthesizedExpression inner context

        OperatorApplicationExpression inner ->
            onOperatorApplicationExpression inner context

        Application parts ->
            onApplication parts context

        _ ->
            context


onApplication : List Expression -> Context -> Context
onApplication parts context =
    List.head parts
        |> Maybe.andThen getParenthesized
        |> Maybe.map .range
        |> Maybe.map (flip (::) context)
        |> Maybe.withDefault context


onOperatorApplicationExpression : OperatorApplication -> Context -> Context
onOperatorApplicationExpression oparatorApplication context =
    let
        fixHandSide f =
            getParenthesized
                >> Maybe.filter (.expression >> isOperatorApplication >> not)
                >> Maybe.filter (.expression >> f)
                >> Maybe.map .range
    in
        [ fixHandSide (isLambda >> not) oparatorApplication.left
        , fixHandSide (always True) oparatorApplication.right
        ]
            |> List.filterMap identity
            |> flip (++) context


onParenthesizedExpression : Parenthesized -> Context -> Context
onParenthesizedExpression { expression, range } context =
    case expression of
        FunctionOrValue _ ->
            range :: context

        Integer _ ->
            range :: context

        Floatable _ ->
            range :: context

        CharLiteral _ ->
            range :: context

        Literal _ ->
            range :: context

        _ ->
            context
