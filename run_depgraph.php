<?php

if (!isset($_FILES['binfile'])) die('No file?');

$id = uniqid();
$fn = "data/$id.bin";

if (!move_uploaded_file($_FILES['binfile']['tmp_name'], $fn))
	die("Upload failed...");

$retval = 1;
system("objdump -d data/$id.bin > data/$id.asm", $retval);
if ($retval != 0)
	die("objdump failed");

$retval = 1;
system("./depgraph data/$id.asm", $retval);
if ($retval != 0)
	die("depgraph failed");

header("Location: data/$id.html");
