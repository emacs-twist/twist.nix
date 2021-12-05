pred:
with builtins;
let
  go = acc: items:
    if length items == 0
    then acc
    else if !(pred (head items))
    then acc
    else go (acc ++ [ (head items) ]) (tail items);
in
go [ ]
