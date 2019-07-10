module Test.Massiv.Utils
  ( assertException
  , assertExceptionIO
  , assertSomeException
  , assertSomeExceptionIO
  , toStringException
  , ExpectedException(..)
  , module X
  ) where

import Data.Typeable as X
import Test.QuickCheck as X
import Test.QuickCheck.Monadic as X
import Test.Hspec as X
import Test.QuickCheck.Function as X
import Control.DeepSeq (NFData, deepseq)
import UnliftIO.Exception (Exception(..), SomeException, catch, catchAny)

assertException ::
     (Testable b, NFData a, Exception exc)
  => (exc -> b) -- ^ Return True if that is the exception that was expected
  -> a -- ^ Value that should throw an exception, when fully evaluated
  -> Property
assertException isExc = assertExceptionIO isExc . pure


assertSomeException :: NFData a => a -> Property
assertSomeException = assertSomeExceptionIO . pure


assertExceptionIO ::
     (Testable b, NFData a, Exception exc)
  => (exc -> b) -- ^ Return True if that is the exception that was expected
  -> IO a -- ^ IO Action that should throw an exception
  -> Property
assertExceptionIO isExc action =
  monadicIO $
  run $
  catch
    (do res <- action
        res `deepseq` return (counterexample "Did not receive an exception" False))
    (\exc -> displayException exc `deepseq` return (property (isExc exc)))

assertSomeExceptionIO :: NFData a => IO a -> Property
assertSomeExceptionIO action =
  monadicIO $
  run $
  catchAny
    (do res <- action
        res `deepseq` return (counterexample "Did not receive an exception" False))
    (\exc -> displayException exc `deepseq` return (property True))


toStringException :: Either SomeException a -> Either String a
toStringException = either (Left . displayException) Right


data ExpectedException = ExpectedException deriving (Show, Eq)

instance Exception ExpectedException
