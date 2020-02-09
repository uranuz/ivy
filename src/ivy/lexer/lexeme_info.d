module ivy.lexer.lexeme_info;

import ivy.lexer.consts: LexemeFlag, LexemeType;

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