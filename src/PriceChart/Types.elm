module PriceChart.Types exposing (..)

{-| Types used in the price chart.


# Prices and actions

@docs Price, PriceAction, PriceHistory


# Price and action utilities

@docs minPrice, maxPrice, actionsByDate, mergeActions, mergeHistory


# Rendering

@docs ElementRect

-}

import Date
import Date.Extra
import List.Extra


{-| The price of a security
-}
type alias Price =
    Float


{-| The stats for a price's action over some span of time.
-}
type alias PriceAction =
    { startDate : Date.Date
    , endDate : Date.Date
    , close : Price
    , volume : Float
    , open : Price
    , high : Price
    , low : Price
    }


{-| A sequence of price actions, assumed to be in order from most recent to oldest.
-}
type alias PriceHistory =
    List PriceAction


{-| Get the lowest price in a history.
-}
minPrice : PriceHistory -> Maybe Price
minPrice =
    List.map .low
        >> List.minimum


{-| Get the hightest price in a history.
-}
maxPrice : PriceHistory -> Maybe Price
maxPrice =
    List.map .high
        >> List.maximum


{-| Retrieve PriceActions from a history that cover a certain date.
-}
actionsByDate : Date.Date -> PriceHistory -> PriceHistory
actionsByDate date =
    List.filter (\a -> Date.Extra.isBetween a.startDate a.endDate date)


{-| Merge two PriceActions into a single PriceAction that represents the full
interval of both.
-}
mergeActions : PriceAction -> PriceAction -> PriceAction
mergeActions a b =
    { startDate = a.startDate
    , endDate = b.endDate
    , open = a.open
    , close = b.close
    , volume = a.volume + b.volume
    , high = max a.high b.high
    , low = min a.low b.low
    }


{-| Merge all actions in a history into a single action
-}
mergeHistory : PriceHistory -> Maybe PriceAction
mergeHistory =
    List.Extra.foldl1 mergeActions


{-| The bounding rect of a DOM element
-}
type alias ElementRect =
    { left : Float
    , right : Float
    , top : Float
    , bottom : Float
    }
