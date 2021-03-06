{-# LANGUAGE
    DeriveDataTypeable
  , MultiParamTypeClasses
  , FlexibleInstances
  , UndecidableInstances #-}

-- Copyright (C) 2010 John Millikin <jmillikin@gmail.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

module UI.NCurses.Types where

import qualified Control.Applicative as A
import           Control.Exception (Exception, throwIO)
import           Control.Monad (liftM, ap)
import           Control.Monad.Fix (MonadFix, mfix)
import           Control.Monad.IO.Class (MonadIO, liftIO)
import           Control.Monad.Trans.Class
import           Control.Monad.Trans.Reader (ReaderT)
import           Control.Monad.Reader.Class
import           Control.Monad.Writer.Class
import           Control.Monad.State.Class
import           Control.Monad.Error.Class
import           Data.Typeable
import qualified Foreign as F
import qualified Foreign.C as F

import qualified UI.NCurses.Enums as E


-- | A small wrapper around 'IO', to ensure the @ncurses@ library is
-- initialized while running.
newtype CursesT m a = CursesT { unCurses :: m a }

type Curses = CursesT IO

instance Functor m => Functor (CursesT m) where
	fmap f = CursesT . fmap f . unCurses

instance Applicative m => A.Applicative (CursesT m) where
	pure = CursesT . pure
	(CursesT f) <*> (CursesT m) = CursesT $ f <*> m

instance Monad m => Monad (CursesT m) where
	return = CursesT . return
	m >>= f = CursesT (unCurses m >>= unCurses . f)

instance MonadFix m => MonadFix (CursesT m) where
	mfix f = CursesT (mfix (unCurses . f))

instance MonadTrans CursesT where
  lift = CursesT

instance MonadIO m => MonadIO (CursesT m) where
	liftIO = CursesT . liftIO

instance MonadReader r m => MonadReader r (CursesT m) where
  ask   = lift ask
  local f (CursesT m) = lift $ local f m
instance MonadWriter w m => MonadWriter w (CursesT m) where
  writer = lift . writer
  listen (CursesT m) = lift $ listen m
  pass   (CursesT m) = lift $ pass   m
instance MonadState  s m => MonadState  s (CursesT m) where
  state = lift . state
  get   = lift get
instance MonadError  e m => MonadError  e (CursesT m) where
  throwError = lift . throwError
  catchError (CursesT m) f = lift $ catchError m (unCurses . f)

newtype Update a = Update { unUpdate :: ReaderT Window Curses a }

instance Monad Update where
	return = Update . return
	m >>= f = Update (unUpdate m >>= unUpdate . f)

instance MonadFix Update where
	mfix f = Update (mfix (unUpdate . f))

instance Functor Update where
	fmap = liftM

instance A.Applicative Update where
	pure = return
	(<*>) = ap

newtype Window = Window { windowPtr :: F.Ptr Window }

newtype CursesException = CursesException String
	deriving (Show, Typeable)

instance Exception CursesException

checkRC :: String -> F.CInt -> IO ()
checkRC name rc = if toInteger rc == E.fromEnum E.ERR
	then throwIO (CursesException (name ++ ": rc == ERR"))
	else return ()

cToBool :: Integral a => a -> Bool
cToBool 0 = False
cToBool _ = True

cFromBool :: Integral a => Bool -> a
cFromBool False = 0
cFromBool True = 1
