module Internal.Junk exposing (..)

{-| -}

import Color
import Svg exposing (Svg)
import Html exposing (Html)
import Html.Attributes
import LineChart.Coordinate as Coordinate
import Color.Convert
import Internal.Svg as Svg
import Internal.Utils as Utils


{-| -}
type Config data msg =
  Config (List (Series data) -> (data -> Maybe Float) -> (data -> Maybe Float) -> Coordinate.System -> Layers msg)


type alias Series data =
  ( Color.Color, String, List data )


{-| -}
none : Config data msg
none =
  Config (\_ _ _ _ -> Layers [] [] [])


{-| -}
custom : (Coordinate.System -> Layers msg) -> Config data msg
custom func =
  Config (\_ _ _ -> func)


{-| -}
type alias Layers msg =
  { below : List (Svg msg)
  , above : List (Svg msg)
  , html : List (Html msg)
  }


{-| -}
getLayers : List (Series data) -> (data -> Maybe Float) -> (data -> Maybe Float) -> Coordinate.System -> Config data msg -> Layers msg
getLayers series toX toY system (Config toLayers) =
  toLayers series toX toY system


{-| -}
addBelow : List (Svg msg) -> Layers msg -> Layers msg
addBelow below layers =
  { layers | below = below ++ layers.below }



-- HOVERS


hoverOne : Maybe data -> List ( String, data -> String ) -> Config data msg
hoverOne hovered properties =
  Config <| \_ toX toY system ->
    { below = []
    , above = []
    , html  = [ Utils.viewMaybe hovered (hoverOneHtml system toX toY properties) ]
    }


hoverOneHtml
  :  Coordinate.System
  -> (data -> Maybe Float)
  -> (data -> Maybe Float)
  -> List ( String, data -> String )
  -> data
  -> Html.Html msg
hoverOneHtml system toX toY properties hovered =
  let
    x = Maybe.withDefault (middle .x system) (toX hovered)
    y = Maybe.withDefault (middle .y system) (toY hovered)

    viewValue ( label, value ) =
      viewRow "inherit" label (value hovered)
  in
  hoverAt system x y [] <|
    List.map viewValue properties



-- HOVER MANY


{-| -}
type alias HoverManyConfig data =
  { x : data -> String
  , y : data -> String
  }


hoverMany : List data -> HoverManyConfig data -> Config data msg
hoverMany hovered format =
  case hovered of
    [] ->
      none

    first :: rest ->
      Config <| \series toX toY system ->
        let xValue = Maybe.withDefault 0 (toX first) in -- TODO Maybe should happen - make it not.
        { below = [ Svg.verticalGrid system [] xValue ]
        , above = []
        , html  = [ hoverManyHtml system toX toY format first hovered series ]
        }


hoverManyHtml
  :  Coordinate.System
  -> (data -> Maybe Float)
  -> (data -> Maybe Float)
  -> HoverManyConfig data
  -> data
  -> List data
  -> List (Series data)
  -> Html.Html msg
hoverManyHtml system toX toY format first hovered series =
  let
    x = Maybe.withDefault (middle .x system) (toX first)

    viewValue ( color, label, data ) =
      Utils.viewMaybe (find hovered data) <| \hovered ->
        viewRow (Color.Convert.colorToHex color) label (format.y hovered)
  in
  hover system x [] <|
    viewHeader (format.x first) :: List.map viewValue series


standardStyles : List ( String, String )
standardStyles =
  [ ( "padding", "5px" )
  , ( "min-width", "100px" )
  , ( "background", "rgba(255,255,255,0.8)" )
  , ( "border", "1px solid #d3d3d3" )
  , ( "border-radius", "5px" )
  , ( "pointer-events", "none" )
  ]


viewHeader : String -> Html.Html msg
viewHeader value =
  Html.p
    [ Html.Attributes.style
        [ ( "margin-top", "3px" )
        , ( "margin-bottom", "5px" )
        , ( "padding", "3px" )
        , ( "border-bottom", "1px solid rgb(163, 163, 163)" )
        ]
    ]
    [ Html.text value ]


viewRow : String -> String -> String -> Html.Html msg
viewRow color label value =
  Html.p
    [ Html.Attributes.style [ ( "margin", "3px" ), ( "color", color ) ] ]
    [ Html.text (label ++ ": " ++ value) ]



-- HOVER GENERAL


{-| -}
hover : Coordinate.System  -> Float -> List ( String, String ) -> List (Html.Html msg) -> Html.Html msg
hover system x styles =
  let
    y = middle .y system

    containerStyles =
      [ if shouldFlip system x
          then ( "transform", "translate(-100%, -50%)" )
          else ( "transform", "translate(0, -50%)" )
      ]
      ++ styles
  in
  hoverAt system x y containerStyles


{-| -}
hoverAt : Coordinate.System  -> Float -> Float -> List ( String, String ) -> List (Html.Html msg) -> Html.Html msg
hoverAt system x y styles view =
  let
    space = if shouldFlip system x then -15 else 15
    xPosition = Coordinate.toSvgX system x + space
    yPosition = Coordinate.toSvgY system y

    posititonStyles =
      [ ( "left", toString xPosition ++ "px" )
      , ( "top", toString yPosition ++ "px" )
      , ( "position", "absolute" )
      , if shouldFlip system x
          then ( "transform", "translateX(-100%)" )
          else ( "transform", "translateX(0)" )
      ]

    containerStyles =
      standardStyles ++ posititonStyles ++styles
  in
  Html.div [ Html.Attributes.style containerStyles ] view



-- UTILS


middle : (Coordinate.System -> Coordinate.Range) -> Coordinate.System -> Float
middle r system =
  let range = r system in
  range.min + (range.max - range.min) / 2


shouldFlip : Coordinate.System -> Float -> Bool
shouldFlip system x =
  x - system.x.min > system.x.max - x


find : List data -> List data -> Maybe data
find hovered data =
  case hovered of
    [] ->
      Nothing

    first :: rest ->
      if List.any ((==) first) data then
        Just first
      else
        find rest data
