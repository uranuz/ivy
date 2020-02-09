module ivy.ast.iface.statement;

import ivy.ast.iface.node: IvyNode;
import ivy.ast.iface.node_range: IvyNodeRange;
import ivy.ast.iface.expr: IExpression;

interface IStatement: IvyNode
{
	@property {
		bool isCompoundStatement();
		ICompoundStatement asCompoundStatement();
		bool isDirectiveStatement();
		IDirectiveStatement asDirectiveStatement();
	}
}

interface IDataFragmentStatement: IStatement
{
	@property {
		string data();
	}
}

interface ICompoundStatement: IStatement
{
	IStatementRange opSlice();
	IStatementRange opSlice(size_t begin, size_t end);
}

interface ICodeBlockStatement: ICompoundStatement, IExpression
{
	// Covariant overrides
	override IDirectiveStatementRange opSlice();
	override IDirectiveStatementRange opSlice(size_t begin, size_t end);

	bool isListBlock() @property;
}

interface IMixedBlockStatement: ICompoundStatement, IExpression
{
}

interface IDirectiveStatement: IStatement
{
	@property {
		string name(); //Returns name of directive
	}

	IAttributeRange opSlice();
	IAttributeRange opSlice(size_t begin, size_t end);
}

interface IKeyValueAttribute: IvyNode
{
	@property {
		string name();
		IvyNode value();
	}
}

interface IStatementRange: IvyNodeRange
{
	// Covariant overrides
	override @property IStatement front();
	override @property IStatement back();
	override @property IStatementRange save();
	override IStatement opIndex(size_t index);
}

interface IDirectiveStatementRange: IStatementRange
{
	// Covariant overrides
	override @property IDirectiveStatement front();
	override @property IDirectiveStatement back();
	override @property IDirectiveStatementRange save();
	override IDirectiveStatement opIndex(size_t index);
}

interface IAttributeRange: IvyNodeRange
{
}
