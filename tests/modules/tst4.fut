-- A functor with a closure
-- ==
-- input {}
-- output { 26 }

module A = { type t = i32 val x : t = 3 }
module F (X : { val b : i32 }) : { type t = i32 val c : t } =
   { type t = i32 val c = A.x + X.b }

module C = {
  module A = { type t = f32 }
  module B = F( { val b = 23 } )
}

fun main() : i32 = C.B.c