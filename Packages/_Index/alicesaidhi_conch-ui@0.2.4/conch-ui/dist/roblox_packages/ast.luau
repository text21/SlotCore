local main = require(script.Parent.Parent.Parent["ast"])
export type TokenKindText  = main.TokenKindText 
export type TokenKindRest  = main.TokenKindRest 
export type Token<T = TokenKindRest | TokenKindText> = main.Token<T >
export type Result  = main.Result 
return main