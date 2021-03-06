{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE FlexibleInstances #-}
-- | Futhark prettyprinter.  This module defines 'Pretty' instances
-- for the AST defined in "Language.Futhark.Syntax".
module Language.Futhark.Pretty
  ( pretty
  , prettyTuple
  , leadingOperator
  )
where

import           Data.Array
import           Data.Functor
import           Data.Hashable
import           Data.List
import           Data.Maybe
import           Data.Monoid
import           Data.Ord
import           Data.Word

import           Prelude

import           Futhark.Util.Pretty

import           Language.Futhark.Syntax

-- | Given an operator name, return the operator that determines its
-- syntactical properties.
leadingOperator :: Name -> BinOp
leadingOperator s = maybe LogAnd snd $ find ((`isPrefixOf` s') . fst) $
                    sortBy (flip $ comparing $ length . fst) $
                    zip (map pretty operators) operators
  where s' = nameToString s
        operators :: [BinOp]
        operators = [minBound..maxBound::BinOp]

commastack :: [Doc] -> Doc
commastack = align . stack . punctuate comma

instance Pretty Value where
  ppr (PrimValue bv) = ppr bv
  ppr (TupValue vs)
    | any (not . primValue) vs =
      parens $ commastack $ map ppr vs
    | otherwise =
      parens $ commasep $ map ppr vs
    where primValue PrimValue{} = True
          primValue _           = False
  ppr (ArrayValue a t)
    | [] <- elems a = text "empty" <> parens (ppr t)
    | Array{} <- t = brackets $ commastack $ map ppr $ elems a
    | otherwise     = brackets $ commasep $ map ppr $ elems a

instance Pretty PrimType where
  ppr (Unsigned Int8)  = text "u8"
  ppr (Unsigned Int16) = text "u16"
  ppr (Unsigned Int32) = text "u32"
  ppr (Unsigned Int64) = text "u64"
  ppr (Signed t)       = ppr t
  ppr (FloatType t)    = ppr t
  ppr Bool             = text "bool"

instance Pretty PrimValue where
  ppr (UnsignedValue (Int8Value v)) =
    text (show (fromIntegral v::Word8)) <> text "u8"
  ppr (UnsignedValue (Int16Value v)) =
    text (show (fromIntegral v::Word16)) <> text "u16"
  ppr (UnsignedValue (Int32Value v)) =
    text (show (fromIntegral v::Word32)) <> text "u32"
  ppr (UnsignedValue (Int64Value v)) =
    text (show (fromIntegral v::Word64)) <> text "u64"
  ppr (SignedValue v) = ppr v
  ppr (BoolValue True) = text "true"
  ppr (BoolValue False) = text "false"
  ppr (FloatValue v) = ppr v

instance (Eq vn, Hashable vn, Pretty vn) =>
         Pretty (TupleArrayElemTypeBase (ShapeDecl vn) as) where
  ppr (PrimArrayElem bt _ u) = ppr u <> ppr bt
  ppr (PolyArrayElem bt _ u) = ppr u <> ppr (baseName <$> qualNameFromTypeName bt)
  ppr (ArrayArrayElem at)    = ppr at
  ppr (TupleArrayElem ts)    = parens $ commasep $ map ppr ts

instance Pretty (TupleArrayElemTypeBase Rank as) where
  ppr (PrimArrayElem bt _ u) = ppr u <> ppr bt
  ppr (PolyArrayElem bt _ u) = ppr u <> ppr (baseName <$> qualNameFromTypeName bt)
  ppr (ArrayArrayElem at)    = ppr at
  ppr (TupleArrayElem ts)    = parens $ commasep $ map ppr ts

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ArrayTypeBase (ShapeDecl vn) as) where
  ppr (PrimArray et (ShapeDecl ds) u _) =
    ppr u <> mconcat (map (brackets . f) ds) <> ppr et
    where f AnyDim       = mempty
          f (NamedDim v) = ppr v
          f (ConstDim n) = ppr n

  ppr (PolyArray et (ShapeDecl ds) u _) =
    ppr u <> mconcat (map (brackets . f) ds) <> ppr (baseName <$> qualNameFromTypeName et)
    where f AnyDim       = mempty
          f (NamedDim v) = ppr v
          f (ConstDim n) = ppr n

  ppr (TupleArray et (ShapeDecl ds) u) =
    ppr u <> mconcat (map (brackets . f) ds) <> parens (commasep $ map ppr et)
    where f AnyDim       = mempty
          f (NamedDim v) = ppr v
          f (ConstDim n) = ppr n

instance Pretty (ArrayTypeBase Rank as) where
  ppr (PrimArray et (Rank n) u _) =
    ppr u <> mconcat (replicate n (brackets mempty)) <> ppr et
  ppr (PolyArray et (Rank n) u _) =
    ppr u <> mconcat (replicate n (brackets mempty)) <> ppr (baseName <$> qualNameFromTypeName et)
  ppr (TupleArray ts (Rank n) u) =
    ppr u <> mconcat (replicate n (brackets mempty)) <>
    parens (commasep $ map ppr ts)

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (TypeBase (ShapeDecl vn) as) where
  ppr (Prim et)    = ppr et
  ppr (TypeVar et) = ppr $ baseName <$> qualNameFromTypeName et
  ppr (Array at)   = ppr at
  ppr (Tuple ts)   = parens $ commasep $ map ppr ts

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (TypeExp vn) where
  ppr (TEUnique t _) = text "*" <> ppr t
  ppr (TEArray at d _) = brackets (f d) <> ppr at
    where f AnyDim       = mempty
          f (NamedDim v) = ppr v
          f (ConstDim n) = ppr n
  ppr (TETuple ts _) = parens $ commasep $ map ppr ts
  ppr (TEVar name _) = ppr name

instance Pretty (TypeBase Rank as) where
  ppr (Prim et)    = ppr et
  ppr (TypeVar et) = ppr $ baseName <$> qualNameFromTypeName et
  ppr (Array at)   = ppr at
  ppr (Tuple ts)   = parens $ commasep $ map ppr ts

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (TypeDeclBase f vn) where
  ppr = ppr . declaredType

instance Pretty vn => Pretty (QualName vn) where
  ppr (QualName names name) =
    mconcat $ punctuate (text ".") $ map ppr names ++ [ppr name]

instance Pretty vn => Pretty (IdentBase f vn) where
  ppr = ppr . identName

instance Pretty BinOp where
  ppr Plus     = text "+"
  ppr Minus    = text "-"
  ppr Pow      = text "**"
  ppr Times    = text "*"
  ppr Divide   = text "/"
  ppr Mod      = text "%"
  ppr Quot     = text "//"
  ppr Rem      = text "%%"
  ppr ShiftR   = text ">>"
  ppr ZShiftR  = text ">>>"
  ppr ShiftL   = text "<<"
  ppr Band     = text "&"
  ppr Xor      = text "^"
  ppr Bor      = text "|"
  ppr LogAnd   = text "&&"
  ppr LogOr    = text "||"
  ppr Equal    = text "=="
  ppr NotEqual = text "!="
  ppr Less     = text "<"
  ppr Leq      = text "<="
  ppr Greater  = text ">"
  ppr Geq      = text ">="

hasArrayLit :: ExpBase ty vn -> Bool
hasArrayLit ArrayLit{}     = True
hasArrayLit (TupLit es2 _) = any hasArrayLit es2
hasArrayLit _              = False

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (DimIndexBase ty vn) where
  ppr (DimFix e)       = ppr e
  ppr (DimSlice i j s) = maybe mempty ppr i <> text ":" <>
                         maybe mempty ppr j <> text ":" <>
                         maybe mempty ppr s

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ExpBase ty vn) where
  ppr = pprPrec (-1)
  pprPrec _ (Var name _ _) = ppr name
  pprPrec _ (Literal v _) = ppr v
  pprPrec _ (TupLit es _)
    | any hasArrayLit es = parens $ commastack $ map ppr es
    | otherwise          = parens $ commasep $ map ppr es
  pprPrec _ (Empty (TypeDecl t _) _) =
    text "empty" <> parens (ppr t)
  pprPrec _ (ArrayLit es _ _) =
    brackets $ commasep $ map ppr es
  pprPrec p (BinOp bop (x,_) (y,_) _ _) = prettyBinOp p bop x y
  pprPrec _ (TupleProject k e _ _) = text "#" <> ppr k <+> pprPrec 9 e
  pprPrec _ (If c t f _ _) = text "if" <+> ppr c </>
                             text "then" <+> align (ppr t) </>
                             text "else" <+> align (ppr f)
  pprPrec _ (Apply fname args _ _) = ppr fname <>
                                     apply (map (align . ppr . fst) args)
  pprPrec _ (Negate e _) = text "-" <> ppr e
  pprPrec p (LetPat pat e body _) =
    mparens $ align $
    text "let" <+> align (ppr pat) <+>
    (if linebreak
     then equals </> indent 2 (ppr e)
     else equals <+> align (ppr e)) <+> text "in" </>
    ppr body
    where mparens = if p == -1 then id else parens
          linebreak = case e of
                        Map{}      -> True
                        Reduce{}   -> True
                        Filter{}   -> True
                        Scan{}     -> True
                        DoLoop{}   -> True
                        LetPat{}   -> True
                        LetWith{}  -> True
                        If{}       -> True
                        ArrayLit{} -> False
                        _          -> hasArrayLit e
  pprPrec _ (LetWith dest src idxs ve body _)
    | dest == src =
      text "let" <+> ppr dest <+> list (map ppr idxs) <+>
      equals <+> align (ppr ve) <+>
      text "in" </> ppr body
    | otherwise =
      text "let" <+> ppr dest <+> equals <+> ppr src <+>
      text "with" <+> brackets (commasep (map ppr idxs)) <+>
      text "<-" <+> align (ppr ve) <+>
      text "in" </> ppr body
  pprPrec _ (Index e idxs _) =
    pprPrec 9 e <> brackets (commasep (map ppr idxs))
  pprPrec _ (Iota e _) = text "iota" <> parens (ppr e)
  pprPrec _ (Shape e _) =
    text "shape" <> apply [ppr e]
  pprPrec _ (Replicate ne ve _) =
    text "replicate" <> apply [ppr ne, align (ppr ve)]
  pprPrec _ (Reshape shape e _) =
    text "reshape" <+> ppr shape <+> ppr e
  pprPrec _ (Rearrange perm e _) =
    text "rearrange" <> apply [apply (map ppr perm), ppr e]
  pprPrec _ (Transpose e _) =
    text "transpose" <> apply [ppr e]
  pprPrec _ (Rotate d x e _) =
    text "rotate@" <> ppr d <> apply [ppr x, ppr e]
  pprPrec _ (Map lam [a] _) = ppSOAC "map" [lam] [a]
  pprPrec _ (Map lam as _) = ppSOAC "zipWith" [lam] as
  pprPrec _ (Reduce Commutative lam e a _) = ppSOAC "reduceComm" [lam] [e, a]
  pprPrec _ (Reduce Noncommutative lam e a _) = ppSOAC "reduce" [lam] [e, a]
  pprPrec _ (Stream form lam arr _) =
    case form of
      MapLike o ->
        let ord_str = if o == Disorder then "Per" else ""
        in  text ("streamMap"++ord_str) <>
            parens ( ppList [lam] </> commasep [ppr arr] )
      RedLike o comm lam0 ->
        let ord_str = if o == Disorder then "Per" else ""
            comm_str = case comm of Commutative    -> "Comm"
                                    Noncommutative -> ""
        in  text ("streamRed"++ord_str++comm_str) <>
            parens ( ppList [lam0, lam] </> ppr arr )
      Sequential acc ->
            text "streamSeq" <>
            parens ( ppList [lam] </> commasep [ppr acc, ppr arr] )
  pprPrec _ (Scan lam e a _) = ppSOAC "scan" [lam] [e, a]
  pprPrec _ (Filter lam a _) = ppSOAC "filter" [lam] [a]
  pprPrec _ (Partition lams a _) = ppSOAC "partition" lams [a]
  pprPrec _ (Zip 0 e es _) = text "zip" <+> spread (map ppr (e:es))
  pprPrec _ (Zip i e es _) = text "zip@" <> ppr i <+> spread (map ppr (e:es))
  pprPrec _ (Unzip e _ _) = text "unzip" <> parens (ppr e)
  pprPrec _ (Unsafe e _) = text "unsafe" <+> pprPrec 9 e
  pprPrec _ (Split i e a _) =
    text "split@" <> ppr i <+> ppr e <+> ppr a
  pprPrec _ (Concat i x y _) =
    text "concat" <> text "@" <> ppr i <> apply [ppr x, ppr y]
  pprPrec _ (Copy e _) = text "copy" <> parens (ppr e)
  pprPrec _ (DoLoop pat initexp form loopbody letbody _) =
    text "loop" <+> parens (ppr pat <+> equals <+> ppr initexp) <+> equals <+>
    ppr form <+>
    text "do" </>
    indent 2 (ppr loopbody) <+> text "in" </>
    ppr letbody
  pprPrec _ (Write i v a _) = text "write" <> parens (commasep [ppr i, ppr v, ppr a])

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (LoopFormBase ty vn) where
  ppr (For FromUpTo lbound i ubound) =
    text "for" <+> align (ppr lbound) <+> ppr i <+> text "<" <+> align (ppr ubound)
  ppr (For FromDownTo lbound i ubound) =
    text "for" <+> align (ppr ubound) <+> ppr i <+> text ">" <+> align (ppr lbound)
  ppr (While cond) =
    text "while" <+> ppr cond

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (LowerBoundBase ty vn) where
  ppr ZeroBound    = text "0"
  ppr (ExpBound e) = ppr e

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (PatternBase ty vn) where
  ppr (PatternAscription p t) = ppr p <> text ":" <+> ppr t
  ppr (Id ident)              = ppr ident
  ppr (TuplePattern pats _)   = parens $ commasep $ map ppr pats
  ppr (Wildcard _ _)          = text "_"

ppAscription :: (Eq vn, Hashable vn, Pretty vn) => Maybe (TypeDeclBase ty vn) -> Doc
ppAscription Nothing  = mempty
ppAscription (Just t) = text ":" <> ppr t

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (LambdaBase ty vn) where
  ppr (CurryFun fname [] _ _) = text $ pretty fname
  ppr (CurryFun fname curryargs _ _) =
    ppr fname <+> apply (map ppr curryargs)
  ppr (AnonymFun params body ascript _ _) =
    text "fn" <+>
    apply (map ppParam params) <> ppAscription ascript <+>
    text "=>" </> indent 2 (ppr body)
  ppr (BinOpFun binop _ _ _ _) =
    ppr binop
  ppr (CurryBinOpLeft binop x _ _ _) =
    ppr x <+> ppr binop
  ppr (CurryBinOpRight binop x _ _ _) =
    ppr binop <+> ppr x

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ProgBase ty vn) where
  ppr = stack . punctuate line . map ppr . progDecs

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (DecBase ty vn) where
  ppr (ValDec dec)     = ppr dec
  ppr (TypeDec dec)    = ppr dec
  ppr (SigDec sig)     = ppr sig
  ppr (StructDec sd)   = ppr sd
  ppr (FunctorDec fd)  = ppr fd
  ppr (OpenDec x xs _) = text "open" <+> spread (map ppr (x:xs))

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ModExpBase ty vn) where
  ppr (ModVar v _) = ppr v
  ppr (ModImport v _) = ppr $ show v
  ppr (ModDecs ds _) = nestedBlock "{" "}" (stack $ punctuate line $ map ppr ds)
  ppr (ModApply f a _ _ _) = ppr f <> parens (ppr a)
  ppr (ModAscript me se _ _) = ppr me <> colon <+> ppr se

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (StructBindBase ty vn) where
  ppr (StructBind name e _) = text "module" <+> ppr name <+> equals <+> ppr e

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ValDecBase ty vn) where
  ppr (FunDec fun) = ppr fun
  ppr (ConstDec c) = ppr c

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (TypeBindBase ty vn) where
  ppr (TypeBind name usertype _) =
    text "type" <+> ppr name <+> equals <+> ppr usertype

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (FunBindBase ty vn) where
  ppr (FunBind entry name retdecl _ args body _) =
    text fun <+> ppr name <+>
    spread (map ppParam args) <> retdecl' <+> equals </>
    indent 2 (ppr body)
    where fun | entry     = "entry"
              | otherwise = "fun"
          retdecl' = case retdecl of
                       Just rettype -> text ":" <+> ppr rettype
                       Nothing      -> mempty

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (ConstBindBase ty vn) where
  ppr (ConstBind name maybe_t _ e _) =
    text "val" <+> ppr name <> t' <+> text "=" <+> ppr e
    where t' = case maybe_t of Just t  -> text ":" <+> ppr t
                               Nothing -> mempty

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (SpecBase ty vn) where
  ppr (TypeAbbrSpec tpsig) = ppr tpsig
  ppr (TypeSpec name _) = text "type" <+> ppr name
  ppr (ValSpec name params rettype _) =
    ppr name <+> colon <+>
    mconcat (map (\p -> ppr p <+> text "-> ") params) <+> ppr rettype
  ppr (IncludeSpec e _) =
    text "include" <+> ppr e

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (SigExpBase ty vn) where
  ppr (SigVar v _) = ppr v
  ppr (SigSpecs ss _) = nestedBlock "{" "}" (stack $ punctuate line $ map ppr ss)
  ppr (SigWith s (TypeRef v td) _) =
    ppr s <+> text "with" <+> ppr v <+> equals <+> ppr td

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (SigBindBase ty vn) where
  ppr (SigBind name e _) =
    text "module type" <+> ppr name <+> equals <+> ppr e

instance (Eq vn, Hashable vn, Pretty vn) => Pretty (FunctorBindBase ty vn) where
  ppr (FunctorBind name (pname,psig) sig e _) =
    text "module" <+> ppr name <>
    parens (ppr pname <> colon <+> ppr psig) <> sig' <+> equals <+> ppr e
    where sig' = case sig of Nothing -> mempty
                             Just s  -> colon <+> ppr s <> text " "

ppParam :: (Eq vn, Hashable vn, Pretty vn) => PatternBase t vn -> Doc
ppParam (Id param) = ppr param
ppParam p          = parens $ ppr p

prettyBinOp :: (Eq vn, Hashable vn, Pretty vn) =>
               Int -> QualName vn -> ExpBase ty vn -> ExpBase ty vn -> Doc
prettyBinOp p bop x y = parensIf (p > symPrecedence bop) $
                        pprPrec (symPrecedence bop) x <+/>
                        ppr bop <+>
                        pprPrec (symRPrecedence bop) y
  where symPrecedence = precedence . leadingOperator . nameFromString . pretty
        symRPrecedence = rprecedence . leadingOperator . nameFromString . pretty
        precedence LogAnd   = 0
        precedence LogOr    = 0
        precedence Band     = 1
        precedence Bor      = 1
        precedence Xor      = 1
        precedence Equal    = 2
        precedence NotEqual = 2
        precedence Less     = 2
        precedence Leq      = 2
        precedence Greater  = 2
        precedence Geq      = 2
        precedence ShiftL   = 3
        precedence ShiftR   = 3
        precedence ZShiftR  = 3
        precedence Plus     = 4
        precedence Minus    = 4
        precedence Times    = 5
        precedence Divide   = 5
        precedence Mod      = 5
        precedence Quot     = 5
        precedence Rem      = 5
        precedence Pow      = 6
        rprecedence Minus  = 10
        rprecedence Divide = 10
        rprecedence op     = precedence op

ppSOAC :: (Eq vn, Hashable vn, Pretty vn, Pretty fn) =>
          String -> [fn] -> [ExpBase ty vn] -> Doc
ppSOAC name funs es =
  text name <> parens (ppList funs </>
                       commasep (map ppr es))

ppList :: (Pretty a) => [a] -> Doc
ppList as = case map ppr as of
              []     -> empty
              a':as' -> foldl (</>) (a' <> comma) $ map (<> comma) as'
