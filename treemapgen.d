import std.file;
import std.string, std.conv, std.ascii, std.array;
import std.exception;
import std.process;
import core.demangle;

import ae.utils.json;
import ae.utils.text;

import mapfile;

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

		int p = 0;
		auto decoded = decodeDmdString(sym, p);
		if (decoded.length)
			sym = decoded;

		if (sym.startsWith("__D"))
			sym = sym[1..$];

		string dem = demangle(sym).idup;
		string[] segments;
		if (dem != sym)
		{
			enum SUB_SPACE  = '\xFF';
			enum SUB_PERIOD = '\xFE';

			int plevel = 0;
			auto str = dem.dup;
			foreach (ref c; str)
				if (c=='(')
					plevel++;
				else
				if (c==')')
					plevel--;
				else
				if (c==' ' && plevel)
					c = SUB_SPACE;
				else
				if (c=='.' && plevel)
					c = SUB_PERIOD;

			segments = assumeUnique(str).replace("...", [SUB_PERIOD, SUB_PERIOD, SUB_PERIOD]).split(".");
			foreach (ref seg; segments)
			{
				if (seg.startsWith("extern (C) "))
					seg = seg["extern (C) ".length..$];
				if (seg.lastIndexOf(' ')>=0)
					seg = seg[seg.lastIndexOf(' ')+1..$];
				if (seg.indexOf('(')>=0)
					seg = seg[0..seg.indexOf('(')];

				seg = seg
					.replace([SUB_SPACE], " ")
					.replace([SUB_PERIOD], ".");
			}
		}
		else
		{
			if (sym.startsWith("_D") && sym.length>=4 && isDigit(sym[2]))
			{
				auto str = sym[2..$];
				while (str.length)
				{
					try
					{
						auto len = parse!uint(str);
						enforce(len <= str.length);
						segments ~= str[0..len];
						str = str[len..$];
					}
					catch (Exception e)
					{
						segments ~= str;
						str = null;
					}
				}
				dem = segments.join(".");
			}
			else
			if (sym.startsWith("__d_"))
				segments = ["D internals", sym[4..$]];
			else
			if (sym.startsWith("_d_"))
				segments = ["D internals", sym[3..$]];
			else
			/*if (sym in cppSymbols)
				dem = cppSymbols[sym];
			else*/
			if (sym.startsWith("?"))
				segments = ["C++ symbols", sym];
			else
			if (sym.startsWith("__imp__"))
				segments = ["Imports", sym[7..$]];
			else
			if (sym.startsWith("_"))
			{
				auto str = sym;
				while (str.startsWith("_")) str = str[1..$];
				segments = ["C symbols", str];
			}
			else
			if (sym.startsWith("/"))
			{
				auto str = sym
					.replace(" (", "(")
					.replace("(", "/")
					.replace(")", "");
				segments = str.split("/");
				segments[0] = "/";

				int j = 0;
				while (j < segments.length-1)
					if (segments[j+1] == "..")
						segments = segments[0..j] ~ segments[j+2..$],
						j--;
					else
						j++;
			}
			else
				segments = [sym];
		}
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
