module Basic exposing (..)

import Html exposing (..)
import PriceChart
import PriceChart.Types
import Svg exposing (..)


type Msg
    = PriceChartMsg PriceChart.Msg


type alias Model =
    { priceChart : PriceChart.Model }


initialModel : Model
initialModel =
    { priceChart = PriceChart.initialModel }


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
            PriceChart.Types.ElementRect 0 1000 0 300
    in
        div []
            [ svg [] [ PriceChart.priceChart model.priceChart screenRect |> Html.map PriceChartMsg ] ]


main =
    Html.program
        { init = ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = .priceChart >> PriceChart.subscriptions >> Sub.map PriceChartMsg
        }
