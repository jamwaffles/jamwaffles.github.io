---
layout: post
title:  "Elm: counting groups of items in a list"
date:   2017-12-01 17:03:26
categories: elm
<!-- image: huanyang-header-2.jpg -->
---

So. Elm. It's been an interesting experience for me, coming from a procedural language background. The learning curve is steep, but the functional nature of Elm, along with its compile time type safety really pays off, especially for data handling. The only problem I've found as a newcomer however, is that the documentation can be really frustrating sometimes. In this post, I hope to remedy that slightly by providing a newcomer's perspective on a little bit of data processing in Elm.

Let's say I've collected a list of tags from questions on StackOverflow. I want to create a unique dictionary of tags and the number of times they occur in the dataset. To do that, we'll need to process the data from a flat list into a `Dict` of key/value pairs. The key will be the name of the tag, and the value will be the number of occurrences in the dataset.

First, let's just render the whole tag list. The data in my Elm program looks like the following `List`:

```elm
tagList = [ "elm", "javascript", "javascript", "rust", "elm", "rust", "javascript", "typescript" ]
```

Cool. Let's put that list into a `Model` that an Elm program can use:

```elm
import List

type alias Model =
    { tagList : List String
    }


init : ( Model, Cmd Msg )
init =
    ( { tagList =
            [ "elm"
            , "javascript"
            , "javascript"
            , "rust"
            , "elm"
            , "rust"
            , "javascript"
            , "typescript"
            ]
      }
    , Cmd.none
    )
```

This will store the list of tags under `model.tagList`, which we can use in the view to render a (not so) pretty list:

```elm
view : Model -> Html msg
view model =
    div []
        [ section []
            [ text "All the tags"
            , ul [] (List.map (\tag -> li [] [ text tag ]) model.tagList)
            ]
        ]
```

The entire program so far is shown below. It's a pretty standard Elm boilerplate app. The most interesting bits are described above; how we store the list, and how we present it.

<iframe src="https://ellie-app.com/embed/9vWnYkPqxa1/2" style="width:100%; height:400px; border:0; overflow:hidden;" sandbox="allow-modals allow-forms allow-popups allow-scripts allow-same-origin"></iframe>