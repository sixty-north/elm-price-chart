port module DomInfo exposing (..)

import PriceChart.Types as Types

{-| The ID of a DOM element
-}
type alias ElementId =
    String


{-| Association between DOM ID and size
-}
type alias ElementSizeInfo =
    { id : ElementId
    , rect : Types.ElementRect
    }

{-| Port for requesting element sizes
-}
port requestSize : ElementId -> Cmd msg


{-| Port for receiving requested element sizes.
-}
port elementSize : (ElementSizeInfo -> msg) -> Sub msg
