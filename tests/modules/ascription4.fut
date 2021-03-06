-- Ascription can happen anywhere in a module expression.
-- ==
-- input { 2 } output { [0,0] }

module type S = { val f: i32 -> []i32 }

module M = {
  fun f(x: i32): *[]i32 = replicate x 0
}: S

fun main(n: i32): []i32 = M.f n
