import std.file;
import std.string, std.array;
import std.exception;
import core.demangle;

import ae.utils.json;
import ae.utils.text;

import mapfile;

void main(string[] args)
{
	enforce(args.length == 3, "Usage: "~args[0]~" input.map output.json");

	auto map = new MapFile(args[1]);

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
		int p = 0;
		sym = decodeDmdString(sym, p);

		if (sym.startsWith("__D"))
			sym = sym[1..$];

		string dem = demangle(sym).idup;
		string[] segments;
		if (dem != sym)
		{
			segments = dem.replace("...", "***").split(".");
			foreach (ref seg; segments)
			{
				int plevel = 0;
				foreach (ref c; cast(char[])seg) // fuck constness
					if (c=='(')
						plevel++;
					else
					if (c==')')
						plevel--;
					else
					if (c==' ' && plevel)
						c = '_';

				if (seg.startsWith("extern (C) "))
					seg = seg["extern (C) ".length..$];
				if (seg.lastIndexOf(' ')>=0)
					seg = seg[seg.lastIndexOf(' ')+1..$];
				if (seg.indexOf('(')>=0)
					seg = seg[0..seg.indexOf('(')];
			}
		}
		else
			segments = [dem];

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
