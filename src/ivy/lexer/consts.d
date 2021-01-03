module ivy.lexer.consts;

static immutable mixedBlockBegin = "{*";
static immutable mixedBlockEnd = "*}";

static immutable commentBlockBegin = "{#";
static immutable commentBlockEnd = "#}";

static immutable dataBlockBegin = `{"`;
static immutable dataBlockEnd = `"}`;

static immutable exprBlockBegin = `{{`;
static immutable exprBlockEnd = `}}`;
static immutable codeBlockBegin = `{=`;
static immutable codeListBegin = `{%`;

enum LexemeType {
	Unknown = 0,
	Add,
	Assign,
	Colon,
	Comma,
	Div,
	Dot,
	Equal,
	GT,
	GTEqual,
	LBrace,
	LBracket,
	LParen,
	LT,
	LTEqual,
	DoubleMod,
	Mod,
	Mul,
	NotEqual,
	Pipe,
	Pow,
	RBrace,
	RBracket,
	RParen,
	Semicolon,
	Sub,
	Tilde,
	Integer,
	Float,
	String,
	Name,
	ExprBlockBegin,
	ExprBlockEnd,
	CodeBlockBegin,
	CodeListBegin,
	MixedBlockBegin,
	MixedBlockEnd,
	Comment,
	Data,
	DataBlock,
	Invalid,
	EndOfFile,


	CoreTypesEnd,
	ExtensionTypesStart = 100,

	CodeBlockEnd = LexemeType.RBrace,
	CodeListEnd = LexemeType.RBrace
}


enum LexemeFlag: uint
{
	None = 0,
	Literal = 1 << 0,
	Dynamic = 1 << 1,
	Operator = 1 << 2,
	Paren = 1 << 3,
	Left = 1 << 4,
	Right = 1 << 5,
	Arithmetic = 1 << 6,
	Compare = 1 << 7,
	Separator = 1 << 8
}

enum ContextState
{
	CodeContext,
	MixedContext
}