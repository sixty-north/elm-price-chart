module PriceChart exposing (initialModel, Model, Msg, priceChart, subscriptions, update)

import Date
import Date.Extra
import Draggable
import Json.Decode exposing (float)
import Json.Decode.Pipeline exposing (decode, required)
import List
import List.Extra exposing (groupWhile)
import PriceChart.Types as Types
import Svg exposing (Svg, rect, path, g, line, text, text_)
import Svg.Attributes exposing (..)
import Svg.Events exposing (on)
import Visualization.Axis as Axis
import Visualization.Scale as Scale


{-| Render a price chart. This returns an SVG element but not entire SVG; you
need to embed this into an SVG.
-}
priceChart : Model msg -> Types.ElementRect -> Svg msg
priceChart model screenRect =
    let
        ctx =
            context model screenRect

        xToMsg x y =
            Focus (mouseXToDate ctx x) (mouseYToPrice ctx y)
                |> SetFocus
                |> model.outMsg

        setFocusDecoder =
            decode xToMsg
                |> required "clientX" float
                |> required "clientY" float

        attrs =
            [ Draggable.mouseTrigger "price-chart" (DragMsg >> model.outMsg)
            , on "mousemove" setFocusDecoder
            , class "price-chart"
            ]

        opts =
            Axis.defaultOptions

        -- TODO: This transform is an interim guess. We should probably be
        -- basing it on: the maximum price in the scale's domain, font-size,
        -- etc.
        yAxis =
            g [ transform "translate(30, 0)" ]
                [ Axis.axis opts ctx.yScale ]

        xAxis =
            g [ transform "translate(0, 30)" ]
                [ Axis.axis { opts | orientation = Axis.Top } ctx.xScale ]

        shareInterval a1 a2 =
            Date.Extra.equalBy model.interval a1.startDate a2.startDate

        prices =
            model.prices
                |> groupWhile shareInterval
                |> List.map Types.mergeHistory
                |> List.filterMap identity
                |> List.filter (\p -> Date.Extra.compare p.startDate model.startDate /= LT)
    in
        g
            attrs
            [ Svg.rect [ width "100%", height "100%" ] []
            , g [] <| List.map (candlestick model ctx) prices
            , reticle model ctx
            , yAxis
            , xAxis
            ]


subscriptions : Model msg -> Sub.Sub msg
subscriptions model =
    Draggable.subscriptions (DragMsg >> model.outMsg) model.drag


type alias Position =
    { x : Float, y : Float }


type alias Focus =
    { date : Date.Date, price : Types.Price }


type Msg
    = OnDragBy Draggable.Delta
    | DragMsg Draggable.Msg
    | SetFocus Focus


dragConfig : Draggable.Config Msg
dragConfig =
    Draggable.basicConfig OnDragBy


type alias Model msg =
    { prices : Types.PriceHistory -- the prices to render
    , focus : Maybe Focus -- current focus of the reticle
    , startDate : Date.Date -- The "furthest left" date to display
    , interval : Date.Extra.Interval
    , candlestickWidth : Float -- the width of the candlestick body
    , candlestickPadding : Float -- space between candlesticks
    , outMsg :
        Msg
        -> msg -- wrapper for transporting our messages
    , position : Position -- last drag position
    , drag : Draggable.State -- required state for Draggable support
    }


{-| Create a default Model instance.
-}
initialModel : (Msg -> msg) -> Model msg
initialModel outMsg =
    { prices = []
    , focus = Nothing
    , startDate = Date.fromTime 0
    , interval = Date.Extra.Day
    , candlestickWidth = 5
    , candlestickPadding = 1
    , outMsg = outMsg
    , position = Position 0.0 0.0
    , drag = Draggable.init
    }


update : Msg -> Model msg -> ( Model msg, Cmd.Cmd msg )
update msg model =
    case msg of
        OnDragBy ( dx, dy ) ->
            let
                posx =
                    model.position.x

                posy =
                    model.position.y

                width =
                    model.candlestickWidth + model.candlestickPadding

                inc =
                    -1 * dx / width |> round

                newDate =
                    Date.Extra.add Date.Extra.Day inc model.startDate
            in
                { model | position = Position (posx + dx) (posy + dy), startDate = newDate } ! []

        DragMsg dragMsg ->
            let
                ( mdl, cmd ) =
                    Draggable.update dragConfig dragMsg model
            in
                ( mdl, Cmd.map model.outMsg cmd )

        SetFocus focus ->
            { model | focus = Just focus } ! []


{-| The rendering context. This comprises the set of scales necessary for
properly rendering the chart.
-}
type alias Context =
    { xScale : Scale.ContinuousTimeScale -- date-to-x scale
    , yScale : Scale.ContinuousScale -- price-to-y scale
    , mouseXScale : Scale.ContinuousScale -- absolute screen x-coordinates to viewport scale
    , mouseYScale : Scale.ContinuousScale -- absolute screen y-coordinates to viewport scale
    }


{-| Create a rendering context from the current model and window extents.
-}
context : Model msg -> Types.ElementRect -> Context
context model screenRect =
    let
        minPrice =
            Types.minPrice model.prices |> Maybe.withDefault 0

        maxPrice =
            Types.maxPrice model.prices |> Maybe.withDefault 0

        diff =
            maxPrice - minPrice

        padding =
            diff * 0.05

        renderWidth =
            screenRect.right - screenRect.left

        renderHeight =
            screenRect.bottom - screenRect.top

        numCandlesticks =
            renderWidth / (model.candlestickWidth + model.candlestickPadding) |> floor

        maxDate =
            Date.Extra.add Date.Extra.Day numCandlesticks model.startDate

        height =
            screenRect.bottom - screenRect.top
    in
        { xScale =
            Scale.time ( model.startDate, maxDate ) ( 0, renderWidth )
        , yScale =
            Scale.linear ( minPrice - padding, maxPrice + padding ) ( height, 0 )
        , mouseXScale =
            Scale.linear ( screenRect.left, screenRect.right ) ( 0, renderWidth )
        , mouseYScale =
            Scale.linear ( screenRect.top, screenRect.bottom ) ( 0, renderHeight )
        }


{-| Draw an SVG line.

This is just a convenience function that takes care or stringifying your float
values.

-}
line : Float -> Float -> Float -> Float -> Svg.Svg msg
line x1 y1 x2 y2 =
    -- TODO This should probably be in a separate module of similar convenience functions.
    Svg.line
        [ Svg.Attributes.x1 <| toString x1
        , Svg.Attributes.y1 <| toString y1
        , Svg.Attributes.x2 <| toString x2
        , Svg.Attributes.y2 <| toString y2
        ]
        []


{-| Draw an SVG rectangle.
-}
rect : Float -> Float -> Float -> Float -> Svg.Svg msg
rect x y width height =
    Svg.rect
        [ Svg.Attributes.x <| toString x
        , Svg.Attributes.y <| toString y
        , Svg.Attributes.width <| toString width
        , Svg.Attributes.height <| toString height
        ]
        []


{-| Render a single candlestick.
-}
candlestick : Model msg -> Context -> Types.PriceAction -> Svg msg
candlestick model ctx action =
    let
        xmid =
            Scale.convert ctx.xScale action.startDate

        x =
            xmid - (model.candlestickWidth / 2)

        ylow =
            Scale.convert ctx.yScale action.low

        yhigh =
            Scale.convert ctx.yScale action.high

        yopen =
            Scale.convert ctx.yScale action.open

        yclose =
            Scale.convert ctx.yScale action.close

        boxBottom =
            Basics.max yopen yclose

        boxTop =
            Basics.min yopen yclose

        changeClass =
            if action.open > action.close then
                "price-chart-inc"
            else
                "price-chart-dec"

        lines =
            g [ class "candlestick-wick" ]
                [ line xmid ylow xmid yhigh ]

        body =
            g [ class "candlestick-body" ]
                [ rect x boxTop model.candlestickWidth (boxBottom - boxTop)
                ]
    in
        g [ class <| String.join " " [ "candlestick", changeClass ] ] [ lines, body ]


{-| Draw a reticle at the current date/price coordinate.
-}
reticle : Model msg -> Context -> Svg msg
reticle model ctx =
    let
        makeReticle focus =
            let
                dateX =
                    Scale.convert ctx.xScale focus.date
                        |> toString

                priceY =
                    Scale.convert ctx.yScale focus.price
                        |> toString
            in
                g [ class "reticle" ]
                    [ Svg.line [ class "reticle-horizontal", x1 dateX, x2 dateX, y1 "0", y2 "100%" ] []
                    , Svg.line [ class "reticle-vertical", x1 "0", x2 "100%", y1 priceY, y2 priceY ] []
                    ]
    in
        model.focus
            |> Maybe.andThen (makeReticle >> Just)
            |> Maybe.withDefault (g [] [])


{-| Convert mouse-position x-coordinate into a Date.
-}
mouseXToDate : Context -> Float -> Date.Date
mouseXToDate ctx =
    Scale.convert ctx.mouseXScale
        >> Scale.invert ctx.xScale
        >> Date.Extra.floor Date.Extra.Day


{-| Convert a mouse-position y-coordiante into a price.
-}
mouseYToPrice : Context -> Float -> Types.Price
mouseYToPrice ctx =
    Scale.convert ctx.mouseYScale
        >> Scale.invert ctx.yScale
