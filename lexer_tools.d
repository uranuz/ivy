module declarative.lexer_tools;

import std.range;
import std.traits;
import std.algorithm: startsWith;
import std.range: popFrontN;
import std.algorithm: equal;

import std.stdio;

import declarative.common;

struct TextForwardRange(S, LocationConfig c = LocationConfig.init )
	if( isSomeString!S )
{
	alias String = S;
	alias Char = Unqual!(ElementEncodingType!S);
	enum LocationConfig config = c;
	
	alias ThisType = TextForwardRange!(S, c);
	
	String str;
	
	size_t index = 0;
	size_t endIndex = size_t.max;
	
	@disable this(this);
	
	static if( config.withGraphemeIndex )
		size_t graphemeIndex = 0;
	
	static if( config.withLineIndex )
	{
		size_t lineIndex = 0;
		
		static if( config.withColumnIndex )
			size_t columnIndex = 0;
		
		static if( config.withGraphemeColumnIndex )
			size_t graphemeColumnIndex = 0;
	}
	
	bool empty() @property inout
	{
		return index >= this.sliceEndIndex;
	}
	
	private size_t sliceEndIndex() @property inout
	{
		import std.algorithm: min;
		
		return min( str.length, endIndex );	
	}
	
	size_t length() @property inout
	{
		return this.sliceEndIndex - index;
	}
	
	Char popChar()
	{
		Char ch = front();
		popFront();
		return ch;
	}
	
	void popFront()
	{
		if( index >= this.sliceEndIndex )
			return;
		
		static if( config.withLineIndex )
		{
			if( ( str[index] == '\r' && !str.startsWith("\r\n") ) || str[index] == '\n' )
			{
				lineIndex++;
				
				static if( config.withColumnIndex )
					columnIndex = 0;
				
				static if( config.withGraphemeColumnIndex )
					graphemeColumnIndex = 0;
			}
			else
			{
				columnIndex++;
			}
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
			
		index++;
	}
	
	void popFrontN(size_t N)
	{
		foreach(i; 0..N)
			popFront();
	}
	
	Char front() @property inout
	{	return index >= this.sliceEndIndex ? '\0' : str[index];
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
	
	// bool matchDottedIdentifier(String input)
	// {
		// auto thisSlice = this.save;
		
		// return false;
	// }
	
	auto save() @property inout
	{
		auto thisCopy = ThisType(str, index, endIndex);
		
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
		//writeln("toString: index: ", index, ", this.sliceEndIndex: ", this.sliceEndIndex);
		return str[index .. this.sliceEndIndex];
	}
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


// void main()
// {
	
	// alias SourceRange = TextForwardRange!string;
	
	// auto sourceRange = SourceRange("iffd {}");
	
	// writeln("Hello!!!");
	
// // 	dchar c = stream.decodeFront();
// // 	writeln(c);
	// //writeln(replacementChar);
	
	
	// writeln(sourceRange.matchWord("iffd"));

// }


bool isNameChar(dchar ch)
{
	import std.uni: isAlpha;
	
	return isAlpha(ch) || ('0' <= ch && ch <= '9') || ch == '_';
}

bool isNumberChar(dchar ch)
{
	return ('0' <= ch && ch <= '9');
}