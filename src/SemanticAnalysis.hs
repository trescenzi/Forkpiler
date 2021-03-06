{-# LANGUAGE BangPatterns #-}
module SemanticAnalysis where
import Token
import qualified Data.Map as Map
import AST
import SymbolTable 
import Debug.Trace 

updateSymbolTable :: AST -> ScopeMap -> Scope -> ScopeMap
updateSymbolTable (AST parent []) m (pscope,scope) = m
updateSymbolTable (AST ast children) m (pscope,scop)
  |tt == EqualsOp  = assignValues children m (pscope,scop)
  |tt == PrintOp   = usedInPrint children m (pscope,scop)
  |tt == PlusOp    = usedInMath children m (pscope,scop)
  |tt == OpenBrace =
    let nextScope = scope (tokentype ast)
    in updateChildren children m (scop, nextScope)
  |otherwise = updateSymbolTable child m (pscope,scop) 
   where
    (child:childs) = children
    tt = kind $ original ast

updateChildren :: Children -> ScopeMap -> Scope -> ScopeMap
updateChildren [] m _ = m
updateChildren (child:childs) m (pscope,scope) =
  let nm = updateSymbolTable child m (pscope,scope)
  in updateChildren childs nm (pscope,scope)

assignValues :: Children -> ScopeMap -> Scope -> ScopeMap
assignValues [] m scope = m
assignValues (child:[]) m scope = m
assignValues (child1:child2:[]) m scope
  |opType == CharacterList =
    let value = contents (original op)
    in updateValue m token scope value 
  |opType == PlusOp = 
    let value = "-2"
    in updateValue m token scope value
  where 
    AST id _ = child1 
    --plus doesn't do anything other than set used yet
    AST op kids = child2
    opType = kind (original op)
    token = original id
assignValues kids m scope = m

usedInMath :: Children -> ScopeMap -> Scope -> ScopeMap
usedInMath (child1:child2:[]) m scope
  |lt == ID =
    let key = contents (original leftChild)
    in use m key scope
  |rt == ID =
    let key = contents (original rightChild)
    in use m key scope
  |rt == PlusOp = usedInMath rightKids m scope
  |lt == Digit = m
  |otherwise = error "Problem in math op that passed through everything..."
  where
    AST leftChild leftKids = child1 
    AST rightChild rightKids = child2
    rt = kind $ original rightChild
    lt = kind $ original leftChild

usedInPrint :: Children -> ScopeMap -> Scope -> ScopeMap
usedInPrint (child1:[]) m scope
  |tt == PlusOp = usedInMath children m scope
  |tt == ID = 
    let key = contents (original parent) 
    in use m key scope
  |otherwise = m
  where
    tt = kind $ original parent
    AST parent children = child1


typeCheck :: AST -> ScopeMap -> Int -> Symbol
typeCheck (AST ast children) m scop
  |tt == CharacterList = dummySymbol S 
  |tt == Digit = dummySymbol I
  |tt == EqualsOp = dummySymbol $ assignType children m scop
  |tt == PrintOp = dummySymbol $ printType children m scop
  |tt == PlusOp || tt == MinusOp = dummySymbol $ mathType children m scop
  |tt == Equality = dummySymbol $ boolType children m scop
  |tt == While || tt == If =
    let
      ((AST parent leftChildren):right:[]) = children
      !dumb = trace("here's the left " ++ show leftChildren) dummySymbol $! boolType leftChildren m scop
    in typeCheck right m scop
  |tt == OpenBrace = 
    let nextScope = scope (tokentype ast)
    in dummySymbol $ head' $! typeCheckChildren children m nextScope
  |tt == IntOp = dummySymbol I
  |tt == CharOp = dummySymbol S
  |tt == Boolean = dummySymbol B
  |tt == FalseOp || tt == TrueOp = dummySymbol B
  |tt == ID = getSymbol 
  where 
    tt = kind $ original ast
    key = contents $ original ast
    line = location $ original ast
    dummySymbol t = Symbol "dummy" (-1) t "" False
    getSymbol
     |symbol == Errer = error $ "Undecler ID: " ++ key ++ " on Line: " ++ show line
     |otherwise = trace ("typechecking symbol: " ++ name symbol ++ " has type " ++(show $ sType symbol)) symbol
     where symbol = findInScope m key scop
typeCheck ast m scope = trace ("typechecking error" ++ (show ast)) Symbol "dummy" (-1) I "" False


boolType :: [AST] -> ScopeMap -> Int -> SymbolType
boolType [] m scope = B
boolType (child1:child2:[]) m scope
  |lt /= rt = error("Type mismatch in equality check: "  ++ (name left)
    ++" Found: " ++ (expandType rt) ++ " Expected: " ++ (expandType lt)
    ++ " on line: " ++ (show line)) 
  |otherwise = trace("Well this is akward") lt
  where
    !left = typeCheck child1 m scope 
    !right = typeCheck child2 m scope
    !lt = trace ("LEFT="++(show $ sType left)) sType left
    !rt = trace ("RIGHT="++(show $ sType left)) sType right
    AST node _  = child1
    line = location $ original node

head' :: [SymbolType] -> SymbolType 
head' [] = I
head' (x:xs) = x

typeCheckChildren :: [AST] -> ScopeMap -> Int -> [SymbolType]
typeCheckChildren [] m scope = [] 
typeCheckChildren (child: childs) m scope = 
    childScope : kidsScope
  where
    !childScope = sType $ typeCheck child m scope
    !kidsScope = typeCheckChildren childs m scope

assignType :: [AST] -> ScopeMap -> Int -> SymbolType
assignType (child1:child2:[]) m scope
  |lt /= rt = error("Type mismatch in assignment of: "  ++ (name left)
    ++" Found: " ++ (expandType rt) ++ " Expected: " ++ (expandType lt)
    ++ " on line: " ++ (show line)) 
  |otherwise = trace("I'm ignorning your order") lt
  where 
    !left = typeCheck child1 m scope 
    !right = typeCheck child2 m scope
    !lt = trace ("LEFT="++(show $ sType left)) sType left
    !rt = trace ("RIGHT="++(show $ sType left)) sType right
    AST node _  = child1
    line = location $ original node

mathType :: [AST] -> ScopeMap -> Int -> SymbolType
mathType (child1:child2:[]) m scope
  |lt == S = error("Error: Found String on left of plus. Line: " ++ (show line)
        ++ "\n Note: Plus is not for String conciatenation") 
  |rt == S = error("Error: Found String on right of plus. Line: " ++ (show line)
      ++ " \nNote: Plus is not for String concatenation")
  |rt == B = error("Error: Found Boolean on right of plus. Line: " ++ (show line)
      ++ " \nNote: Plus is not defined for Booleans") 
  |lt == B = error("Error: Found Boolean on left of plus. Line: " ++ (show line)
      ++ " \nNote: Plus is not defined for Booleans") 
  |otherwise = I
  where
    !left = typeCheck child1 m scope
    !right = typeCheck child2 m scope 
    lt = sType left
    rt = sType right
    AST node _  = child1
    line = location $ original node

printType :: [AST] -> ScopeMap -> Int -> SymbolType
printType (child1:[]) m scope 
  |tt == PlusOp = mathType children m scope
  |tt == CharacterList = S
  |tt == Digit = I
  |otherwise = sType $ typeCheck child1 m scope
  where 
    tt = kind $ original parent
    AST parent children = child1 

--Initial Building of the symbol table
--Also sets up the scopes on the AST
--buildSymbolTable :: AST -> (ScopeMap,AST)
--buildSymbolTable tree = symbolLine (tree, emptySymbolTable, (0,0))
buildSymbolTable :: AST -> (AST, ScopeMap)
buildSymbolTable tree = statement (tree, emptySymbolTable, (-1,0))

--looks at a single statement and only fires on brackets
--and variable declerations
statement :: (AST, ScopeMap, Scope) -> (AST, ScopeMap)
statement (AST parent [], m, _) = (AST parent [], m)
statement (tree, m, scope) 
  |tt == IntOp = (tree, intScope child m scope)
  |tt == CharOp = (tree, charScope child m scope) 
  |tt == Boolean = (tree, boolScope child m scope)
  |tt == While || tt == If = 
    --jump to { and do a statement stuff on it
    let (blockChildren, newMap) = statement (head children,m,scope)
    in (addChildTree (AST parent [child]) blockChildren, newMap) 
  |tt == OpenBrace =
    let
      nextScope = findNextScope m s
      dummy = tokenAndTypeToSymbol (Token "parent" s Digit) I
      !newMap = insertInScope m dummy (s, nextScope)
      newParent = AST $ Terminal (original parent) (N nextScope)
      --make a new map and rebuild set of children
      (!kids, !updatedMap) = bracket (child:children) (newMap, (s, nextScope), [])
    in (newParent kids, updatedMap)
  |otherwise =
    let (_, updated) = statement (child, m, scope)
    in  (tree, updated)
  where
    AST parent (child:children) = tree
    (p, s) = scope
    tt = kind $ original parent

bracket :: Children -> (ScopeMap, Scope, Children) -> (Children, ScopeMap)
bracket [] (m, _, kids) = (kids, m)
bracket (kid:kids) (m, scope, children) = 
  let (child, newMap) = statement (kid, m, scope)
  in bracket kids (newMap, scope, children++[child]) 

intScope :: AST -> ScopeMap -> Scope -> ScopeMap
intScope (AST parent []) m scope = updatedMap
    where 
      updatedMap = insertInScope m symbol scope
      symbol = tokenAndTypeToSymbol t I
      t = original parent

boolScope :: AST -> ScopeMap -> Scope -> ScopeMap
boolScope (AST parent []) m scope = updatedMap
    where 
      updatedMap = insertInScope m symbol scope
      symbol = tokenAndTypeToSymbol t B
      t = original parent

charScope :: AST -> ScopeMap -> Scope -> ScopeMap
charScope (AST parent []) m scope = updatedMap
    where 
      updatedMap = insertInScope m symbol scope
      symbol = tokenAndTypeToSymbol t S
      t = original parent

findNextScope :: ScopeMap -> Int -> Int
findNextScope m current = if Map.member current m 
  then findNextScope m (current+1) else current
