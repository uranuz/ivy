module ivy.compiler.def_analyze_mixin;


mixin template DefAnalyzeMixin()
{
	
	auto analyzeValueAttr(IAttributeRange attrRange)
	{
		import std.typecons: Tuple;
		alias Result = Tuple!(
			DirValueAttr, `attr`,
			bool, `isSet`,
			IExpression, `defaultValueExpr`
		);

		Result res;
		if( auto kwPair = cast(IKeyValueAttribute) attrRange.front )
		{
			res.attr.name = kwPair.name;
			res.defaultValueExpr = cast(IExpression) kwPair.value;
			if( !res.defaultValueExpr )
				loger.error(`Expected attribute default value expression!`);
			res.isSet = true;

			attrRange.popFront(); // Skip named attribute
		}
		else if( auto nameExpr = cast(INameExpression) attrRange.front )
		{
			res.attr.name = nameExpr.name;
			res.isSet = true;
			attrRange.popFront(); // Skip variable name
		}

		if( !attrRange.empty )
		{
			// Try to parse optional type definition
			if( auto asKwdExpr = cast(INameExpression) attrRange.front )
			{
				if( asKwdExpr.name == "as" )
				{
					// TODO: Try to find out type of attribute after `as` keyword
					// Assuming that there will be no named attribute with name `as` in programme
					attrRange.popFront(); // Skip `as` keyword

					if( attrRange.empty )
						loger.error(`Expected attr type definition, but got end of attrs range!`);

					auto attrTypeExpr = cast(INameExpression) attrRange.front;
					if( !attrTypeExpr )
						loger.error(`Expected attr type definition!`);

					res.attr.typeName = attrTypeExpr.name; // Getting type of attribute as string (for now)

					attrRange.popFront(); // Skip type expression
				}
			}
		}

		return res;
	}


	auto analyzeDirBody(IAttributeRange attrsDefStmtAttrRange)
	{
		import std.typecons: Tuple;
		alias Result = Tuple!(
			DirBodyAttr, `attr`,
			ICompoundStatement, `statement`
		);

		Result res;
		// Try to parse noscope and noescape flags
		body_flags_loop:
		while( !attrsDefStmtAttrRange.empty )
		{
			INameExpression flagExpr = cast(INameExpression) attrsDefStmtAttrRange.front;
			if( !flagExpr ) {
				break;
			}
			switch( flagExpr.name )
			{
				case "noscope": res.attr.isNoscope = true; break;
				case "noescape": res.attr.isNoescape = true; break;
				default: break body_flags_loop;
			}
			attrsDefStmtAttrRange.popFront();
		}

		if( attrsDefStmtAttrRange.empty )
			loger.error("Unexpected end of def.body directive!");

		// Getting body AST for statement just for check if it is there
		res.statement = cast(ICompoundStatement) attrsDefStmtAttrRange.front;
		if( !res.statement )
			loger.error("Expected compound statement as directive body statement");

		attrsDefStmtAttrRange.popFront(); // Need to consume body statement to behave correctly

		return res;
	}

}