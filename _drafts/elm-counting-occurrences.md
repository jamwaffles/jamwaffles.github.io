---
layout: post
title:  "Elm: counting groups of items in a list"
date:   2017-12-01 17:03:26
categories: elm
image: elm-tag-header.jpg
---

So. Elm. It's been an interesting experience for me, coming from a procedural language background. The learning curve is steep, but the functional nature of Elm, along with its compile time type safety really pays off, especially for data handling. The only problem I've found as a newcomer however, is that the documentation can be really frustrating sometimes. In this post, I hope to remedy that slightly by providing a newcomer's perspective on a little bit of data processing in Elm.

_Header photo by [@rawpixel](https://unsplash.com/photos/ndP5Oj0sSps)_

Let's say I've collected a list of tags from questions on StackOverflow. I want to create a unique dictionary of tags and the number of times they occur in the dataset. To do that, we'll need to process the data from a flat list into a `Dict` of key/value pairs. The key will be the name of the tag, and the value will be the number of occurrences in the dataset.

## Starting at the beginning (whoa)

First, let's just render the whole tag list. The data in my Elm program looks like the following `List`:

```haskell
tagList =
    [ "elm"
    , "javascript"
    , "javascript"
    , "rust"
    , "elm"
    , "rust"
    , "javascript"
    , "typescript"
    ]
```

Cool. Let's put that list into a `Model` that an Elm program can use:

```haskell
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

```haskell
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

Great, we've got a working Elm program. Next, I'll go into a bit of data processing to turn this flat list into a `Dict` of tags and counts.

## Dicts

As a first step towards grouping the data, we need to start using a `Dict`. Dicts contain unique keys with an associated value. They're the same as `Map()`s in JavaScript. To keep things (hipefully) understandable, as a first step we'll just render a list of unique tags.

First, the model type needs to change to use an Elm `Dict` for our list of tags:

```haskell
import Dict exposing (..)

type alias Model =
    { tagList : Dict String Int
    }
```

Here, `tagList` is now of type `Dict String Int`, which is a map of `String` keys to `Int` values. This will hold our `tag -> count` mapping.

We need to write a function to transform the list of tags when the model is initalised, so let's write that:

```haskell
import Dict exposing (..)

-- ...

groupTags : List String -> Dict String Int
groupTags tags =
    tags
        |> List.foldr (\tag -> Dict.insert tag 0) Dict.empty
```

This function will `foldr` (`Array.reduce()` in JavaScript parlance) the tag list and create a `Dict`. The keys will be the _unique_ list of tags from the input, while the values at the moment will all be `0` for simplicity's sake.

The `|>` is some syntactic sugar. The above is the same as this:

```haskell
groupTags : List String -> Dict String Int
groupTags tags =
    List.foldr (\tag -> Dict.insert tag 0) Dict.empty tags
```

The `|>` operator "fills in" the last argument of `List.foldr` function with `tags`.

> A quick aside: in [the docs for `foldr`](http://package.elm-lang.org/packages/elm-lang/core/latest/List#foldr) you'll see a signature that looks like this:
>
> ```haskell
> foldr : (a -> b -> b) -> b -> List a -> b
> ```
>
> This is frustratingly obtuse for a beginnger (or at least was for me), so let's rename the variables to make it a bit clearer:
>
> ```haskell
> foldr : (item -> carry -> carry result) -> initialValue -> inputList -> returnType
> ```
>
The example in the docs is `foldr (+) 0 [1,2,3] == 6`. I found this pretty confusing, although it's wonderfully concise. Rewritten in longer form, it's a > bit more understandable for the purpose of more complex use:
>
> ```haskell
> foldr (\item carry -> carry + item) 0 [1,2,3] == 6
> ```
>
> Hope that helps!

Anyway, now we can initialise the model:

```haskell
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
```

Finally, we can change our render method slightly:

```haskell
view : Model -> Html msg
view model =
    div []
        [ section []
            [ text "My tag list"
            , ul []
                (model.tagList
                    |> Dict.keys
                    |> List.map (\tag -> li [] [ text tag ])
                )
            ]
        ]
```

Again, the `|>` could be written like this:

```haskell
(List.map (\tag -> li [] [ text tag ] (Dict.keys model.tagList)))
```

You can see that using the [pipeline operator](http://package.elm-lang.org/packages/elm-lang/core/latest/Basics) makes things much easier to read. The complete program now looks like this:

<iframe src="https://ellie-app.com/embed/4HDDt9jpTa1/0" style="width:100%; height:400px; border:0; overflow:hidden;" sandbox="allow-modals allow-forms allow-popups allow-scripts allow-same-origin"></iframe>
