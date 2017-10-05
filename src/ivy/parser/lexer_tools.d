module ivy.parser.lexer_tools;

import std.range;
import std.traits;
import std.algorithm: startsWith;
import std.range: popFrontN;
import std.algorithm: equal;

import std.stdio;

import ivy.common;

struct TextForwardRange(S, LocationConfig c = LocationConfig.init)
	if( isSomeString!S )
{
	alias String = S;
	alias Char = Unqual!(ElementEncodingType!S);
	enum LocationConfig config = c;

	alias ThisType = TextForwardRange!(S, c);

	// This range keeps original reference to data internally
	String str;

	// Index of starting position to data this range points to
	size_t index = 0;
	// Index of tail of this range or size_t.max if range ends at end of original data buffer
	size_t endIndex = size_t.max;

	@disable this(this);

	this( String source )
	{
		str = source;

		analyzeIndents();
	}

	static if( config.withGraphemeIndex )
		size_t graphemeIndex = 0;

	static if( config.withLineIndex )
	{
		size_t lineIndex = 0; // Line index related to original data buffer

		static if( config.withColumnIndex )
			size_t columnIndex = 0;

		static if( config.withGraphemeColumnIndex )
			size_t graphemeColumnIndex = 0;
	}

	//size_t lineStartIndex; // TODO: Decide whether use or remove it

	// If it set to true means that indents on current line have passed
	private bool isIndenting = true;
	IndentStyle indentStyle; // Tabs or spaces indent style for current line
	size_t indentCount; // Indentation count in number of tabs or spaces


	/// Test if current range is empty or fully consumed
	bool empty() @property inout
	{
		return index >= this.sliceEndIndex;
	}

	// Ending position of range in original data
	private size_t sliceEndIndex() @property inout
	{
		import std.algorithm: min;

		return min( str.length, endIndex );
	}

	/// Count of remaining symbols in range
	size_t length() @property inout
	{
		return this.sliceEndIndex - index;
	}

	/// Return current char and push the range forward
	Char popChar()
	{
		Char ch = front();
		popFront();
		return ch;
	}

	// Tests if current item is line indentation symbol
	private void analyzeIndents()
	{
		if( index >= this.sliceEndIndex )
			return;

		if( isNewLine )
		{
			indentCount = 0;
			isIndenting = true;
		}

		if( isIndenting )
		{
			if( indentCount == 0 )
			{
				if( str[index] == '\t' )
				{
					indentStyle = IndentStyle.tab;
					++indentCount;
				}
				else if( str[index] == ' ' )
				{
					indentStyle = IndentStyle.space;
					++indentCount;
				}
				else
					isIndenting = false;
			}
			else
			{
				if( str[index] == indentStyle )
					++indentCount;
				else
					isIndenting = false;
			}
		}
	}

	/// Push the range forward by one encoding element
	void popFront()
	{
		index++;

		if( index >= this.sliceEndIndex )
			return;

		analyzeIndents();

		static if( config.withLineIndex )
		{
			if( isNewLine )
			{
				lineIndex++;

				static if( config.withColumnIndex )
					columnIndex = 0;

				static if( config.withGraphemeColumnIndex )
					graphemeColumnIndex = 0;
			}

			static if( config.withColumnIndex )
				columnIndex++;
		}

		import std.traits: Unqual;

		static if( is( Char == char ) )
		{
			if( isStartCodeUnit(str[index]) )
			{
				static if( config.withGraphemeIndex )
					graphemeIndex++;

				static if( config.withGraphemeColumnIndex )
					graphemeColumnIndex++;
			}
		}
		else static if( is( Char == wchar ) )
		{
			static assert( false, "Working with Unicode Transfromation Format 16 is not implemented yet!");
			if( str[index] < 65536 )
			{
				static if( config.withGraphemeIndex )
					graphemeIndex++;

				static if( config.withGraphemeColumnIndex )
					graphemeColumnIndex++;
			}
		}
		else static if( is( Char == dchar ) )
		{
			static if( config.withGraphemeIndex )
				graphemeIndex++;

			static if( config.withGraphemeColumnIndex )
				graphemeColumnIndex++;
		}
		else
			static assert( false, "Code unit type '" ~ Char.stringof ~ "' is not valid!" );
	}

	/// Push the range forward by N encoding elements
	void popFrontN(size_t N)
	{
		foreach(i; 0..N)
			popFront();
	}

	/// Get current encoding element
	Char front() @property inout
	{	return index >= this.sliceEndIndex ? '\0' : str[index];
	}

	/// Tests if current encoding element goes immediatly after new line chars or when it's start of buffer
	@property bool isNewLine()
	{
		return index == 0 || str[index-1] == '\n' || ( str[index-1] == '\r' && str[index] != '\n' );
	}

	/// Tests if range front currently points to indentation symbol
	@property bool isIndentation()
	{
		return isIndenting && ( str[index] == '\t' || str[index] == ' ' );
	}

	/// Get current's line indent info without pushing this range forward
	void getLineIndent( ref size_t count, ref IndentStyle style )
	{
		bool isInd = this.isIndentation;

		if( !isInd )
		{
			count = indentCount;
			style = indentStyle;
			return;
		}

		auto tmp = this.save;
		isInd = tmp.isIndentation;

		while( isInd && !tmp.empty )
		{
			tmp.popFront();
			isInd = tmp.isIndentation;
		}

		count = tmp.indentCount;
		style = tmp.indentStyle;

		return;
	}

	/// Parses current's line indent with pushing the range forward
	void parseLineIndent( ref size_t count, ref IndentStyle style )
	{
		while( isIndentation && !this.empty )
			this.popFront();

		count = indentCount;
		style = indentStyle;
	}

	bool match(String input)
	{
		import std.algorithm: equal;

		if( input.length > this.length )
			return false;

		if( !equal( this[0 .. input.length], input ) )
			return false;

		foreach( i; 0..input.length )
			popFront();

		return true;
	}

	bool matchWord(String input)
	{
		import std.uni: isAlpha;

		size_t inpIndex = 0;

		auto thisSlice = this.save; //Creating temporary slice of this range

		if( input.length > thisSlice.length || input.length == 0 || thisSlice.empty )
			return false;

		Char thisChar = thisSlice.front;
		dchar thisDChar;
		ubyte codeUnitLen;

		//Match if we have input starting with
		if( !isStartCodeUnit(input[0]) || !isStartCodeUnit(thisChar) )
			return false;

		while( !thisSlice.empty )
		{
			thisDChar = thisSlice.decodeFront();

			codeUnitLen = frontUnitLength(thisSlice);

			if( isAlpha(thisDChar) )
			{
				if( inpIndex + codeUnitLen > input.length )
					return false;

				if( !equal( thisSlice[0 .. codeUnitLen], input[inpIndex .. inpIndex + codeUnitLen] ) )
					return false;
			}
			else
				break;

			inpIndex += codeUnitLen;
			thisSlice.popFrontN(codeUnitLen);
		}

		if( thisSlice.empty || ( !isAlpha(thisDChar) && ( inpIndex + codeUnitLen > input.length ) ) )
		{
			this = thisSlice.save;
			return true;
		}
		else
			return false;
	}

	auto opSlice() const
	{
		return this.save;
	}

	alias opDollar = length;

	auto opSlice(size_t start, size_t end) const
	{
		import std.conv;

		size_t newEndIndex = this.index + end;

		assert( start <= str.length, "Slice start index: " ~ start.to!string ~ " out of bounds: [ 0, " ~ str.length.to!string ~ " )"  );
		assert( newEndIndex <= str.length, "Slice end index: " ~ newEndIndex.to!string ~ " out of bounds: [ 0, " ~ str.length.to!string ~ " )" );
		auto thisSlice = this.save;

		thisSlice.popFrontN(start); //Call this in order to get valid lineIndex, graphemeIndex, etc.
		thisSlice.endIndex = newEndIndex; //Calculating end index for slice

		return thisSlice;
	}

	auto save() @property inout
	{
		auto thisCopy = ThisType(str);

		thisCopy.index = this.index;
		thisCopy.endIndex = this.endIndex;
		thisCopy.isIndenting = this.isIndenting;
		thisCopy.indentCount = this.indentCount;
		thisCopy.indentStyle = this.indentStyle;

		static if( config.withGraphemeIndex )
			thisCopy.graphemeIndex = this.graphemeIndex;

		static if( config.withLineIndex )
		{
			thisCopy.lineIndex = this.lineIndex;

			static if( config.withColumnIndex )
				thisCopy.columnIndex = this.columnIndex;

			static if( config.withGraphemeColumnIndex )
				thisCopy.graphemeColumnIndex = this.graphemeColumnIndex;
		}

		return thisCopy;
	}

	string toString() inout
	{
		return str[index .. this.sliceEndIndex];
	}
}

struct ByLine(Range)
{
private:
	import std.range: ElementType;

	alias Char = ElementType!Range;

	Range _source;
	Range _front;
	bool _isEmpty;

public:
	@disable this(this);

	this(Range src)
	{
		_source = src.save;
		popFront();
	}

	auto front()
	{
		return _front.save;
	}

	void popFront()
	{
		if( _source.empty )
		{
			_isEmpty = true;
			return;
		}

		auto lineRange = _source.save;

		size_t sliceLen = 0;
		bool br = false;


		size_t indentCount;
		IndentStyle indentStyle;

		range_loop:
		while( !br && !_source.empty )
		{
			char_select:
			switch( _source.front )
			{
				case '\n', '\v', '\f', '\u0085':
				{
					_source.getLineIndent( indentCount, indentStyle );
					br = true;
					break;
				}
				case '\r':
				{
					auto tmp = _source.save;
					tmp.popFront();
					if( tmp.empty || tmp.front != '\n' )
					{
						_source.getLineIndent( indentCount, indentStyle );
						br = true;
					}
					else
						break char_select;
					break;
				}
				default:
					break;
			}


			_source.popFront();
			++sliceLen;
		}

		_front = lineRange[0 .. sliceLen];
		_front.indentCount = indentCount;
		_front.indentStyle = indentStyle;
		_front.isIndenting = false;
	}

	auto opSlice()
	{
		return this.save;
	}

	@property auto save()
	{
		auto tmp = ByLine!Range(_source.save);

		tmp._source = _source.save;
		tmp._front = _front.save;
		tmp._isEmpty = _isEmpty;

		return tmp;
	}

	bool empty()
	{
		return _isEmpty;
	}
}

auto byLine(Range)(auto ref Range range)
{
	return ByLine!Range(range.save);
}

enum dchar replacementChar = 0xFFFD;

bool isStartCodeUnit(char ch)
{
	return (ch & 0b1100_0000) != 0b1000_0000;
}

bool isStartCodeUnit(dchar ch)
{
	return true;
}

ubyte frontUnitLength(SourceRange)(ref const(SourceRange) input)
	if( isInputRange!SourceRange )
{
	alias Char = Unqual!(ElementEncodingType!SourceRange);

	if( input.empty )
		return 0;

	Char ch = input.front;

	//For UTF-8 and UTF-16 code points encoded with variable number of code units
	static if( is( Char == char ) )
	{
		if( (ch & 0b1000_0000) == 0 )
			return 1;
		else if( (ch & 0b1110_0000) == 0b1100_0000  )
			return 2;
		else if( (ch & 0b1111_0000) == 0b1110_0000 )
			return 3;
		else if( (ch & 0b1111_1000) == 0b1111_0000 )
			return 4;
		else
			//If SourceRange is in the middle of code point then just return 0
			//instead of throwing error
			return 0;

	}
	else static if( is( Char == wchar ) )
	{
		static assert( false, "Wchar is not supported yet!" );
	}
	else static if( is( Char == dchar ) )
	{
		return 1; //For UTF-32 each code points encoded with 1 code unit
	}
	else
		static assert( false, "Unsupported character type!" );
}



dchar decodeFront(SourceRange)(ref const(SourceRange) input)
	if( isForwardRange!SourceRange )
{
	alias Char = Unqual!(ElementEncodingType!SourceRange);

	static if( is( Char == char ) )
	{
		import std.typetuple: TypeTuple;
		static immutable(char)[4] firstByteMasks = [ 0b0111_1111, 0b0001_1111, 0b0000_1111, 0b0000_0111 ];
		auto textRange = input.save;

		ubyte length = frontUnitLength(input);

		assert( 0 < length && length <= 4, `Char code unit length must be in range [1; 4]!!!` );

		if( length == 0 )
			return replacementChar;

		Char ch = textRange.front;
		dchar result = 0;
		result |= ch & firstByteMasks[length-1];

		foreach( i; TypeTuple!(1,2,3) )
		{
			if( i >= length )
				break;

			textRange.popFront();
			if( textRange.empty )
				return replacementChar;
			ch = textRange.front;

			result <<= 6;
			result |= (ch & 0x3F);
		}

		return result;
	}
	else static if( is( Char == wchar ) )
	{
		static assert( false, "Wchar character type is not supported yet!" );
	}
	else static if( is( Char == dchar ) )
	{
		return input.front;
	}
	else
		static assert( false, "Unsupported character type!!!");

}


bool isNameChar(dchar ch)
{
	import std.uni: isAlpha;

	return isAlpha(ch) || ('0' <= ch && ch <= '9') || ch == '_';
}

bool isNumberChar(dchar ch)
{
	return ('0' <= ch && ch <= '9');
}