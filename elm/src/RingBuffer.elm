module RingBuffer exposing (RingBuffer, clear, init, isFull, length, push, size, values)


type alias RingBuffer a =
    { size : Int
    , values : List a
    }


init : Int -> RingBuffer a
init s =
    { size = s
    , values = []
    }


size : RingBuffer a -> Int
size =
    .size


length : RingBuffer a -> Int
length =
    values >> List.length


values : RingBuffer a -> List a
values =
    .values


push : a -> RingBuffer a -> RingBuffer a
push value buffer =
    { buffer | values = (value :: buffer.values) |> List.take buffer.size }


clear : RingBuffer a -> RingBuffer a
clear buffer =
    { buffer | values = [] }


isFull : RingBuffer a -> Bool
isFull buffer =
    size buffer == length buffer
