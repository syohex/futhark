-- | A re-export of the prettyprinting library, along with a convenience function.
module Futhark.Util.Pretty
       ( module Text.PrettyPrint.Mainland
       , pretty
       , prettyDoc
       , prettyTuple

       , apply
       , oneLine
       )
       where

import Text.PrettyPrint.Mainland hiding (pretty)
import qualified Text.PrettyPrint.Mainland as PP

-- | Prettyprint a value, wrapped to 80 characters.
pretty :: Pretty a => a -> String
pretty = PP.pretty 80 . ppr

-- | Re-export of 'PP.pretty'.
prettyDoc :: Int -> Doc -> String
prettyDoc = PP.pretty

ppTuple' :: Pretty a => [a] -> Doc
ppTuple' ets = braces $ commasep $ map ppr ets

-- | Prettyprint a list enclosed in curly braces.
prettyTuple :: Pretty a => [a] -> String
prettyTuple = PP.pretty 80 . ppTuple'

-- | The document @'apply' ds@ separates @ds@ with commas and encloses them with
-- parentheses.
apply :: [Doc] -> Doc
apply = parens . commasep . map align

-- | Make sure that the given document is printed on just a single line.
oneLine :: PP.Doc -> PP.Doc
oneLine s = PP.text $ PP.displayS (PP.renderCompact s) ""