{-# LANGUAGE FlexibleContexts, FlexibleInstances, TypeSynonymInstances #-}
-- | Functions for inspecting and constructing various types.
module Futhark.Representation.AST.Attributes.Types
       (
         rankShaped
       , extShaped
       , arrayRank
       , arrayShape
       , modifyArrayShape
       , setArrayShape
       , existential
       , uniqueness
       , setUniqueness
       , unifyUniqueness
       , unique
       , staticShapes
       , staticShapes1
       , primType

       , arrayOf
       , arrayOfRow
       , arrayOfShape
       , setOuterSize
       , setDimSize
       , setOuterDim
       , setDim
       , setArrayDims
       , peelArray
       , stripArray
       , arrayDims
       , shapeSize
       , arraySize
       , arraysSize
       , rowType
       , elemType

       , transposeType
       , rearrangeType

       , diet

       , subtypeOf
       , subtypesOf

       , toDecl
       , fromDecl

       , extractShapeContext
       , shapeContext
       , shapeContextSize
       , hasStaticShape
       , hasStaticShapes
       , generaliseExtTypes
       , existentialiseExtTypes
       , shapeMapping
       , shapeMapping'

         -- * Abbreviations
       , int8, int16, int32, int64
       , float32, float64

         -- * The Typed typeclass
       , Typed (..)
       , DeclTyped (..)
       , SetType (..)
       )
       where

import Control.Applicative
import Control.Monad.State
import Data.Maybe
import Data.Monoid
import qualified Data.HashSet as HS
import qualified Data.HashMap.Lazy as HM

import Prelude

import Futhark.Representation.AST.Syntax.Core
import Futhark.Representation.AST.Attributes.Constants
import Futhark.Representation.AST.Attributes.Rearrange

-- | Remove shape information from a type.
rankShaped :: ArrayShape shape => TypeBase shape u -> TypeBase Rank u
rankShaped (Array et sz u) = Array et (Rank $ shapeRank sz) u
rankShaped (Prim et) = Prim et
rankShaped (Mem size space) = Mem size space

-- | Add vacuous existential type information to a type.  Every
-- dimension will be its own 'Ext'.
extShaped :: ArrayShape shape => TypeBase shape u -> TypeBase ExtShape u
extShaped (Array et sz u) = Array et (ExtShape $ map Ext [0..shapeRank sz-1]) u
extShaped (Prim et) = Prim et
extShaped (Mem size space) = Mem size space

-- | Return the dimensionality of a type.  For non-arrays, this is
-- zero.  For a one-dimensional array it is one, for a two-dimensional
-- it is two, and so forth.
arrayRank :: ArrayShape shape => TypeBase shape u -> Int
arrayRank = shapeRank . arrayShape

-- | Return the shape of a type - for non-arrays, this is the
-- 'mempty'.
arrayShape :: ArrayShape shape => TypeBase shape u -> shape
arrayShape (Array _ ds _) = ds
arrayShape _              = mempty

-- | Modify the shape of an array - for non-arrays, this does nothing.
modifyArrayShape :: ArrayShape newshape =>
                    (oldshape -> newshape)
                 -> TypeBase oldshape u
                 -> TypeBase newshape u
modifyArrayShape f (Array t ds u)
  | shapeRank ds' == 0 = Prim t
  | otherwise          = Array t (f ds) u
  where ds' = f ds
modifyArrayShape _ (Prim t)        = Prim t
modifyArrayShape _ (Mem size space) = Mem size space

-- | Set the shape of an array.  If the given type is not an
-- array, return the type unchanged.
setArrayShape :: ArrayShape newshape =>
                 TypeBase oldshape u
              -> newshape
              -> TypeBase newshape u
setArrayShape t ds = modifyArrayShape (const ds) t

-- | True if the given type has a dimension that is existentially sized.
existential :: ExtType -> Bool
existential = any ext . extShapeDims . arrayShape
  where ext (Ext _)  = True
        ext (Free _) = False

-- | Return the uniqueness of a type.
uniqueness :: TypeBase shape Uniqueness -> Uniqueness
uniqueness (Array _ _ u) = u
uniqueness _ = Nonunique

-- | @unique t@ is 'True' if the type of the argument is unique.
unique :: TypeBase shape Uniqueness -> Bool
unique = (==Unique) . uniqueness

-- | Set the uniqueness attribute of a type.
setUniqueness :: TypeBase shape Uniqueness
              -> Uniqueness
              -> TypeBase shape Uniqueness
setUniqueness (Array et dims _) u = Array et dims u
setUniqueness t _ = t

-- | Unify the uniqueness attributes and aliasing information of two
-- types.  The two types must otherwise be identical.  The resulting
-- alias set will be the 'mappend' of the two input types aliasing sets,
-- and the uniqueness will be 'Unique' only if both of the input types
-- are unique.
unifyUniqueness :: Monoid u =>
                   TypeBase shape u
                -> TypeBase shape u
                -> TypeBase shape u
unifyUniqueness (Array et dims u1) (Array _ _ u2) =
  Array et dims (u1 <> u2)
unifyUniqueness t1 _ = t1

-- | Convert types with non-existential shapes to types with
-- non-existential shapes.  Only the representation is changed, so all
-- the shapes will be 'Free'.
staticShapes :: [TypeBase Shape u] -> [TypeBase ExtShape u]
staticShapes = map staticShapes1

-- | As 'staticShapes', but on a single type.
staticShapes1 :: TypeBase Shape u -> TypeBase ExtShape u
staticShapes1 (Prim bt) =
  Prim bt
staticShapes1 (Array bt (Shape shape) u) =
  Array bt (ExtShape $ map Free shape) u
staticShapes1 (Mem size space) =
  Mem size space

-- | @arrayOf t s u@ constructs an array type.  The convenience
-- compared to using the 'Array' constructor directly is that @t@ can
-- itself be an array.  If @t@ is an @n@-dimensional array, and @s@ is
-- a list of length @n@, the resulting type is of an @n+m@ dimensions.
-- The uniqueness of the new array will be @u@, no matter the
-- uniqueness of @t@.  If the shape @s@ has rank 0, then the @t@ will
-- be returned, although if it is an array, with the uniqueness
-- changed to @u@.
arrayOf :: ArrayShape shape =>
           TypeBase shape u_unused -> shape -> u -> TypeBase shape u
arrayOf (Array et size1 _) size2 u =
  Array et (size2 <> size1) u
arrayOf (Prim et) s _
  | 0 <- shapeRank s = Prim et
arrayOf (Prim et) size u =
  Array et size u
arrayOf Mem{} _ _ =
  error "arrayOf Mem"

-- | Construct an array whose rows are the given type, and the outer
-- size is the given 'SubExp'.  This is just a convenient wrapper
-- around 'arrayOf'.
arrayOfRow :: Type -> SubExp -> Type
arrayOfRow t size = arrayOf t (Shape [size]) NoUniqueness

-- | Construct an array whose rows are the given type, and the outer
-- size is the given 'Shape'.  This is just a convenient wrapper
-- around 'arrayOf'.
arrayOfShape :: Type -> Shape -> Type
arrayOfShape t shape = arrayOf t shape NoUniqueness

-- | Set the dimensions of an array.  If the given type is not an
-- array, return the type unchanged.
setArrayDims :: TypeBase oldshape u -> [SubExp] -> TypeBase Shape u
setArrayDims t dims = t `setArrayShape` Shape dims

-- | Replace the size of the outermost dimension of an array.  If the
-- given type is not an array, it is returned unchanged.
setOuterSize :: TypeBase Shape u -> SubExp -> TypeBase Shape u
setOuterSize = setDimSize 0

-- | Replace the size of the given dimension of an array.  If the
-- given type is not an array, it is returned unchanged.
setDimSize :: Int -> TypeBase Shape u -> SubExp -> TypeBase Shape u
setDimSize i t e = t `setArrayShape` setDim i (arrayShape t) e

-- | Replace the outermost dimension of an array shape.
setOuterDim :: Shape -> SubExp -> Shape
setOuterDim = setDim 0

-- | Replace the specified dimension of an array shape.
setDim :: Int -> Shape -> SubExp -> Shape
setDim i (Shape ds) e = Shape $ take i ds ++ e : drop (i+1) ds

-- | @peelArray n t@ returns the type resulting from peeling the first
-- @n@ array dimensions from @t@.  Returns @Nothing@ if @t@ has less
-- than @n@ dimensions.
peelArray :: ArrayShape shape =>
             Int -> TypeBase shape u -> Maybe (TypeBase shape u)
peelArray 0 t = Just t
peelArray n (Array et shape u)
  | shapeRank shape == n = Just $ Prim et
  | shapeRank shape >  n = Just $ Array et (stripDims n shape) u
peelArray _ _ = Nothing

-- | @stripArray n t@ removes the @n@ outermost layers of the array.
-- Essentially, it is the type of indexing an array of type @t@ with
-- @n@ indexes.
stripArray :: ArrayShape shape => Int -> TypeBase shape u -> TypeBase shape u
stripArray n (Array et shape u)
  | n < shapeRank shape = Array et (stripDims n shape) u
  | otherwise           = Prim et
stripArray _ t = t

-- | Return the size of the given dimension.  If the dimension does
-- not exist, the zero constant is returned.
shapeSize :: Int -> Shape -> SubExp
shapeSize i shape = case drop i $ shapeDims shape of
  e : _ -> e
  []    -> constant (0 :: Int32)

-- | Return the dimensions of a type - for non-arrays, this is the
-- empty list.
arrayDims :: TypeBase Shape u -> [SubExp]
arrayDims = shapeDims . arrayShape

-- | Return the size of the given dimension.  If the dimension does
-- not exist, the zero constant is returned.
arraySize :: Int -> TypeBase Shape u -> SubExp
arraySize i = shapeSize i . arrayShape

-- | Return the size of the given dimension in the first element of
-- the given type list.  If the dimension does not exist, or no types
-- are given, the zero constant is returned.
arraysSize :: Int -> [TypeBase Shape u] -> SubExp
arraysSize _ []    = constant (0 :: Int32)
arraysSize i (t:_) = arraySize i t

-- | Return the immediate row-type of an array.  For @[[int]]@, this
-- would be @[int]@.
rowType :: ArrayShape shape => TypeBase shape u -> TypeBase shape u
rowType = stripArray 1

-- | A type is a primitive type if it is not an array or memory block.
primType :: TypeBase shape u -> Bool
primType Array{} = False
primType Mem{} = False
primType _ = True

-- | Returns the bottommost type of an array.  For @[[int]]@, this
-- would be @int@.  If the given type is not an array, it is returned.
elemType :: TypeBase shape u -> PrimType
elemType (Array t _ _) = t
elemType (Prim t)     = t
elemType Mem{}      = error "elemType Mem"

-- | Swap the two outer dimensions of the type.
transposeType :: Type -> Type
transposeType = rearrangeType [1,0]

-- | Rearrange the dimensions of the type.  If the length of the
-- permutation does not match the rank of the type, the permutation
-- will be extended with identity.
rearrangeType :: [Int] -> Type -> Type
rearrangeType perm t =
  t `setArrayShape` Shape (rearrangeShape perm' $ arrayDims t)
  where perm' = perm ++ [length perm .. arrayRank t - 1]

-- | @diet t@ returns a description of how a function parameter of
-- type @t@ might consume its argument.
diet :: TypeBase shape Uniqueness -> Diet
diet (Prim _) = Observe
diet (Array _ _ Unique) = Consume
diet (Array _ _ Nonunique) = Observe
diet Mem{} = Observe

-- | @x \`subtypeOf\` y@ is true if @x@ is a subtype of @y@ (or equal to
-- @y@), meaning @x@ is valid whenever @y@ is.
subtypeOf :: (Ord u, ArrayShape shape) =>
             TypeBase shape u
          -> TypeBase shape u
          -> Bool
subtypeOf (Array t1 shape1 u1) (Array t2 shape2 u2) =
  u2 <= u1 &&
  t1 == t2 &&
  shape1 `subShapeOf` shape2
subtypeOf (Prim t1) (Prim t2) = t1 == t2
subtypeOf (Mem _ space1) (Mem _ space2) = space1 == space2
subtypeOf _ _ = False

-- | @xs \`subtypesOf\` ys@ is true if @xs@ is the same size as @ys@,
-- and each element in @xs@ is a subtype of the corresponding element
-- in @ys@..
subtypesOf :: (Ord u, ArrayShape shape) =>
              [TypeBase shape u]
           -> [TypeBase shape u]
           -> Bool
subtypesOf xs ys = length xs == length ys &&
                   and (zipWith subtypeOf xs ys)

toDecl :: TypeBase shape NoUniqueness
       -> Uniqueness
       -> TypeBase shape Uniqueness
toDecl (Prim bt) _ = Prim bt
toDecl (Array et shape _) u = Array et shape u
toDecl (Mem size space) _ = Mem size space

fromDecl :: TypeBase shape Uniqueness
         -> TypeBase shape NoUniqueness
fromDecl (Prim bt) = Prim bt
fromDecl (Array et shape _) = Array et shape NoUniqueness
fromDecl (Mem size space) = Mem size space

-- | Given the existential return type of a function, and the shapes
-- of the values returned by the function, return the existential
-- shape context.  That is, those sizes that are existential in the
-- return type.
extractShapeContext :: [TypeBase ExtShape u] -> [[a]] -> [a]
extractShapeContext ts shapes =
  evalState (concat <$> zipWithM extract ts shapes) HS.empty
  where extract t shape =
          catMaybes <$> zipWithM extract' (extShapeDims $ arrayShape t) shape
        extract' (Ext x) v = do
          seen <- gets $ HS.member x
          if seen then return Nothing
            else do modify $ HS.insert x
                    return $ Just v
        extract' (Free _) _ = return Nothing

-- | The set of identifiers used for the shape context in the given
-- 'ExtType's.
shapeContext :: [TypeBase ExtShape u] -> HS.HashSet Int
shapeContext = HS.fromList
               . concatMap (mapMaybe ext . extShapeDims . arrayShape)
  where ext (Ext x)  = Just x
        ext (Free _) = Nothing

-- | The size of the set that would be returned by 'shapeContext'.
shapeContextSize :: [ExtType] -> Int
shapeContextSize = HS.size . shapeContext

-- | If all dimensions of the given 'RetType' are statically known,
-- return the corresponding list of 'Type'.
hasStaticShape :: ExtType -> Maybe Type
hasStaticShape (Prim bt) =
  Just $ Prim bt
hasStaticShape (Mem size space) =
  Just $ Mem size space
hasStaticShape (Array bt (ExtShape shape) u) =
  Array bt <$> (Shape <$> mapM isFree shape) <*> pure u
  where isFree (Free s) = Just s
        isFree (Ext _)  = Nothing

hasStaticShapes :: [ExtType] -> Maybe [Type]
hasStaticShapes = mapM hasStaticShape

-- | Given two lists of 'ExtType's of the same length, return a list
-- of 'ExtType's that is a subtype (as per 'isSubtypeOf') of the two
-- operands.
generaliseExtTypes :: [TypeBase ExtShape u]
                   -> [TypeBase ExtShape u]
                   -> [TypeBase ExtShape u]
generaliseExtTypes rt1 rt2 =
  evalState (zipWithM unifyExtShapes rt1 rt2) (0, HM.empty)
  where unifyExtShapes t1 t2 =
          setArrayShape t1 . ExtShape <$>
          zipWithM unifyExtDims
          (extShapeDims $ arrayShape t1)
          (extShapeDims $ arrayShape t2)
        unifyExtDims (Free se1) (Free se2)
          | se1 == se2 = return $ Free se1 -- Arbitrary
          | otherwise  = do (n,m) <- get
                            put (n + 1, m)
                            return $ Ext n
        unifyExtDims (Ext x) (Ext y)
          | x == y = Ext <$> (maybe (new x) return =<<
                              gets (HM.lookup x . snd))
        unifyExtDims (Ext x) _ = Ext <$> new x
        unifyExtDims _ (Ext x) = Ext <$> new x
        new x = do (n,m) <- get
                   put (n + 1, HM.insert x n m)
                   return n

-- | Given a list of 'ExtType's and a set of "forbidden" names, modify
-- the dimensions of the 'ExtType's such that they are 'Ext' where
-- they were previously 'Free' with a variable in the set of forbidden
-- names.
existentialiseExtTypes :: Names -> [ExtType] -> [ExtType]
existentialiseExtTypes inaccessible ts =
  evalState (mapM makeBoundShapesFree ts)
  (firstavail, HM.empty, HM.empty)
  where firstavail = 1 + HS.foldl' max (-1) (shapeContext ts)
        makeBoundShapesFree t = do
          shape <- mapM checkDim $ extShapeDims $ arrayShape t
          return $ t `setArrayShape` ExtShape shape
        checkDim (Free (Var v))
          | v `HS.member` inaccessible =
            replaceVar v
        checkDim (Free se) = return $ Free se
        checkDim (Ext x)   = replaceExt x
        replaceExt x = do
          (n, extmap, varmap) <- get
          case HM.lookup x extmap of
            Nothing -> do put (n+1, HM.insert x (Ext n) extmap, varmap)
                          return $ Ext n
            Just replacement -> return replacement
        replaceVar name = do
          (n, extmap, varmap) <- get
          case HM.lookup name varmap of
            Nothing -> do put (n+1, extmap, HM.insert name (Ext n) varmap)
                          return $ Ext n
            Just replacement -> return replacement

-- | In the call @shapeMapping ts1 ts2@, the lists @ts1@ and @ts@ must
-- be of equal length and their corresponding elements have the same
-- types modulo exact dimensions (but matching array rank is
-- important).  The result is a mapping from named dimensions of @ts1@
-- to the corresponding dimension in @ts2@.
--
-- This function is useful when @ts1@ are the value parameters of some
-- function and @ts2@ are the value arguments, and we need to figure
-- out which shape context to pass.
shapeMapping :: [TypeBase Shape u0] -> [TypeBase Shape u1] -> HM.HashMap VName SubExp
shapeMapping ts = shapeMapping' ts . map arrayDims

-- | Like @shapeMapping@, but works with explicit dimensions.
shapeMapping' :: [TypeBase Shape u] -> [[a]] -> HM.HashMap VName a
shapeMapping' ts shapes = HM.fromList $ concat $ zipWith inspect ts shapes
  where inspect t shape =
          mapMaybe match $ zip (arrayDims t) shape
        match (Constant {}, _) = Nothing
        match (Var v, dim)     = Just (v, dim)

int8 :: PrimType
int8 = IntType Int8

int16 :: PrimType
int16 = IntType Int16

int32 :: PrimType
int32 = IntType Int32

int64 :: PrimType
int64 = IntType Int64

float32 :: PrimType
float32 = FloatType Float32

float64 :: PrimType
float64 = FloatType Float64

-- | Typeclass for things that contain 'Type's.
class Typed t where
  typeOf :: t -> Type

instance Typed Type where
  typeOf = id

instance Typed DeclType where
  typeOf = fromDecl

instance Typed Ident where
  typeOf = identType

instance Typed attr => Typed (Param attr) where
  typeOf = typeOf . paramAttr

instance Typed attr => Typed (PatElemT attr) where
  typeOf = typeOf . patElemAttr

instance Typed b => Typed (a,b) where
  typeOf = typeOf . snd

-- | Typeclass for things that contain 'DeclType's.
class DeclTyped t where
  declTypeOf :: t -> DeclType

instance DeclTyped DeclType where
  declTypeOf = id

instance DeclTyped attr => DeclTyped (Param attr) where
  declTypeOf = declTypeOf . paramAttr

-- | Typeclass for things whose type can be changed.
class Typed a => SetType a where
  setType :: a -> Type -> a

instance SetType Type where
  setType _ t = t

instance SetType b => SetType (a, b) where
  setType (a, b) t = (a, setType b t)

instance SetType attr => SetType (PatElemT attr) where
  setType (PatElem name bindage attr) t =
    PatElem name bindage $ setType attr t
