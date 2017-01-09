-- Reduction with an array accumulator, where the compiler (probably)
-- cannot do a interchange.
--
-- ==
-- input { [[1,2,3], [4,5,6], [6,7,8]] }
-- output { [11i32, 14i32, 17i32] }

fun main(xss: [n][m]int): []int =
  reduceComm(fn xs ys:[]int =>
               loop (zs = replicate m 0) = for i < m do
                 let zs[i] = xs[i] + ys[i]
                 in zs
               in zs)
             (replicate m 0) xss