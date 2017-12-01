module Main exposing (..)

import Html exposing (..)
import List


-- Empty message type. Elm needs this for its update function
-- but we don't have any messages to update from


type Msg
    = NoOp



--Where we keep our app data


type alias Model =
    { tagList : List String
    }


init : Model
init =
    { tagList = [ "elm", "javascript", "javascript", "rust", "elm", "rust", "javascript", "typescript" ]
    }



-- Update has no events to subscribe to so this just returns the passed model
-- and the `Cmd.none` "don't do anything" command


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )



--Print the list!


view : Model -> Html msg
view model =
    div []
        [ section []
            [ text "Original list"
            , ul [] (List.map (\s tag -> li [] [ text tag ]) model.tagList)
            ]
        ]


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update

        -- No subscriptions – we don't have any interactions or events to respond to
        , subscriptions = \_ -> Sub.none
        }
