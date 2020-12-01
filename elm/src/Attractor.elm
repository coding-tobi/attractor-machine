port module Attractor exposing (main)

import Browser
import Html exposing (Attribute, Html, a, button, div, i, span, table, td, text, tr)
import Html.Attributes exposing (class, classList, colspan, style, title)
import Html.Events exposing (onClick)
import List.Extra
import RingBuffer exposing (RingBuffer, isFull)
import Svg exposing (Svg, svg)
import Svg.Attributes


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- TYPES


type alias Statistic =
    { numAttractors : Int
    , numParticles : Int
    , numPairs : Int
    , learningRate : Float
    }


type alias Step =
    { particles : List Float
    , loss : Float
    , numTensors : Int
    }


type alias Model =
    { particles : List ( Float, Float )
    , attractors : List ( Float, Float )
    , statistic : Statistic
    , numTensors : Int
    , attractorsVisible : Bool
    , loss : Float
    , lossDeltaBuffer : RingBuffer Float
    , lossDeltaAvg : Float
    , loopingShuffleActive : Bool
    }


type Msg
    = OptimizationStep Step
    | AttractorsChanged (List Float)
    | StatisticChanged Statistic
    | AddAttractors Int
    | ShuffleAttractors
    | ToggleAttractorsVisible
    | AddParticles Int
    | ShuffleParticles
    | IncreaseLearningRate Float
    | ToggleLoopingShuffle



-- PORTS


port runMachine : () -> Cmd msg


port stopMachine : () -> Cmd msg


port addAttractors : Int -> Cmd msg


port shuffleAttractors : () -> Cmd msg


port addParticles : Int -> Cmd msg


port shuffleParticles : () -> Cmd msg


port increaseLearningRate : Float -> Cmd msg


port attractorsChanged : (List Float -> msg) -> Sub msg


port optimizationStep : (Step -> msg) -> Sub msg


port statisticChanged : (Statistic -> msg) -> Sub msg



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { particles = []
      , attractors = []
      , statistic =
            { numAttractors = 0
            , numParticles = 0
            , numPairs = 0
            , learningRate = 0.0
            }
      , numTensors = 0
      , attractorsVisible = True
      , loss = 0.0
      , lossDeltaBuffer = RingBuffer.init 32
      , lossDeltaAvg = 0.0
      , loopingShuffleActive = True
      }
    , runMachine ()
    )



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "font-family" "sans-serif"
        , style "background-color" "white"
        , style "box-shadow" "0 0.5em 1em -0.125em rgba(10, 10, 10, 0.1), 0 0px 0 1px rgba(10, 10, 10, 0.02)"
        , style "border" "2px solid #0A7CC4"
        , style "border-radius" "4px"
        , style "padding" "10px"
        , style "display" "flex"
        , style "margin-left" "auto"
        , style "margin-right" "auto"
        , style "flex-flow" "row wrap"
        , style "max-width" "700px"
        , style "position" "relative"
        ]
        [ div
            [ style "flex" "1 1 380px" ]
            [ viewSvg model ]
        , div
            [ style "padding" "10px"
            , style "color" "hsl(0, 0%, 21%)"
            , style "width" "280px"
            ]
            [ viewStatistics model
            , viewAutoShuffle model
            ]
        -- , a
        --     [ Html.Attributes.href "http://www.coding-tobi.io"
        --     , Html.Attributes.target "_blank"
        --     , style "position" "absolute"
        --     , style "right" "4px"
        --     , style "bottom" "2px"
        --     ]
        --     [ text "made by coding-tobi.io" ]
        ]


viewSvg : Model -> Html Msg
viewSvg model =
    let
        viewParticle : Float -> String -> ( Float, Float ) -> Svg Msg
        viewParticle size color ( x, y ) =
            Svg.circle
                [ x |> String.fromFloat |> Svg.Attributes.cx
                , y |> String.fromFloat |> Svg.Attributes.cy
                , Svg.Attributes.r (size |> String.fromFloat)
                , Svg.Attributes.fill color
                ]
                []

        viewAttractor : Float -> Float -> String -> ( Float, Float ) -> List (Svg Msg)
        viewAttractor size distance color ( x, y ) =
            [ viewParticle size color ( x, y )
            , Svg.circle
                [ x |> String.fromFloat |> Svg.Attributes.cx
                , y |> String.fromFloat |> Svg.Attributes.cy
                , Svg.Attributes.r (distance |> String.fromFloat)
                , Svg.Attributes.fill "none"
                , Svg.Attributes.stroke (color ++ "80")
                , Svg.Attributes.strokeWidth "0.01"
                , Svg.Attributes.strokeDasharray "0.01, 0.02"
                ]
                []
            ]

        viewAttractors : List (Svg Msg)
        viewAttractors =
            if model.attractorsVisible then
                (model.attractors |> List.map (viewAttractor 0.03 0.5 "#0A7CC4")) |> List.concat

            else
                []

        viewGrid : List (Svg Msg)
        viewGrid =
            [ Svg.defs []
                [ Svg.pattern
                    [ Svg.Attributes.id "grid"
                    , Svg.Attributes.width "0.1"
                    , Svg.Attributes.height "0.1"
                    , Svg.Attributes.patternUnits "userSpaceOnUse"
                    ]
                    [ Svg.path
                        [ Svg.Attributes.d "M 0 0.1 L 0.1 0.1 0.1 0"
                        , Svg.Attributes.fill "none"
                        , Svg.Attributes.stroke "hsl(0, 0%, 86%)"
                        , Svg.Attributes.strokeWidth "0.01"
                        ]
                        []
                    ]
                ]
            , Svg.rect
                [ Svg.Attributes.width "100%"
                , Svg.Attributes.height "100%"
                , Svg.Attributes.x "-1"
                , Svg.Attributes.y "-1"
                , Svg.Attributes.fill "url(#grid)"
                ]
                []
            , Svg.path
                [ Svg.Attributes.d "M 0 -1 L 0 1 M -1 0 L 1 0"
                , Svg.Attributes.fill "none"
                , Svg.Attributes.stroke "hsl(0, 0%, 71%)"
                , Svg.Attributes.strokeWidth "0.0125"
                ]
                []
            ]
    in
    svg
        [ Svg.Attributes.width "100%"
        , Svg.Attributes.viewBox "-1 -1 2 2"
        , style "background-color" "white"
        , style "border-radius" "2px"
        , style "box-shadow" "inset 0 0 4px rgba(0, 0, 0, 0.21)"
        ]
        (viewGrid
            ++ viewAttractors
            ++ (model.particles |> List.map (viewParticle 0.015 "#B812B7"))
        )


viewStatistics : Model -> Html Msg
viewStatistics model =
    let
        attractorsVisibleButtonClass : Attribute msg
        attractorsVisibleButtonClass =
            if model.attractorsVisible then
                class "fas fa-eye fa-fw"

            else
                class "fas fa-eye-slash fa-fw"
    in
    div
        []
        [ table [ class "statistic-table" ]
            [ tr [ title "Number of blue attractors" ]
                [ td [] [ text "Attractors:" ]
                , td [ class "number-col" ] [ text (model.statistic.numAttractors |> String.fromInt) ]
                , td []
                    [ button
                        [ onClick (AddAttractors 1)
                        , class "flat-btn secondary"
                        , title "Add one attractor"
                        ]
                        [ i [ class "fas fa-plus fa-fw" ] [] ]
                    , button
                        [ onClick (AddAttractors -1)
                        , class "flat-btn secondary"
                        , title "Remove one attractor"
                        ]
                        [ i [ class "fas fa-minus fa-fw" ] [] ]
                    , button
                        [ onClick ShuffleAttractors
                        , class "flat-btn secondary"
                        , title "Shuffle attractors"
                        ]
                        [ i [ class "fas fa-dice fa-fw" ] [] ]
                    , button
                        [ onClick ToggleAttractorsVisible
                        , class "flat-btn"
                        , classList [ ( "secondary", model.attractorsVisible ) ]
                        , title "Toggle visibility"
                        ]
                        [ i [ attractorsVisibleButtonClass ] [] ]
                    ]
                ]
            , tr [ title "Number of crazy pink particles" ]
                [ td [] [ text "Particles:" ]
                , td [ class "number-col" ] [ text (model.statistic.numParticles |> String.fromInt) ]
                , td []
                    [ button
                        [ onClick (AddParticles 32)
                        , class "flat-btn tertiary"
                        , title "Add some crazy particles"
                        ]
                        [ i [ class "fas fa-plus fa-fw" ] [] ]
                    , button
                        [ onClick (AddParticles -32)
                        , class "flat-btn tertiary"
                        , title "Remove some crazy particles"
                        ]
                        [ i [ class "fas fa-minus fa-fw" ] [] ]
                    , button
                        [ onClick ShuffleParticles
                        , class "flat-btn tertiary"
                        , title "Shuffle crazy particles"
                        ]
                        [ i [ class "fas fa-dice fa-fw" ] [] ]
                    ]
                ]
            , tr [ title "Learning rate" ]
                [ td [] [ text "Rate:" ]
                , td [ class "number-col" ] [ text ((model.statistic.learningRate * 100 |> String.fromFloat |> String.slice 0 3) ++ "%") ]
                , td []
                    [ button
                        [ onClick (IncreaseLearningRate 0.005)
                        , class "flat-btn primary"
                        , title "Increase learning rate"
                        ]
                        [ i [ class "fas fa-plus fa-fw" ] [] ]
                    , button
                        [ onClick (IncreaseLearningRate -0.005)
                        , class "flat-btn primary"
                        , title "Decrease learning rate"
                        ]
                        [ i [ class "fas fa-minus fa-fw" ] [] ]
                    ]
                ]
            , tr [ title "Number of particle to particle and particle to attractor pairs" ]
                [ td [] [ text "Pairs:" ]
                , td [ class "number-col" ] [ text (model.statistic.numPairs |> String.fromInt) ]
                , td [] []
                ]
            , tr [ title "Number of Tensors used by tensorflow.js" ]
                [ td [] [ text "Tensors:" ]
                , td [ class "number-col" ] [ text (model.numTensors |> String.fromInt) ]
                ]
            , tr [ title "Current loss" ]
                [ td [] [ text "Loss / Δ:" ]
                , td
                    [ colspan 2
                    , class "number-col"
                    , style "text-align" "left"
                    ]
                    [ text
                        ((model.loss * 1000.0 |> String.fromFloat |> String.slice 0 6)
                            ++ " m / "
                            ++ ((model.lossDeltaAvg * 1000 |> String.fromFloat |> String.slice 0 5) ++ " m")
                        )
                    ]
                ]
            ]
        ]


viewAutoShuffle : Model -> Html Msg
viewAutoShuffle model =
    let
        square : Float -> Float
        square x =
            x * x

        fence : Float -> Float -> Float -> Float
        fence min max x =
            if x < min then
                min

            else if max < x then
                max

            else
                x

        map : Float -> Float -> Float -> Float -> Float -> Float
        map fromMin fromMax toMin toMax x =
            ((x - fromMin) / (fromMax - fromMin)) * (toMax - fromMax) + toMin

        progressWidthPercent : Float
        progressWidthPercent =
            model.lossDeltaAvg
                |> map 0.001 0.00001 0 1
                |> square
                |> map 0 1 0 100
                |> fence 0 100
                |> (\x ->
                        if isNaN x then
                            0

                        else
                            x
                   )
    in
    div []
        [ div [ title "Optimization progress" ]
            [ svg
                [ Svg.Attributes.width "100%"
                , Svg.Attributes.height "10"
                ]
                [ Svg.defs []
                    [ Svg.linearGradient
                        [ Svg.Attributes.id "fancy-grad"
                        , Svg.Attributes.x1 "0%"
                        , Svg.Attributes.y1 "0%"
                        , Svg.Attributes.x2 "100%"
                        , Svg.Attributes.y2 "100%"
                        ]
                        [ Svg.stop [ Svg.Attributes.offset "0%", Svg.Attributes.stopColor "#0A7CC4" ] []
                        , Svg.stop [ Svg.Attributes.offset "100%", Svg.Attributes.stopColor "#b812b7" ] []
                        ]
                    ]
                , Svg.rect
                    [ Svg.Attributes.width "100%"
                    , Svg.Attributes.height "100%"
                    , Svg.Attributes.x "0"
                    , Svg.Attributes.y "0"
                    , Svg.Attributes.rx "5"
                    , Svg.Attributes.ry "5"
                    , Svg.Attributes.fill "whitesmoke"
                    ]
                    []
                , Svg.rect
                    [ Svg.Attributes.width ((progressWidthPercent |> round |> String.fromInt) ++ "%")
                    , Svg.Attributes.height "100%"
                    , Svg.Attributes.x "0"
                    , Svg.Attributes.y "0"
                    , Svg.Attributes.rx "5"
                    , Svg.Attributes.ry "5"
                    , Svg.Attributes.fill "#00b89c"
                    ]
                    []
                ]
            ]
        , button
            [ onClick ToggleLoopingShuffle
            , class "flat-btn"
            , classList [ ( "fancy", model.loopingShuffleActive ) ]
            , title "Toggle on/off"
            ]
            [ i [ class "fas fa-redo", style "margin-right" "4px" ] []
            , i [ class "fas fa-dice" ] []
            ]
        , span [ class "number-col" ] [ text " Looping shuffle" ]
        ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        convertParticleData : List Float -> List ( Float, Float )
        convertParticleData data =
            data
                |> List.Extra.groupsOf 2
                |> List.map
                    (\pair ->
                        case pair of
                            [ x, y ] ->
                                ( x, y )

                            _ ->
                                ( 0, 0 )
                    )

        newLossDeltaBuffer : Step -> RingBuffer Float
        newLossDeltaBuffer data =
            if 0 < (model.loss - data.loss) then
                model.lossDeltaBuffer |> RingBuffer.push (model.loss - data.loss)

            else
                model.lossDeltaBuffer

        zeroIfNaN : Float -> Float
        zeroIfNaN x =
            if x |> isNaN then
                0.0

            else
                x

        newLossDeltaAvg : Step -> Float
        newLossDeltaAvg data =
            let
                sum =
                    newLossDeltaBuffer data
                        |> RingBuffer.values
                        |> List.foldl (+) 0.0

                length =
                    newLossDeltaBuffer data |> RingBuffer.length |> toFloat
            in
            (sum / length) |> zeroIfNaN
    in
    case msg of
        OptimizationStep data ->
            { model
                | particles = convertParticleData data.particles
                , loss = data.loss
                , numTensors = data.numTensors
                , lossDeltaBuffer = newLossDeltaBuffer data
                , lossDeltaAvg = newLossDeltaAvg data
            }
                |> (\m ->
                        if (m.lossDeltaBuffer |> RingBuffer.isFull) && m.lossDeltaAvg < 0.000001 then
                            ( { m | lossDeltaBuffer = m.lossDeltaBuffer |> RingBuffer.clear }
                            , if m.loopingShuffleActive then
                                shuffleAttractors ()

                              else
                                stopMachine ()
                            )

                        else
                            ( m, Cmd.none )
                   )

        AttractorsChanged data ->
            ( { model | attractors = convertParticleData data }, Cmd.none )

        StatisticChanged statistic ->
            ( { model | statistic = statistic }, Cmd.none )

        AddAttractors n ->
            ( model, addAttractors n )

        ShuffleAttractors ->
            ( model, Cmd.batch [ shuffleAttractors (), runMachine () ] )

        ToggleAttractorsVisible ->
            ( { model | attractorsVisible = not model.attractorsVisible }, Cmd.none )

        AddParticles n ->
            ( model, addParticles n )

        ShuffleParticles ->
            ( model, Cmd.batch [ shuffleParticles (), runMachine () ] )

        IncreaseLearningRate v ->
            ( model, increaseLearningRate v )

        ToggleLoopingShuffle ->
            { model | loopingShuffleActive = not model.loopingShuffleActive }
                |> (\m ->
                        ( m
                        , if m.loopingShuffleActive then
                            runMachine ()

                          else
                            Cmd.none
                        )
                   )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ optimizationStep OptimizationStep
        , attractorsChanged AttractorsChanged
        , statisticChanged StatisticChanged
        ]
