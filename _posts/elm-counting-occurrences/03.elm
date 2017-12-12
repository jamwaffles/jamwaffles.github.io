module Main exposing (..)

import Html exposing (..)
import List
import Dict exposing (..)
import Tuple


--Where we keep our app data


type alias Model =
    { tagList : Dict String Int
    }


groupTags : List String -> Dict String Int
groupTags tags =
    tags
        |> List.foldr
            (\tag carry ->
                Dict.update
                    tag
                    (\existingCount ->
                        case existingCount of
                            Just existingCount ->
                                Just (existingCount + 1)

                            Nothing ->
                                Just 1
                    )
                    carry
            )
            Dict.empty


init : ( Model, Cmd Msg )
init =
    ( { tagList =
            (groupTags
                [ "elm"
                , "javascript"
                , "javascript"
                , "rust"
                , "elm"
                , "rust"
                , "javascript"
                , "typescript"
                ]
            )
      }
    , Cmd.none
    )



--Print the list!


view : Model -> Html msg
view model =
    div []
        [ section []
            [ text "My tag list"
            , ul []
                (model.tagList
                    |> Dict.toList
                    |> List.map
                        (\pair ->
                            let
                                tag =
                                    Tuple.first pair

                                count =
                                    toString (Tuple.second pair)
                            in
                                li [] [ text (tag ++ ": " ++ count) ]
                        )
                )
            ]
        ]



-- Empty message type. Elm needs this for its update function
-- but we don't have any messages to update from


type Msg
    = NoOp



-- Update has no events to subscribe to so this just
-- returns the passed model and the `Cmd.none`
-- "don't do anything" command


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )



-- Placeholder function for subscriptions (e.g. websockets)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
