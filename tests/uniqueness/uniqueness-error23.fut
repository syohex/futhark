-- ==
-- error: .*consumed.*
fun f(ar: *[]int, a: *[][]int): int =
  f(a[0], a) -- Should be a type error, as both are supposed to be unique

fun main(n: int): int =
  let a = copy(replicate n (iota n))
  let ar = copy(a[0]) in
  f(ar, a)