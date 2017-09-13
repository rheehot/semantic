{-# LANGUAGE TypeOperators, DataKinds #-}
module Semantic.Util where

import Data.Blob
import Language.Haskell.HsColour (hscolour, Output(TTY))
import Language.Haskell.HsColour.Colourise (defaultColourPrefs)
import Text.Show.Pretty (ppShow)
import Files
import Data.Record
import Data.Functor.Classes
import Algorithm
import Data.Align.Generic
import Interpreter
import Parser
import Decorators
import Data.Functor.Both
import Term
import Diff
import Semantic
import Semantic.Task
import Renderer.TOC
import Data.Union
import Data.Syntax.Declaration as Declaration
import Data.Range
import Data.Span
import Data.Syntax

-- Produces colorized pretty-printed output for the terminal / GHCi.
pp :: Show a => a -> IO ()
pp = putStrLn . hscolour TTY defaultColourPrefs False False "" False . ppShow

file :: FilePath -> IO Blob
file path = Files.readFile path (languageForFilePath path)

diffWithParser :: (HasField fields Data.Span.Span,
                                     HasField fields Range,
                                     Error :< fs,
                                     Declaration.Method :< fs,
                                     Declaration.Function :< fs,
                                     Empty :< fs,
                                     Apply1 Eq1 fs, Apply1 Show1 fs,
                                     Apply1 Traversable fs, Apply1 Functor fs,
                                     Apply1 Foldable fs, Apply1 Diffable fs,
                                     GAlign (Data.Union.Union fs)) =>
                                    Parser (Term (Data.Union.Union fs) (Record fields))
                                    -> Both Blob
                                    -> Task (Diff (Union fs) (Record (Maybe Declaration ': fields)))
diffWithParser parser = run (\ blob -> parse parser blob >>= decorate (declarationAlgebra blob))
  where
    run parse sourceBlobs = distributeFor sourceBlobs parse >>= diffTermPair sourceBlobs diffRecursively

    diffRecursively :: (Eq1 f, GAlign f, Show1 f, Traversable f, Diffable f) => Both (Term f (Record fields)) -> Diff f (Record fields)
    diffRecursively = decoratingWith constructorNameAndConstantFields (diffTermsWith algorithmForTerms comparableByConstructor)

