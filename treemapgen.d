import std.string;
import std.exception;
import std.file;

import ae.utils.json;
import ae.utils.text;

import mapfile;
import dsym;

void main(string[] args)
{
	enforce(args.length == 3, "Usage: "~args[0]~" input.map output.json");

	auto map = new MapFile(args[1]);

	string[string] cppSymbols;
	{/+
		string[] cppSymbolList;
		foreach (symbol; map.symbols)
			if (symbol.name.startsWith("?"))
				cppSymbolList ~= symbol.name;

		if (cppSymbolList.length)
		{
			auto fn = "cppsymbols.txt";
			auto outfn = "cppsymbols-dem.txt";
			std.file.write(fn, cppSymbolList.join("\n"));
			scope(exit) if (exists(fn)) remove(fn);
			system("c++filt < "~fn~" > "~outfn);
			scope(exit) if (exists(outfn)) remove(outfn);
			auto cppDemSymbolList = splitAsciiLines(cast(string)std.file.read(outfn));

			if (cppDemSymbolList.length == cppSymbolList.length)
				foreach (i; 0..cppSymbolList.length)
					cppSymbols[cppSymbolList[i]] = cppDemSymbolList[i];
		}
	+/}

	struct TreeLeaf
	{
		ulong size, address;
		string mangledName, demangledName;
	}

	struct TreeNode
	{
		ulong total;

		TreeNode[string] children;
		TreeLeaf[string] leaves;
	}

	TreeNode root;

	enforce(map.symbols.length > 1, "No symbols");
	foreach (i; 0..map.symbols.length-1)
	{
		auto addr  = map.symbols[i  ].address;
		auto addr2 = map.symbols[i+1].address;
		auto size  = addr2 - addr;

		if (addr == 0 || size == 0)
			continue;

		auto sym = map.symbols[i].name;

		bool end;
		if (sym.startsWith(END_PREFIX))
			end = true,
			sym = sym[END_PREFIX.length..$];

		if (end && sym.endsWith("crtend.o (.eh_frame)"))
			continue;

		string dem;
		auto segments = parseDSymbol(sym, dem);

		if (end)
			segments = ["Afterpadding"] ~ segments;

		auto node = &root;
		foreach (segment; segments[0..$-1])
		{
			node.total += size;
			auto next = segment in node.children;
			if (!next)
			{
				node.children[segment] = TreeNode();
				next = segment in node.children;
			}
			node = next;
		}

		{ /*with*/ auto segment = segments[$-1];
			node.total += size;
			auto leafName = segment;
			int n = 0;
			while (leafName in node.leaves)
				leafName = segment ~ format("#%d", ++n);
			node.leaves[leafName] = TreeLeaf(size, addr, forceValidUTF8(sym), dem==sym ? null : forceValidUTF8(dem));
		}
	}

	std.file.write(args[2], "var treeData = " ~ toJson(root));
}
