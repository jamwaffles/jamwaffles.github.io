+++
layout = "post"
title = "Elm: counting groups of items in a list"
date = "2017-12-12 14:03:18"
categories = "elm"
image = "elm-tag-header.jpg"
+++

So. Elm. It's been an interesting experience for me, coming from a procedural language (JS)
background. The learning curve is steep, but the functional nature of Elm, along with its compile
time type safety really pays off. One of the (few!) problems I've found as a newcomer however, is
that the documentation can be really frustrating sometimes. In this post, I hope to remedy that
slightly by providing a newcomer's perspective on a little bit of data processing in Elm.

_Header photo by [@rawpixel](https://unsplash.com/photos/ndP5Oj0sSps)_

Let's say I've collected a list of tags from questions on StackOverflow. I want to create a unique
dictionary of tags and the number of times they occur in the dataset. To do that, we'll need to
process the data from a flat list into a `Dict` of key/value pairs. The key will be the name of the
tag, and the value will be the number of occurrences in the dataset.

## Starting at the beginning (whoa)

First, let's just render this `List` of tags:

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

Cool. We'll store that list in a `Model` to pass to some rendering layer:

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

This will store the list of tags under `model.tagList`, which we can use in the view to render a
(not so) pretty list:

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

The entire program so far is shown below. It's a pretty standard Elm boilerplate app. The most
interesting bits are described above; how we store the list, and how we present it.

<iframe src="https://ellie-app.com/embed/9vWnYkPqxa1/2" style="width:100%; height:400px; border:0; overflow:hidden;" sandbox="allow-modals allow-forms allow-popups allow-scripts allow-same-origin"></iframe>

Great, we've got a working Elm program. Next, I'll go into a bit of data processing to turn this
flat, boring list into a `Dict` of tags and counts.

## Dicts

As a first step towards grouping the data, we need to start using a `Dict`. Dicts contain unique
keys with an associated value. They're the same as `Map()`s in JavaScript. As a first step we'll
just render a list of unique tags to keep things understandable. The counts will come later.

First, the model type needs to change to use an Elm `Dict` for our list of tags:

```haskell
import Dict exposing (..)

type alias Model =
    { tagList : Dict String Int
    }
```

`tagList` is now of type `Dict String Int`, which is a map of `String` keys to `Int` values. This
will hold the `tag -> count` mapping.

We need to write a function to transform the list of tags when the model is initialised, so let's
write that:

```haskell
import Dict exposing (..)

-- ...

groupTags : List String -> Dict String Int
groupTags tags =
    tags
        |> List.foldr (\tag -> Dict.insert tag 0) Dict.empty
```

This function will `foldr` (`Array.reduce()` in JavaScript parlance) the tag list and create a
`Dict`. The keys will be the _unique_ list of tags from the input, while the values at the moment
will all be `0` for simplicity's sake.

The `|>` is some syntactic sugar. The above is the same as this:

```haskell
groupTags : List String -> Dict String Int
groupTags tags =
    List.foldr (\tag -> Dict.insert tag 0) Dict.empty tags
```

The `|>` operator "fills in" the last argument of `List.foldr` function with `tags`.

> A quick aside: in
> [the docs for `foldr`](http://package.elm-lang.org/packages/elm-lang/core/latest/List#foldr)
> you'll see a signature that looks like this:
>
> ```haskell
> foldr : (a -> b -> b) -> b -> List a -> b
> ```
>
> This is frustratingly obtuse for a beginner (or at least was for me), so let's rename the
> variables to make it a bit clearer:
>
> ```haskell
> foldr : (item -> carry -> carry result) -> initialValue -> inputList -> returnType
> ```
>
> The example in the docs is `foldr (+) 0 [1,2,3] == 6`. I found this pretty confusing, although
> it's wonderfully concise. Rewritten in longer form, it's a bit more understandable:
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

You can see that using the
[pipeline operator](http://package.elm-lang.org/packages/elm-lang/core/latest/Basics) makes things
much easier to read. Here's a demo:

<iframe src="https://ellie-app.com/embed/4HDDt9jpTa1/0" style="width:100%; height:400px; border:0; overflow:hidden;" sandbox="allow-modals allow-forms allow-popups allow-scripts allow-same-origin"></iframe>

# Counting keys

This Dict isn't very useful without some actual data in its keys. To fix that, we need to update
`groupTags` to actually count the number of occurrences instead of just setting each value to `0`.
Here's what it looks like:

```haskell
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
```

Instead of overwriting existing keys with `Dict.insert` as before, we're now using `Dict.update`
which takes three arguments:

- `tag` – they Dict key to search for
- `updateFunc` – how to update the Dict
- `dictToUpdate` – the starting `Dict` we want to update

It's important to note that `Dict.update` will _upsert_ a key; if it doesn't exist, it'll get
created. `Dict.update` returns a whole new `Dict`, with the updated/inserted key/value pair. This is
where the second argument (`updateFunc`) comes into play. It is supplied with one argument,
`existingCount`, which is a `Maybe` type. If there's no existing key, this will be `Nothing`,
otherwise you'll get `Just <dict value type>`. In our case, this would be `Just Int`. The `case`
statement will add one to an existing value, or insert a new key into the dict with a starting value
of `1`.

The last thing we need to do is update the view to render tag counts:

```haskell
import Tuple

-- ...

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
```

Unfortunately this is a bit involved, because `Dict.map` takes a `Dict`, therefore must return a
`Dict`. We want to return a `List` of `<li>` elements, so we can't directly use `Dict.map`. Argh.

So first we turn the Dict into a list of tuples with
[`Dict.tolist`](http://package.elm-lang.org/packages/elm-lang/core/latest/Dict#toList). The data now
looks like this:

```haskell
[ ( "elm", 2 )
, ( "javascript", 3 )
, ( "rust", 2 )
, ( "typescript", 1 )
]
```

Cool, now it's in a list so we can turn that into a bunch of `<li>` elements with `List.map`:

```haskell
List.map
    (\pair ->
        let
            tag =
                Tuple.first pair

            count =
                toString (Tuple.second pair)
        in
            li [] [ text (tag ++ ": " ++ count) ]
    )
```

Because this code is looping through a list of tuples, we need to use `Tuple.first` and
`Tuple.second` to extract the tag and count respectively. The last bit is to call `toString` on the
count to turn the `Int` into a `String`, ready for outputting in HTML.

Now we've got something that looks like this:

<iframe src="https://ellie-app.com/embed/shmTqNRBKa1/0" style="width:100%; height:400px; border:0; overflow:hidden;" sandbox="allow-modals allow-forms allow-popups allow-scripts allow-same-origin"></iframe>

And we're done! Well done if you made it down here.

## Wrapping up

Hopefully I've helped you understand a bit about how data processing (particularly with `Dict`s)
works in Elm with some practical code. During my Elm learning experience, I found there was a gap
between absolute beginner tutorials and more advanced stuff. Perhaps that's my procedural background
talking, or perhaps I just need to be smarter. Who knows, but either way the aim of this article was
to help bridge this gap. Let me know [on Twitter](https://twitter.com/jam_waffles) if there's
something I can do to improve this article, and as always, thanks for read'n.
