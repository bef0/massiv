{-# LANGUAGE BangPatterns          #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies          #-}
-- |
-- Module      : Data.Array.Massiv.Manifest.Boxed
-- Copyright   : (c) Alexey Kuleshevich 2017
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Array.Massiv.Manifest.Boxed
  ( B (..)
  , Array(..)
  -- * Creation
  -- , generateM
  -- -- * Mapping
  -- , mapM
  -- , imapM
  -- -- * Conversion
  -- , fromVectorBoxed
  -- , toVectorBoxed
  -- -- * Evaluation
  -- , computeBoxedS
  -- , computeBoxedP
  -- , deepseq
  -- , deepseqP
  ) where

import           Control.DeepSeq                     (NFData (..), deepseq)
import           Control.Monad                       (void)
import           Data.Array.Massiv.Common
import           Data.Array.Massiv.Common.Shape
import           Data.Array.Massiv.Manifest.Internal
import           Data.Array.Massiv.Mutable
import           Data.Array.Massiv.Ops.Fold
import           Data.Array.Massiv.Scheduler
import           Data.Foldable                       (Foldable (..))
import qualified Data.Vector                         as V
import qualified Data.Vector.Mutable                 as MV
import           GHC.Base                            (build)
import           Prelude                             hiding (mapM)
import           System.IO.Unsafe                    (unsafePerformIO)

data B = B deriving Show

data instance Array B ix e = BArray { bComp :: !Comp
                                    , bSize :: !ix
                                    , bData :: !(V.Vector e)
                                    } deriving Eq

instance (Index ix, NFData e) => NFData (Array B ix e) where
  rnf arr@(BArray comp sz v) =
    case comp of
      Seq        -> sz `deepseq` v `deepseq` ()
      Par        -> arr `deepseqP` ()
      ParOn wIds -> deepseqOnP wIds arr ()


instance (Index ix, NFData e) => Construct B ix e where
  size = bSize
  {-# INLINE size #-}

  getComp = bComp
  {-# INLINE getComp #-}

  setComp c arr = arr { bComp = c }
  {-# INLINE setComp #-}

  unsafeMakeArray Seq          !sz f = unsafeGenerateArray sz f
  unsafeMakeArray (ParOn wIds) !sz f = unsafeGenerateArrayP wIds sz f
  {-# INLINE unsafeMakeArray #-}

instance (Index ix, NFData e) => Source B ix e where
  unsafeLinearIndex (BArray _ _ v) = V.unsafeIndex v
  {-# INLINE unsafeLinearIndex #-}


instance (Index ix, NFData e) => Shape B ix e where
  type R B = M

  unsafeReshape !sz !arr = arr { bSize = sz }
  {-# INLINE unsafeReshape #-}

  unsafeExtract !sIx !newSz !arr = unsafeExtract sIx newSz (toManifest arr)
  {-# INLINE unsafeExtract #-}


instance (Index ix, Index (Lower ix), NFData e) => Slice B ix e where

  (!?>) !arr = (toManifest arr !?>)
  {-# INLINE (!?>) #-}

  (<!?) !arr = (toManifest arr <!?)
  {-# INLINE (<!?) #-}


instance (Index ix, NFData e) => Manifest B ix e where

  unsafeLinearIndexM (BArray _ _ v) = V.unsafeIndex v
  {-# INLINE unsafeLinearIndexM #-}


instance (Index ix, NFData e) => Mutable B ix e where
  data MArray s B ix e = MBArray !ix !(V.MVector s e)

  msize (MBArray sz _) = sz
  {-# INLINE msize #-}

  unsafeThaw (BArray _ sz v) = MBArray sz <$> V.unsafeThaw v
  {-# INLINE unsafeThaw #-}

  unsafeFreeze comp (MBArray sz v) = BArray comp sz <$> V.unsafeFreeze v
  {-# INLINE unsafeFreeze #-}

  unsafeNew sz = MBArray sz <$> MV.unsafeNew (totalElem sz)
  {-# INLINE unsafeNew #-}

  unsafeLinearRead (MBArray _ v) !i = MV.unsafeRead v i
  {-# INLINE unsafeLinearRead #-}

  unsafeLinearWrite (MBArray _ v) !i e = e `deepseq` MV.unsafeWrite v i e
  {-# INLINE unsafeLinearWrite #-}


-- | Loading a Boxed array in parallel only make sense if it's elements are
-- fully evaluated into NF.
instance (Index ix, NFData e) => Target B ix e where

  unsafeTargetWrite !mv !i e = e `deepseq` unsafeLinearWrite mv i e
  {-# INLINE unsafeTargetWrite #-}


-- | Parallel version of `deepseq`: fully evaluate all elements of a boxed array in
-- parallel, while returning back the second argument.
deepseqP :: (Index ix, NFData a) => Array B ix a -> b -> b
deepseqP = deepseqOnP []
{-# INLINE deepseqP #-}


deepseqOnP :: (Index ix, NFData a) => [Int] -> Array B ix a -> b -> b
deepseqOnP wIds (BArray _ sz v) b =
  unsafePerformIO $ do
    splitWork_ wIds sz $ \ !scheduler !chunkLength !totalLength !slackStart -> do
      loopM_ 0 (< slackStart) (+ chunkLength) $ \ !start ->
        submitRequest scheduler $
        JobRequest $
        loopM_ start (< (start + chunkLength)) (+ 1) $ \ !k ->
          V.unsafeIndex v k `deepseq` return ()
      submitRequest scheduler $
        JobRequest $
        loopM_ slackStart (< totalLength) (+ 1) $ \ !k ->
          V.unsafeIndex v k `deepseq` return ()
    return b
{-# INLINE deepseqOnP #-}
