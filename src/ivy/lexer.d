module ivy.lexer;

import std.range, std.algorithm, std.conv, std.stdio;

import ivy.lexer_tools, ivy.common;

class IvyLexerException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

void lexerError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new IvyLexerException(msg, file, line);
}

static immutable whitespaceChars = " \n\t\r";
static immutable delimChars = "()[]{}%*-+/#,:|.<>=!";
static immutable intChars = "0123456789";

static immutable exprBlockBegin = "{{";
static immutable exprBlockEnd = "}}";

static immutable codeBlockBegin = "(%";
//static immutable rawCodeBlockBegin = "{{=";
static immutable codeBlockEnd = "%)";

static immutable codeListBegin = "{%";
//static immutable rawCodeListBegin = "{%=";
static immutable codeListEnd = "%}";

static immutable mixedBlockBegin = "{*";
//static immutable rawMixedBlockBegin = "{*=";
static immutable mixedBlockEnd = "*}";

static immutable commentBlockBegin = "{#";
static immutable commentBlockEnd = "#}";

static immutable dataBlockBegin = `{"`;
static immutable dataBlockEnd = `"}`;


enum LexemeType {
	Unknown = 0,
	Add,
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
	//RawExprBlockBegin,
	ExprBlockEnd,
	CodeBlockBegin,
	//RawCodeBlockBegin,
	CodeBlockEnd,
	CodeListBegin,
	//RawCodeListBegin,
	CodeListEnd,
	MixedBlockBegin,
	//RawMixedBlockBegin,
	MixedBlockEnd,
	Comment,
	Data,
	DataBlock,
	Invalid,
	EndOfFile,
	
	
	CoreTypesEnd,
	ExtensionTypesStart = 100
};


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

//Minimal information about type of lexeme
struct LexemeInfo
{
	import std.typecons: BitFlags;

	int typeIndex = 0; // LexemeType for this lexeme
	BitFlags!LexemeFlag flags;
	int pairTypeIndex = 0; // LexemeType for pair of this lexeme
		
	@property const
	{
		bool isLiteral()
		{
			return cast(bool)( flags & LexemeFlag.Literal );
		}
		
		bool isDynamic()
		{
			return cast(bool)( flags & LexemeFlag.Dynamic );
		}
		
		bool isStatic()
		{
			return !( flags & LexemeFlag.Dynamic );
		}
		
		bool isOperator()
		{
			return cast(bool)( flags & LexemeFlag.Operator );
		}
		
		bool isParen()
		{
			return cast(bool)( flags & LexemeFlag.Paren );
		}
		
		bool isLeftParen()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Paren )
				&& ( flags & LexemeFlag.Left ) 
			);
		}
		
		bool isRightParen()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Paren )
				&& ( flags & LexemeFlag.Right ) 
			);
		}
		
		bool isArithmeticOperator()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Operator )
				&& ( flags & LexemeFlag.Arithmetic ) 
			);
		}
		
		bool isCompareOperator()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Operator )
				&& ( flags & LexemeFlag.Compare ) 
			);
		}
		
		bool isValidCoreType()
		{
			return LexemeType.Unknown < typeIndex && typeIndex < LexemeType.Invalid;
		}
		
		bool isExtensionType()
		{
			return typeIndex >= LexemeType.ExtensionTypesStart;
		}
		
		bool isValidType()
		{
			return typeIndex != LexemeType.Unknown && typeIndex != LexemeType.EndOfFile && typeIndex != LexemeType.Invalid;
		}
		
		bool isUnknown()
		{
			return typeIndex == LexemeType.Unknown;
		}
		
		bool isInvalid()
		{
			return typeIndex == LexemeType.Invalid;
		}
		
		bool isEndOfFile()
		{
			return typeIndex == LexemeType.EndOfFile;
		}
	}
}

///Minumal info about found lexeme
struct Lexeme(LocationConfig c)
{
	enum config = c;
	alias CustLocation = CustomizedLocation!(config);

	CustLocation loc; // Location of this lexeme in source text
	LexemeInfo info; // Field containing information about this lexeme

	bool test(int testType) const
	{
		return this.info.typeIndex == testType;
	}

	bool test(int[] testTypes) const
	{
		import std.algorithm: canFind;
		return testTypes.canFind( this.info.typeIndex );
	}

	int typeIndex() const @property
	{
		return info.typeIndex;
	}

	auto getSlice(SourceRange)(ref SourceRange sourceRange) const
	{
		return sourceRange[loc.index .. loc.index + loc.length];
	}
}


template GetSourceRangeConfig(R)
{
	static if( is( typeof(R.config) == LocationConfig ) )
	{
		enum GetSourceRangeConfig = R.config;
	}
	else
	{
		enum GetSourceRangeConfig = ( () {
			LocationConfig c;
			
			return c;
		} )();
	}
}

// Just creates empty lexeme at specified position and of certain type (Unknown type by default)
template createLexemeAt(SourceRange)
{
	alias config = GetSourceRangeConfig!SourceRange;
	alias LexemeT = Lexeme!(config);

	LexemeT createLexemeAt(ref SourceRange source, LexemeType lexType = LexemeType.Unknown)
	{
		LexemeT lex;
		lex.info = LexemeInfo(lexType);
		lex.loc.index = source.index;
		lex.loc.length = 0;
		
		static if( config.withGraphemeIndex )
		{
			lex.loc.graphemeIndex = source.graphemeIndex;
			lex.loc.graphemeLength = 0;
		}
		
		static if( config.withLineIndex )
		{
			lex.loc.lineIndex = source.lineIndex;
			lex.loc.lineCount = 0;
		
			static if( config.withColumnIndex )
				lex.loc.columnIndex = source.columnIndex;
			
			static if( config.withGraphemeColumnIndex )
				lex.loc.graphemeColumnIndex = source.graphemeColumnIndex;
		}
		
		return lex;
	}
}

// Universal super-duper extractor of lexemes by it's begin, end ranges and info about type of lexeme
auto extractLexeme(SourceRange)(ref SourceRange beginRange, ref const(SourceRange) endRange, ref const(LexemeInfo) lexemeInfo)
{
	enum LocationConfig config = GetSourceRangeConfig!SourceRange;
	
	Lexeme!(config) lex;
	lex.info = lexemeInfo;

	// TODO: Maybe we should just add Location field for Lexeme
	lex.loc.index = beginRange.index;

	assert( endRange.index >= beginRange.index,
		"Index for end range must not be less than for begin range!"
	);
	// Not idiomatic range maybe approach, but effective
	lex.loc.length = endRange.index - beginRange.index;
	
	static if( config.withGraphemeIndex )
	{
		lex.loc.graphemeIndex = beginRange.graphemeIndex;

		assert( endRange.graphemeIndex >= beginRange.graphemeIndex,
			"Grapheme index for end range must not be less than for begin range!"
		);
		lex.loc.graphemeLength = endRange.graphemeIndex - beginRange.graphemeIndex;
	}
	
	static if( config.withLineIndex )
	{
		lex.loc.lineIndex = beginRange.lineIndex;

		assert( endRange.lineIndex >= beginRange.lineIndex,
			"Line index for end range must not be less than for begin range!"
		);
		lex.loc.lineCount = endRange.lineIndex - beginRange.lineIndex;
	
		static if( config.withColumnIndex )
			lex.loc.columnIndex = beginRange.columnIndex;
		
		static if( config.withGraphemeColumnIndex )
			lex.loc.graphemeColumnIndex = beginRange.graphemeColumnIndex;
	}

	// Getting slice of this lexeme in order to parse indents
	auto parsedRange = beginRange[0..lex.loc.length];

	IndentStyle indentStyle;
	size_t minIndentCount = size_t.max;

	by_line_loop:
	while( !parsedRange.empty )
	{
		size_t lineIndentCount;
		IndentStyle lineIndentStyle;
		parsedRange.parseLineIndent( lineIndentCount, lineIndentStyle );

		bool isEmptyLine = true;
		// Inner loop check if line contains meaningful characters
		while( !parsedRange.empty )
		{
			auto ch = parsedRange.popChar();
			if( !" \t\r\n".canFind(ch) )
			{
				isEmptyLine = false;
			}

			if( ch == ' ' && ch == '\t' )
			{
				continue; //Just skip rest empty spaces
			}
			else if( parsedRange.isNewLine || parsedRange.empty )
			{
				if( !isEmptyLine )
				{
					minIndentCount = min(minIndentCount, lineIndentCount);
					indentStyle = lineIndentStyle;
				}

				continue by_line_loop;
			}
		}
	}
	lex.loc.indentCount = minIndentCount;
	lex.loc.indentStyle = indentStyle;
	
	beginRange = endRange.save; //Move start currentRange to point of end currentRange
	return lex;
}

// Simple function for parsing static lexemes
bool parseStaticLexeme(SourceRange, LexRule)(ref SourceRange source, ref const(LexRule) rule)
{
	if( source.match(rule.val) )
	{
		return true;
	}

	return false;
}

struct LexicalRule(R)
	if( isForwardRange!R )
{
	import std.traits: Unqual;
	
	alias SourceRange = R;
	enum config = GetSourceRangeConfig!R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];
	alias LexemeT = Lexeme!(config);

	// Methods of this type should return true if starting part of range matches this rule
	// and consume this part. Otherwise it should return false
	alias ParseMethodType = bool function(ref SourceRange source, ref const(LexicalRule!R) rule);
	alias parseStaticMethod = parseStaticLexeme!( SourceRange, LexicalRule!R );
	
	String val;
	ParseMethodType parseMethod;
	LexemeInfo lexemeInfo;

	bool apply(ref SourceRange currentRange) inout
	{
		return parseMethod(currentRange, this);
	}
	
	@property const
	{
		bool isDynamic()
		{
			return lexemeInfo.isDynamic;
		}
		
		bool isStatic()
		{
			return lexemeInfo.isStatic;
		}
	}
}

enum ContextState { CodeContext, MixedContext };

struct Lexer(S, LocationConfig c = LocationConfig.init)
{
	import std.typecons: BitFlags;	
	
	alias SourceRange = TextForwardRange!(String, c);
	alias LexRule = LexicalRule!(SourceRange);
	alias LexemeT = LexRule.LexemeT;
	alias Char = SourceRange.Char;
	alias String = S;
	enum LocationConfig config = c;
	alias LexTypeIndex = int;

	static auto staticRule(Flags...)(String str, LexemeType lexType, Flags extraFlags)
	{
		BitFlags!LexemeFlag newFlags;
		int pairTypeIndex;
		
		foreach(flag; extraFlags)
		{
			static if( is( typeof(flag) == LexemeFlag ) )
			{
				newFlags |= flag;
			}
			else static if( is( typeof(flag) == LexemeType ) || is( typeof(flag) == int ) )
			{
				assert( pairTypeIndex == 0, "Pair type index is not 0, so seems that it's attempt to set multiple pairs for lexeme" );
				pairTypeIndex = flag;
			}
			else
			{
				static assert( false, "Expected lexeme flags or pair lexeme index" );
			}
		}

		newFlags &= ~LexemeFlag.Dynamic;
		assert( !(  cast(bool)(newFlags & LexemeFlag.Paren) && pairTypeIndex == 0 ), "Lexeme with LexemeFlag.Paren expected to have pair lexeme" );
		
		return LexRule( str, &parseStaticLexeme!(SourceRange, LexRule), LexemeInfo( lexType, newFlags, pairTypeIndex ) );
	}
	
	static auto dynamicRule(Flags...)(LexRule.ParseMethodType method, LexemeType lexType, Flags extraFlags)
	{
		BitFlags!LexemeFlag newFlags;
		
		foreach(flag; extraFlags)
			newFlags |= flag;
			
		newFlags |= LexemeFlag.Dynamic;
		
		return LexRule( null, method, LexemeInfo( lexType, newFlags ) );
	}

	public:


	
	__gshared LexRule[] mixedContextRules = [
		//staticRule( rawCodeBlockBegin, LexemeType.RawCodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeBlockEnd ),
		staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeBlockEnd ),

		//staticRule( rawCodeListBegin, LexemeType.RawCodeListBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeListEnd ),
		staticRule( codeListBegin, LexemeType.CodeListBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeListEnd ),

		//staticRule( rawMixedBlockBegin, LexemeType.RawMixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.MixedBlockEnd ),
		staticRule( mixedBlockBegin, LexemeType.MixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.MixedBlockEnd ),
		staticRule( mixedBlockEnd, LexemeType.MixedBlockEnd, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.MixedBlockBegin ),
		
		//staticRule( rawExprBlockBegin, LexemeType.RawExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.ExprBlockEnd ),
		staticRule( exprBlockBegin, LexemeType.ExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.ExprBlockEnd ),
		dynamicRule( &parseData, LexemeType.Data, LexemeFlag.Literal )
	];
	
	__gshared LexRule[] codeContextRules = [
		dynamicRule( &parseDataBlock, LexemeType.DataBlock, LexemeFlag.Literal ),
	
		//staticRule( rawCodeBlockBegin, LexemeType.RawCodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeBlockEnd ),
		staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeBlockEnd ),
		staticRule( codeBlockEnd, LexemeType.CodeBlockEnd, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.CodeBlockBegin ),
		
		//staticRule( rawCodeListBegin, LexemeType.RawCodeListBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeListEnd ),
		staticRule( codeListBegin, LexemeType.CodeListBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.CodeListEnd ),
		staticRule( codeListEnd, LexemeType.CodeListEnd, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.CodeListBegin ),

		//staticRule( rawMixedBlockBegin, LexemeType.RawMixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.MixedBlockEnd ),
		staticRule( mixedBlockBegin, LexemeType.MixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.MixedBlockEnd ),
		staticRule( mixedBlockEnd, LexemeType.MixedBlockEnd, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.MixedBlockBegin ),

		//staticRule( rawExprBlockBegin, LexemeType.RawExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.ExprBlockEnd ),
		staticRule( exprBlockBegin, LexemeType.ExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.ExprBlockEnd ),
		staticRule( exprBlockEnd, LexemeType.ExprBlockEnd, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.ExprBlockBegin ),
		
		staticRule( "+", LexemeType.Add, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "==", LexemeType.Equal, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( ":", LexemeType.Colon, LexemeFlag.Operator ),
		staticRule( ",", LexemeType.Comma, LexemeFlag.Operator ),
		staticRule( "/", LexemeType.Div, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( ".", LexemeType.Dot, LexemeFlag.Operator ),
		staticRule( ">=", LexemeType.GTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( ">", LexemeType.GT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "{", LexemeType.LBrace, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.RBrace ),
		staticRule( "[", LexemeType.LBracket, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.RBracket ),
		staticRule( "(", LexemeType.LParen, LexemeFlag.Paren, LexemeFlag.Left, LexemeType.RParen ),
		staticRule( "<=", LexemeType.LTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "<", LexemeType.LT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "%", LexemeType.Mod, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "**", LexemeType.Pow, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "*", LexemeType.Mul, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "!=", LexemeType.NotEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "}", LexemeType.RBrace, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.LBrace ),
		staticRule( "]", LexemeType.RBracket, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.LBracket ),
		staticRule( ")", LexemeType.RParen, LexemeFlag.Paren, LexemeFlag.Right, LexemeType.LParen ),
		staticRule( ";", LexemeType.Semicolon, LexemeFlag.Separator),
		staticRule( "-", LexemeType.Sub, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "~", LexemeType.Tilde, LexemeFlag.Operator ),

		dynamicRule( &parseFloat, LexemeType.Float, LexemeFlag.Literal ),
		dynamicRule( &parseInteger, LexemeType.Integer, LexemeFlag.Literal ),
		dynamicRule( &parseName, LexemeType.Name ),
		dynamicRule( &parseString, LexemeType.String, LexemeFlag.Literal )
	];
	
	struct LexerContext
	{
		ContextState[] statesStack;
		LexTypeIndex[] parenStack;
		
		this(this)
		{
			parenStack = parenStack.dup;
		}
		
		ref LexerContext opAssign(ref LexerContext rhs)
		{
			statesStack = rhs.statesStack.dup;
			parenStack = rhs.parenStack.dup;
			return this;
		}
		
		@property ContextState state()
		{
			return statesStack.empty ? ContextState.CodeContext : statesStack.back;	
		}
		
	}

	LexemeT[] lexemes;
	SourceRange sourceRange; //Source range. Don't modify it!
	SourceRange currentRange;
	LexerContext _ctx;
		
	/+private+/ LexemeT _front;
	
	@disable this(this);	
	
	this( String src ) 
	{
		auto newRange = SourceRange(src);
		this( newRange );
	}
	
	this( ref const(SourceRange) srcRange )
	{
		sourceRange = srcRange.save;
		currentRange = sourceRange.save;

		// In order to make lexer initialized at startup - we parse first lexeme
		if( !this.empty )
			this.popFront();
	}
	
	void parse()
	{
		while( !currentRange.empty )
		{
			popFront();
		}
	}

	static LexemeT parseFront(ref SourceRange source, ref LexerContext ctx)
	{
		import std.conv: to;
		if( ctx.state == ContextState.CodeContext )
			skipWhiteSpaces(source);

		if( source.empty )
		{
			if( !ctx.parenStack.empty )
				assert( 0, 
					"Expected matching parenthesis for " 
					~ (cast(LexemeType) ctx.parenStack.back).to!string  
					~ ", but unexpected end of input found!!!" 
				);
			
			return createLexemeAt(source, LexemeType.EndOfFile);
		}
		
		LexRule[] rules;
		
		if( ctx.state == ContextState.CodeContext )
			rules = codeContextRules;
		else if( ctx.state == ContextState.MixedContext )
			rules = mixedContextRules;
		else {
			assert( false, "No lexer context detected!" );
			rules = null;
		}


		LexemeT lex;
		SourceRange currentRange;
		foreach( rule; rules )
		{
			currentRange = source.save;
			if( rule.apply(currentRange) )
			{
				lex = extractLexeme( source, currentRange, rule.lexemeInfo );
				break;
			}
		}

		if( !lex.info.isValidType )
			assert(false, "Expected valid token!");

		return lex;
	}

	void popFront()
	{
		import std.array: array;
		import std.conv: to;
		
		_front = parseFront(currentRange, _ctx);
		
		lexemes ~= _front;

		// Checking paren balance
		if( _front.info.isRightParen )
		{
			if( !_ctx.parenStack.empty )
			{
				if( _ctx.parenStack.back == _front.info.pairTypeIndex )
				{
					_ctx.parenStack.popBack();
				}
				else
				{
					lexerError( `Expected pair lexeme "` ~ (cast(LexemeType) _front.info.typeIndex).to!string
						~ `" for lexeme "` ~ (cast(LexemeType) _front.info.pairTypeIndex).to!string ~ `"` );
				}
			}
		}
		else if( _front.info.isLeftParen )
		{
			_ctx.parenStack ~= _front.info.typeIndex;
		}

		// Determining context state
		switch( _front.info.typeIndex ) with( LexemeType )
		{
			case CodeBlockBegin:
			{
				if( _ctx.state == ContextState.CodeContext || _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.CodeContext;
				}
				break;
			}
			case CodeBlockEnd:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
				break;
			}
			case CodeListBegin:
			{
				if( _ctx.state == ContextState.CodeContext || _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.CodeContext;
				}
				break;
			}
			case CodeListEnd:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
				break;
			}
			case MixedBlockBegin:
			{
				if( _ctx.state == ContextState.CodeContext || _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.MixedContext;
				}
				break;
			}
			case MixedBlockEnd:
			{
				if( _ctx.state == ContextState.MixedContext )
				{
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
				break;
			}
			default:
				break;
		}
	}
	
	bool empty()
	{	return currentRange.empty || _front.info.isEndOfFile;
	}
	
	LexemeT front() @property
	{
		return _front;
	}
	
	auto frontValue() @property
	{
		return front.getSlice(sourceRange);
	}
	
	@property auto save()
	{
		auto thisCopy = Lexer!(S, c)(sourceRange);
		thisCopy.currentRange = this.currentRange.save;
		thisCopy.lexemes = this.lexemes.dup;
	
		thisCopy._ctx = this._ctx;
		thisCopy._front = this._front;
		
		return thisCopy;
	}
	
	
	void fail_expectation(LexemeType lexType, size_t line, String value = String.init )
	{
		String whatExpected = `lexeme of typeIndex "` ~ lexType.to!String ~ `"`;
		if( !value.empty )
			whatExpected ~= ` with value "` ~ value ~ `"`;

		assert( !this.empty, `Expected ` ~ whatExpected ~ ` but end of input found!!!` );
		
		String whatGot = `lexeme of typeIndex "` ~ front.info.typeIndex.to!String ~ `"`;
		if( !front.getSlice(sourceRange).empty )
			whatGot ~= ` with value "` ~ front.getSlice(sourceRange).array ~ `"`;
		
		assert( false,  `[` ~ line.to!String ~ `] Expected ` ~ whatExpected ~ ` but got ` ~ whatGot ~ `!!!` );
	}
	
	LexemeT expect(LexemeType lexType, String value, size_t line = __LINE__)
	{
		import std.algorithm: equal;
		
		if( this.empty )
			fail_expectation(lexType, line, value);
		
		LexemeT lex = this.front;
		if( lex.info.typeIndex == lexType && lex.getSlice(sourceRange).equal(value) )
		{
			this.popFront();
			return lex;
		}
		
		fail_expectation(lexType, line, value);
		assert(0);
	}

	LexemeT expect(LexemeType lexType, size_t line = __LINE__)
	{
		if( this.empty )
			fail_expectation(lexType, line);
		
		LexemeT lex = this.front;
		if( lex.info.typeIndex == lexType )
		{
			this.popFront();
			return lex;
		}
		
		fail_expectation(lexType, line);
		assert(0);
	}
		
	bool skipIf(LexemeType lexType)
	{
		if( this.empty )
			return false;
		
		auto lex = this.front;
		if( lex.info.typeIndex == lexType )
		{
			this.popFront();
			return true;
		}
		return false;
	}
	
	bool skipIf(LexemeType typeIndex, String value)
	{
		import std.algorithm: equal;
		
		if( this.empty )
			return false;
		
		auto lex = this.front;
		if( lex.info.typeIndex == typeIndex && lex.getSlice(sourceRange).equal(value) )
		{
			this.popFront();
			return true;
		}
		return false;
	}
	
	LexemeT next() @property
	{
		//Creates copy of currentRange in order to not modify original one
		SourceRange parsedRange = currentRange.save; 
		if( this.empty )
			assert( false, "Cannot peek lexeme, because currentRange is empty!!!" );
		
		return parseFront(parsedRange, _ctx);
	}
	
	static void skipWhiteSpaces(ref SourceRange source)
	{
		Char ch;
		while( !source.empty )
		{
			ch = source.front();
			if( !whitespaceChars.canFind(ch) )
				return;
			source.popFront();
		}
	}

	static immutable string[] stringQuotes = [
		`"`, `'`
	];

	import std.traits;

	static bool parseString(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseString");
		
		String quoteLex;

		foreach( ref quote; stringQuotes )
		{
			if( source.match(quote) )
			{
				quoteLex = quote;
				break;
			}
		}
		
		if( quoteLex.empty )
			return false;
		
		while( !source.empty )
		{
			if( source.match(quoteLex) ) // Test and consume
				return true;
			else
				source.popFront();
		}
		
		assert(0, `Expected <` ~ quoteLex.to!string ~ `> but end of input found!!!` );
	}

	static bool parseInteger(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseInteger");

		Char ch;
		
		if( source.empty )
			return false;
		
		ch = source.front;
		if( !('0' <= ch && ch <= '9') )
			return false;
		source.popFront();
		
		while( !source.empty )
		{
			ch = source.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			source.popFront();
		}
		
		return true;
	}

	static bool parseFloat(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseFloat");

		Char ch;
		
		if( source.empty )
			return false;
		
		ch = source.front;
		if( !('0' <= ch && ch <= '9') )
			return false;
		source.popFront();
		
		while( !source.empty )
		{
			ch = source.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			source.popFront();
		}
		
		if( source.empty )
			return false;
		
		ch = source.front;
		if( ch != '.' )
			return false;
		source.popFront();
		
		if( source.empty )
			assert( false, `Expected decimal part of float!!!` );
		
		ch = source.front;
		if( !('0' <= ch && ch <= '9') )
			assert( false, `Expected decimal part of float!!!` );
		source.popFront();
		
		while( !source.empty )
		{
			ch = source.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			source.popFront();
		}
		
		return true;
	}
	
	static immutable notTextLexemes = [
		codeBlockBegin,
		codeListBegin,
		mixedBlockBegin,
		mixedBlockEnd
		//,exprBlockBegin
	];

	static bool parseData(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseData");

		while( !source.empty )
		{
			foreach( ref notText; notTextLexemes )
			{
				if( source.save.match(notText) ) // Test only, but not consume
				{
					return true;
				}
			}
			source.popFront();
		}
		
		return true;
	}
	
	static bool parseDataBlock(ref SourceRange source, ref const(LexRule) rule)
	{
		if( source.empty )
			return false;
		
		if( !source.match(dataBlockBegin) )
			return false;
		
		while( !source.empty )
		{
			if( source.match(dataBlockEnd) )
				return true;
				
			source.popFront();
		}
	
		return true;
	}
	
	static bool parseName(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseName");

		Char ch;
		dchar dch;
		ubyte len;
		
		if( source.empty )
			return false;
		
		ch = source.front();
		
		if( !isStartCodeUnit(ch) )
			return false;
		
		dch = source.decodeFront();
		len = source.frontUnitLength();
		if( !isNameChar(dch) || isNumberChar(dch) )
			return false;
		
		source.popFrontN(len);
		
		while( !source.empty )
		{
			len = source.frontUnitLength();
			dch = source.decodeFront();
			
			if( !isNameChar(dch) )
				break;
			
			source.popFrontN(len);
		}
		
		return true;
	}
	
}
