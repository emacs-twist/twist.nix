pred:
with builtins;
let
  go = items:
    if length items == 0
    then [ ]
    else if ! (pred (head items))
    then items
    else go (tail items);
in
go
