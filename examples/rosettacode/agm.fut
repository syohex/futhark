-- http://rosettacode.org/wiki/Arithmetic-geometric_mean
--
-- ==
-- input { 1.0f64 2.0f64 }
-- output { 1.456791f64 }

include futlib.numeric

fun agm(a: f64, g: f64): f64 =
  let eps = 1.0E-16
  loop ((a,g)) = while F64.abs(a-g) > eps do
    ((a+g) / 2.0,
     F64.sqrt (a*g))
  in a

fun main(x: f64, y: f64): f64 =
  agm(x,y)