module Basic exposing (..)

import Date
import DomInfo
import Html exposing (..)
import Html.Attributes exposing (..)
import PriceChart
import PriceChart.Types
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Tesla
import Window


type Msg
    = PriceChartMsg PriceChart.Msg
    | WindowResized Window.Size
    | ElementSize DomInfo.ElementSizeInfo


type alias Model =
    { priceChart : PriceChart.Model
    , chartRect : PriceChart.Types.ElementRect
    }


priceChartId : String
priceChartId =
    "price-chart"


initialModel : Model
initialModel =
    let
        pcm =
            PriceChart.initialModel

        date =
            List.reverse Tesla.tesla |> List.head |> Maybe.andThen (.startDate >> Just) |> Maybe.withDefault (Date.fromTime 0)
    in
        { priceChart = { pcm | prices = Tesla.tesla, startDate = date }
        , chartRect = PriceChart.Types.ElementRect 0 0 0 0
        }


update : Msg -> Model -> ( Model, Cmd.Cmd Msg )
update msg model =
    case msg of
        PriceChartMsg pcMsg ->
            let
                ( mdl, cmd ) =
                    PriceChart.update pcMsg model.priceChart
            in
                { model | priceChart = mdl } ! [ Cmd.map PriceChartMsg cmd ]

        WindowResized _ ->
            model ! [ DomInfo.requestSize priceChartId ]

        ElementSize { id, rect } ->
                if id == priceChartId then
                    { model | chartRect = rect } ! []
                else
                    model ! []


view : Model -> Html.Html Msg
view model =
    let
        { left, right, top, bottom } =
            model.chartRect

        vboxh =
            bottom - top

        vboxw =
            right - left

        vbox =
            viewBox <| String.join " " <| List.map toString [ 0, 0, vboxw, vboxh ]

        attrs =
            [ Svg.Attributes.preserveAspectRatio "none"
            , vbox
            , Html.Attributes.id priceChartId
            , attribute "width" "100%"
            , attribute "height" "1000px"
            ]
    in
        svg attrs [ PriceChart.priceChart model.priceChart model.chartRect |> Html.map PriceChartMsg ]


main =
    Html.program
        { init = ( initialModel, DomInfo.requestSize priceChartId )
        , view = view
        , update = update
        , subscriptions =
            \model ->
                Sub.batch
                    [ PriceChart.subscriptions model.priceChart |> Sub.map PriceChartMsg
                    , Window.resizes WindowResized
                    , DomInfo.elementSize ElementSize
                    ]
        }
