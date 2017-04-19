{-# LANGUAGE DataKinds, TemplateHaskell #-}
module Language.Ruby.Syntax where

import Data.Functor.Union
import qualified Data.Syntax as Syntax
import Data.Syntax.Assignment
import qualified Data.Syntax.Comment as Comment
import qualified Data.Syntax.Declaration as Declaration
import qualified Data.Syntax.Expression as Expression
import qualified Data.Syntax.Literal as Literal
import qualified Data.Syntax.Statement as Statement
import Language.Haskell.TH
import Prologue hiding (optional, unless)
import Term
import Text.Parser.TreeSitter.Language
import Text.Parser.TreeSitter.Ruby

-- | The type of Ruby syntax.
type Syntax = Union Syntax'
type Syntax' =
  '[Comment.Comment
  , Declaration.Class
  , Declaration.Method
  , Expression.Not
  , Literal.Array
  , Literal.Boolean
  , Literal.Hash
  , Literal.Integer
  , Literal.String
  , Literal.Symbol
  , Statement.Break
  , Statement.Continue
  , Statement.If
  , Statement.Return
  , Statement.Yield
  , Syntax.Empty
  , Syntax.Identifier
  , []
  ]


term :: InUnion Syntax' f => f (Term Syntax ()) -> Term Syntax ()
term f = cofree $ () :< inj f


-- | Statically-known rules corresponding to symbols in the grammar.
mkSymbolDatatype (mkName "Grammar") tree_sitter_ruby


-- | Assignment from AST in Ruby’s grammar onto a program in Ruby’s syntax.
assignment :: Assignment Grammar [Term Syntax ()]
assignment = symbol Program *> children (many declaration)

declaration :: Assignment Grammar (Term Syntax ())
declaration = comment <|> class' <|> method

class' :: Assignment Grammar (Term Syntax ())
class' = term <$  symbol Class
              <*> children (Declaration.Class <$> (constant <|> scopeResolution) <*> (superclass <|> pure []) <*> many declaration)
  where superclass = pure <$ symbol Superclass <*> children constant
        scopeResolution = symbol ScopeResolution *> children (constant <|> identifier)

constant :: Assignment Grammar (Term Syntax ())
constant = term . Syntax.Identifier <$ symbol Constant <*> source

identifier :: Assignment Grammar (Term Syntax ())
identifier = term . Syntax.Identifier <$ symbol Identifier <*> source

method :: Assignment Grammar (Term Syntax ())
method = term <$  symbol Method
              <*> children (Declaration.Method <$> identifier <*> pure [] <*> (term <$> many statement))

statement :: Assignment Grammar (Term Syntax ())
statement  =  exit Statement.Return Return
          <|> exit Statement.Yield Yield
          <|> exit Statement.Break Break
          <|> exit Statement.Continue Next
          <|> if'
          <|> ifModifier
          <|> unless
          <|> literal
  where exit construct sym = term . construct <$ symbol sym <*> children (optional (symbol ArgumentList *> children statement))

comment :: Assignment Grammar (Term Syntax ())
comment = term . Comment.Comment <$ symbol Comment <*> source

if' :: Assignment Grammar (Term Syntax ())
if' = go If
  where go s = term <$ symbol s <*> children (Statement.If <$> statement <*> (term <$> many statement) <*> optional (go Elsif <|> term <$ symbol Else <*> children (many statement)))

ifModifier :: Assignment Grammar (Term Syntax ())
ifModifier = term <$ symbol IfModifier <*> children (flip Statement.If <$> statement <*> statement <*> pure (term Syntax.Empty))

unless :: Assignment Grammar (Term Syntax ())
unless = term <$ symbol Unless <*> children (Statement.If <$> (term . Expression.Not <$> statement) <*> (term <$> many statement) <*> optional (term <$ symbol Else <*> children (many statement)))

literal :: Assignment Grammar (Term Syntax ())
literal  =  term Literal.true <$ symbol Language.Ruby.Syntax.True <* source
        <|> term Literal.false <$ symbol Language.Ruby.Syntax.False <* source
        <|> term . Literal.Integer <$ symbol Language.Ruby.Syntax.Integer <*> source

optional :: Assignment Grammar (Term Syntax ()) -> Assignment Grammar (Term Syntax ())
optional a = a <|> pure (term Syntax.Empty)
