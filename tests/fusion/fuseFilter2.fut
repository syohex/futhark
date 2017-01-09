-- ==
-- input { [1,2,3,4] [5,6,7,8] }
-- output { 26 }
fun main(a: []int, b: []int): int =
  let (a2,b2) = unzip(filter (fn (x,y) => x < y) (zip a b)) in
  reduce (+) 0 b2