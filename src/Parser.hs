module Parser where

import Token
import Debug.Trace
import SymbolTable
--Ok so this took way to long to realise how to write properly
--I blame it on the class being taught imparativly :p
--Anyways the big break through was that when parsing something like
--(stuff) in a totally recursive way you have to call the functions
--in semingly reverse order. I should have realised that at first
--but for some reason it didn't seem right. 
--The exit conditiono for almost all of the recursive calls is to 
--just return rest. 

--entry point and also catches the error of there being a missing } at the end
parse :: [Token] -> ([Token], SymbolTable, [String]) 
parse tokens = empty $ program tokens

--the first rewrite rule. does nothing but be called by parse
program :: [Token] -> ([Token], SymbolTable, [String]) 
program tokens = statement (tokens, [], [])

--The big one. Catches most of the beginnings of complex statements
statement :: ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
statement ([],table,errors) = ([], table, ("Found error in statement recived empty token stream." ++
                              " Dangling operator? Expected Print, ID, Open Brace or int/char"):errors)
statement ((token:next:rest),table,errors)
  |kind token == PrintOp =
    consumeToken ParenClose (exper $ consumeToken ParenOpen $ 
    trace("parsing open paren") (next:rest, table, errors))
  |kind token == ID = 
    exper . consumeToken EqualsOp $ trace("parsing ID statement") (next:rest,table, errors)
  |kind token == OpenBrace = 
    consumeToken CloseBrace $! statementList $ trace("parsing open brace") (next:rest,table, errors)
  |kind token == IntOp = varDecl $ trace("parsing IntOp") (next:rest, insertSymbol table ([token,next]),errors)
  |kind token == CharOp = varDecl $ trace("parsing CharOp") (next:rest,insertSymbol table ([token,next]),errors)
  |otherwise = (rest, table,("Expecting more in statement found " ++ (show token)):errors)
--matches when there are only two elements left in the token list
statement ((token:rest),table,errors) = 
  (rest , table, ("Found error in statement on line " ++ (show $ location token) ++ " have " ++ (show token) ++ " expected more"):errors) 
  
--parses the expression rule and inserts symbols into the symbol table
exper :: ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
exper ([],table,errors) = ([], table, ("Found error in exper recived empty token stream." ++
                          " Dangling operator? Expected Digit ID or CharacterList"):errors)
exper ((token:next:rest),table,errors)
  |kind token == Digit = 
    intExper $ trace("parsing Digit " ++ (show token)) (next:rest,table,errors)
  |kind token == CharacterList = trace("parsed character list in exper") (next:rest,table,errors)
  |kind token == ID = trace("parsed ID in exper") (next:rest,table,errors)
  |otherwise = (rest, table, ("Error in exper found " ++ (show token) ++ " most likely a lone operator. Expected Digit, ID or Character list"):errors)
exper ((token:rest),table,errors)
  |kind token == Digit =  trace ("parsing last digit " ++ (show token)) (rest,table,errors)
  |kind token == CharacterList = trace("parsed last character list") (rest,table,errors) 
  |kind token == ID = trace("parsed last id") (rest,table,errors)
  |otherwise = (rest, table, ("Error in Exper found " ++ (show token) ++ " expected digit, character list or id"):errors)

--parses the existance of an ID after a type decleration
varDecl :: ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
varDecl ([],table,errors) = ([], table, ("found nothing expected ID in var decl"):errors) 
varDecl ((token:rest),table,errors)
  |kind token == ID = trace("parsing variable decleration") (rest,table,errors)
  |otherwise = (rest,table,("varDecl error with token" ++(show token)):errors)

--the big recursive guy. $! is 100% needed. if missing Haskell will be super lazy
--and recurse FOREVER by not consuming anything and instead just running in cicrles
statementList :: ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
statementList ([],table,errors) = ([],table,errors)
statementList ((token:rest),table,errors)
  |kind token == CloseBrace = trace("parsing end of statement list") $ (token:rest,table,errors)
  |otherwise  = statementList $!  
    statement $ trace("parsing statementList at " ++ (show token)) $ ((token:rest),table,errors) 

--parses recursive int expressions. does not calculate any values for symbols that's in
--sementic analysis
intExper :: ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
intExper ([],table,errors) = ([], table, ("found nothing expected + or - in int expression"):errors)
intExper ((token:rest),table,errors)
  |kind token == PlusOp = exper $ trace("parsed PlusOp") (rest,table,errors)
  |kind token == MinusOp = exper $ trace("parsed MinusOp") (rest,table,errors)
  |otherwise = trace("Done intExper") ((token:rest),table,errors)

--nom nom nom
consumeToken :: TokenType -> ([Token], SymbolTable, [String])  -> ([Token], SymbolTable, [String]) 
consumeToken type' ([],table,errors) = ([],table,(("Looking for " ++ (show type') ++ " found nothing") : errors))
consumeToken type' ((token:rest),table, errors)
  |kind token == type' = trace("consuming " ++(show  token)) $  (rest,table,errors)
  |otherwise = (rest,table,("expected: " ++ (show type') ++ " got " ++ (show token)):errors)

empty :: (TokenList, SymbolTable, [String]) -> ([Token], SymbolTable, [String])
empty ([],table,errors) = ([],table,errors)
empty (x,table,errors) 
  |kind first == CloseBrace = (x,table,("Found closeBrace without matching openBrace on line " ++ line):errors) 
  |kind first == ParenClose = (x,table,("Found closeParen without matching open paren on line " ++ line) :errors) 
  |kind first == Digit = (x,table,("Found unexpected digit on line " ++ line ++ " most likely began math with an ID"):errors)
  |otherwise = (x,table,("More than one statement found outside of {} on line." ++ 
    (show (location (x !! 0))) ++ " Maybe missing {}?"):errors)
  where 
    first = head x
    line = show (location first)
