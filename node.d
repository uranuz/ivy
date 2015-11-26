module declarative.node;

import declarative.common;

interface IDeclNode
{
	@property {
		IDeclNode parent();
		IDeclNode[] children();
		
		Location location() const;             // Location info for internal usage
		PlainLocation plainLocation() const;   // Location for user info
		ExtendedLocation extLocation() const;  // Extended location info
		LocationConfig locationConfig() const; // Configuration of available location data

		string kind();
	}
	
	@property {
		void parent(IDeclNode node);
	}
	
	// string toString();
}



interface IExpression: IDeclNode
{
	// bool checkValue();
	// bool checkScalar();
	// bool checkBoolean();
	// bool checkIntegral();
	// bool checkFloating();
	// bool checkArithmetic();
	// bool checkString();
	@property {
		IStatement statement();
	}
}


enum Operator {
	None = 0,
	
	//Unary arithmetic
	UnaryPlus = 1,
	UnaryMin,
	
	//Binary arithmetic
	Add,
	Sub,
	Mul,
	Div,
	Mod,
	
	//Logical operators
	Not,
	And,
	Or,
	Xor,
	
	//Compare operators
	Equal,
	NotEqual,
	LT,
	GT,
	LTEqual,
	GTEqual
}

interface IOperatorExpression: IExpression
{
	@property const {
		int operatorIndex();
	}
}

interface IUnaryExpression: IOperatorExpression
{
	@property
	{
		IExpression expr();
	}

}

interface IBinaryExpression: IOperatorExpression
{
	@property {
		IExpression leftExpr();
		IExpression rightExpr();
	}

}

interface IIdentifier
{
	@property {
		string name();
	}
}


class Identifier: IIdentifier
{

private:
	string _fullName;
	
	
public:
	this( string fullName )
	{
		_fullName = fullName;
	}
	
	override @property {
		string name()
		{
			return _fullName;
		}
	}

}

interface IKeyValueAttribute: IDeclNode
{
	@property {
		string name();
		IExpression expression();
	}

}

interface IStatement: IDeclNode
{
	@property {
		bool isCompoundStatement();
		ICompoundStatement asCompoundStatement();
		bool isDeclarativeStatement();
		IDeclarativeStatement asDeclarativeStatement();
	}
}


interface IDeclarationSection: IStatement
{
	@property {
		string name();
		IExpression[] plainAttributes();
		IKeyValueAttribute[] keyValueAttributes();
		IStatement statement();
	}

}

interface IDeclarativeStatement: IStatement
{
	@property {
		string name();
		IDeclarationSection mainSection();
		IDeclarationSection[] sections();
	}
}

interface ICompoundStatement: IStatement
{
	@property {
		IStatement[] statements();	
	}
}



