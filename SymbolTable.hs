module SymbolTable where
import Data.List

data SymbolType = SInt | SChar
  deriving(Eq, Ord, Bounded, Enum, Show)

data Symbol = Symbol {
  name :: String,
  address :: Int,
  sType :: SymbolType,
  value :: Int,
  used :: Bool
}deriving(Show)

intSymbol :: Symbol
intSymbol = Symbol { sType = SInt, used = False }

charSymbol :: Symbol
charSymbol = Symbol { sType = SChar, used = False }

type SymbolTable = [Symbol] 
