module Basic exposing (..)

import Date
import Html exposing (..)
import Html.Attributes exposing (..)
import PriceChart
import PriceChart.Types
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Tesla


type Msg
    = PriceChartMsg PriceChart.Msg


type alias Model =
    { priceChart : PriceChart.Model }


initialModel : Model
initialModel =
    let
        pcm = PriceChart.initialModel
        date = List.reverse Tesla.tesla |> List.head |> Maybe.andThen (.startDate >> Just) |> Maybe.withDefault (Date.fromTime 0)
        x = Debug.log "prices: " Tesla.tesla
        y = Debug.log "date: " date
    in
        { priceChart = {pcm | prices = Tesla.tesla, startDate = date}}


update : Msg -> Model -> ( Model, Cmd.Cmd Msg )
update msg model =
    case msg of
        PriceChartMsg pcMsg ->
            let
                ( mdl, cmd ) =
                    PriceChart.update pcMsg model.priceChart
            in
                { model | priceChart = mdl } ! [ Cmd.map PriceChartMsg cmd ]

view : Model -> Html.Html Msg
view model =
    let
        -- This is a guess and almost certainly wrong!!!
        screenRect =
            PriceChart.Types.ElementRect 0 1000 0 400
    in
        div [Html.Attributes.width 1000, Html.Attributes.height 400]
            [ svg [viewBox "0 0 1000 400" ] [ PriceChart.priceChart model.priceChart screenRect |> Html.map PriceChartMsg ] ]


main =
    Html.program
        { init = ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = .priceChart >> PriceChart.subscriptions >> Sub.map PriceChartMsg
        }
